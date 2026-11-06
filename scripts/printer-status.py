#!/usr/bin/env python3
import json
import re
import shutil
import socket
import urllib.parse
from command_utils import run_command

def run(args, timeout=2.5):
    return run_command(args, timeout, strip_output=False,
                       error_code=127, timeout_code=None)

def out(obj):
    print(json.dumps(obj, ensure_ascii=False))

LPQ_LINE_RE = re.compile(r"^\s*(\S+)\s+(\S+)\s+(\d+)\s+(.*?)\s*$")
LPQ_SIZE_RE = re.compile(r"\s+\d+\s+\S+\s*$")

def parse_lpq_line(line):
    """Parse one lpq data line into (rank, owner, job_no, title).

    Returns None for headers and unparseable lines. lpq separates some
    columns with single spaces ("1st emanuel 83 ..."), so fixed 2-space
    splitting misaligns; the numeric third field anchors the parse and
    also skips localized header lines. The title is everything between
    it and the trailing size ("1024 bytes").
    """
    m = LPQ_LINE_RE.match((line or "").rstrip())
    if not m:
        return None
    rank, owner, job_no, rest = m.groups()
    title = LPQ_SIZE_RE.sub("", rest).strip()
    if not title:
        return None
    return rank, owner, job_no, title

def device_uri_for(lpstat, name):
    rc, stdout, _ = run([lpstat, "-v", name])
    if rc != 0:
        return ""
    # Typical: "device for PRINTER: ipp://host/ipp/print"
    m = re.search(r":\s*(\S+)\s*$", stdout.strip())
    return m.group(1) if m else ""

def tcp_reachable(host, port, timeout=0.55):
    if not host:
        return False
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except Exception:
        return False

def uri_reachable(uri):
    if not uri:
        return False

    parsed = urllib.parse.urlparse(uri)
    scheme = parsed.scheme.lower()
    host = parsed.hostname

    # Direct USB/local printers should remain visible whenever CUPS sees them.
    if scheme in ("usb", "parallel", "serial", "file"):
        return True

    # Common direct network printing protocols.
    if scheme in ("ipp", "ipps"):
        port = parsed.port or (443 if scheme == "ipps" else 631)
        return tcp_reachable(host, port)

    if scheme == "socket":
        return tcp_reachable(host, parsed.port or 9100)

    if scheme == "lpd":
        return tcp_reachable(host, parsed.port or 515)

    # dnssd:// URIs can be stale in CUPS. Prefer ippfind/Avahi discovery
    # instead of assuming that a configured queue is online.
    if scheme == "dnssd":
        ippfind = shutil.which("ippfind")
        if ippfind:
            rc, stdout, _ = run([ippfind, "-T", "1"], timeout=1.5)
            # Compare service/URI text loosely against the queue URI host/service.
            hay = stdout.lower()
            service = urllib.parse.unquote(parsed.netloc or parsed.path).lower()
            if service and any(part and part in hay for part in re.split(r"[\s._%-]+", service)):
                return True
        return False

    # Unknown network URI: do not mark it online merely because CUPS has a queue.
    if host:
        for port in (631, 9100, 515):
            if tcp_reachable(host, port):
                return True
        return False

    return False

def get_status():
    lpstat = shutil.which("lpstat")
    if not lpstat:
        return {
            "ok": False,
            "version": 1,
            "available": False,
            "visible": False,
            "printers": [],
            "jobs": [],
            "job_count": 0,
            "tooltip": "CUPS/lpstat não encontrado",
            "error": "CUPS/lpstat não encontrado",
        }

    scheduler_rc, scheduler_state, scheduler_error = run([lpstat, "-r"])
    if scheduler_rc != 0 or "not running" in scheduler_state.lower():
        return {
            "ok": False,
            "version": 1,
            "available": False,
            "visible": False,
            "printers": [],
            "jobs": [],
            "job_count": 0,
            "tooltip": "Serviço de impressão indisponível",
            "error": (scheduler_error or scheduler_state or "O serviço de impressão não está disponível").strip(),
        }

    # CUPS destinations may include configured queues that are not actually reachable.
    # We therefore verify each destination's device URI before exposing it in the bar.
    rc, stdout, stderr = run([lpstat, "-e"])
    if rc != 0:
        return {
            "ok": False,
            "version": 1,
            "available": False,
            "visible": False,
            "printers": [],
            "jobs": [],
            "job_count": 0,
            "tooltip": "Estado da impressora indisponível",
            "error": (stderr or stdout or "O serviço de impressão não está disponível").strip(),
        }
    all_destinations = [line.strip() for line in stdout.splitlines() if line.strip()]

    default_name = ""
    _, default_out, _ = run([lpstat, "-d"])
    m = re.search(r":\s*(.+?)\s*$", default_out.strip())
    if m:
        default_name = m.group(1)

    # Pending CUPS jobs must stay accessible even when a network probe fails.
    _, jobs_out, _ = run([lpstat, "-o"])
    queued_printers = {
        line.split()[0].rsplit("-", 1)[0]
        for line in jobs_out.splitlines() if line.strip()
    }

    printers = []
    destinations = []

    for name in all_destinations:
        uri = device_uri_for(lpstat, name)
        reachable = uri_reachable(uri)

        if not reachable and name not in queued_printers:
            continue

        destinations.append(name)

        rc, p_out, _ = run([lpstat, "-p", name])
        line = next((x.strip() for x in p_out.splitlines() if x.strip()), "")
        low = line.lower()

        state = "ready"
        state_text = "Pronta"

        if "disabled" in low or "stopped" in low:
            state = "stopped"
            state_text = "Parada"
        elif "printing" in low:
            state = "printing"
            state_text = "Imprimindo"
        elif not line and rc != 0:
            state = "unknown"
            state_text = "Indisponível"

        if not reachable and state == "ready":
            state = "unknown"
            state_text = "Conexão indisponível · trabalhos na fila"

        printers.append({
            "name": name,
            "state": state,
            "state_text": state_text,
            "default": name == default_name,
            "uri": uri,
            "reachable": reachable,
        })

    jobs = []

    # lpstat gives the canonical CUPS job id; lpq is used to enrich
    # entries with the document title ("File(s)") when available.
    job_titles = {}
    lpq = shutil.which("lpq")

    if lpq:
        for printer_name in destinations:
            rc_q, q_out, _ = run([lpq, "-P", printer_name], timeout=2.5)
            if rc_q != 0:
                continue

            for raw in q_out.splitlines():
                line = raw.rstrip()
                if not line:
                    continue

                low = line.lower()
                if "owner" in low and "job" in low and "file" in low:
                    continue

                parsed = parse_lpq_line(line)
                if not parsed:
                    continue

                rank, owner, job_no, title = parsed
                canonical = f"{printer_name}-{job_no}"
                job_titles[canonical] = {
                    "title": title,
                    "owner": owner,
                    "rank": rank,
                }

    for raw in jobs_out.splitlines():
        raw = raw.strip()
        if not raw:
            continue

        parts = raw.split()
        if not parts:
            continue

        job_token = parts[0]
        owner = parts[1] if len(parts) > 1 else ""
        printer = job_token.rsplit("-", 1)[0] if "-" in job_token else ""

        # Keep jobs for every retained destination, including failed probes.
        if printer not in destinations:
            continue

        extra = job_titles.get(job_token, {})
        title = str(extra.get("title") or job_token)
        if extra.get("owner"):
            owner = str(extra["owner"])

        jobs.append({
            "id": job_token,
            "printer": printer,
            "owner": owner,
            "title": title,
            "rank": str(extra.get("rank") or ""),
            "text": raw,
        })

    job_count = len(jobs)
    has_stopped = any(p["state"] in ("stopped", "unknown") for p in printers)
    has_printing = job_count > 0 or any(p["state"] == "printing" for p in printers)

    status = "error" if has_stopped else ("printing" if has_printing else "ready")

    if not printers:
        tooltip = "Nenhuma impressora alcançável"
    elif len(printers) == 1:
        tooltip = f'{printers[0]["name"]} • {printers[0]["state_text"]}'
    else:
        tooltip = f"{len(printers)} impressoras detectadas"

    if job_count:
        tooltip += f"\n{job_count} trabalho" + ("" if job_count == 1 else "s") + " na fila"
        first_title = str(jobs[0].get("title") or jobs[0].get("id") or "")
        if first_title:
            tooltip += f"\n▶ {first_title[:80]}"

    return {
        "ok": True,
        "version": 1,
        "available": True,
        "visible": len(printers) > 0,
        "status": status,
        "printers": printers,
        "jobs": jobs[:100],
        "job_count": job_count,
        "default": default_name,
        "tooltip": tooltip,
        "error": None,
    }


def main():
    out(get_status())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
