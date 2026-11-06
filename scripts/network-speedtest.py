#!/usr/bin/env python3
import http.client
import json
import re
import subprocess
import sys
import time
import urllib.request

from network_utils import prefer_ipv4_resolution

prefer_ipv4_resolution()


def report(phase, down=0.0, up=0.0, ping=0.0, progress=0.0, done=False, error=""):
    msg = {
        "phase": phase,
        "download_mbps": round(down, 1),
        "upload_mbps": round(up, 1),
        "ping_ms": round(ping, 0),
        "progress": round(progress, 2),
        "done": done,
        "error": error,
    }
    print(json.dumps(msg), flush=True)


def main():
    report("ping", progress=0.05)

    # 1. Latency (Ping)
    ping_val = 0.0
    try:
        p = subprocess.run(
            ["ping", "-c", "2", "-W", "1", "1.1.1.1"],
            capture_output=True,
            text=True,
            timeout=2.5,
        )
        m = re.search(r"=\s*[\d\.]+/([\d\.]+)/", p.stdout)
        if not m:
            m = re.search(r"(?:time|tempo)[=<]([\d\.]+)", p.stdout)
        if m:
            ping_val = float(m.group(1))
    except Exception:
        pass

    report("download", ping=ping_val, progress=0.15)

    # 2. Download Test (Cloudflare target up to 50MB, max 3.5s duration)
    down_mbps = 0.0
    url = "https://speed.cloudflare.com/__down?bytes=50000000"
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0"})

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            t0 = time.time()
            total = 0
            last_report = t0
            while True:
                chunk = resp.read(131072)
                if not chunk:
                    break
                total += len(chunk)
                now = time.time()
                dt = now - t0
                if dt >= 3.5:
                    break
                if now - last_report >= 0.20:
                    cur_speed = (total * 8 / 1_000_000) / dt if dt > 0 else 0
                    prog = min(0.60, 0.15 + 0.45 * (dt / 3.5))
                    report("download", down=cur_speed, ping=ping_val, progress=prog)
                    last_report = now
            dt = time.time() - t0
            down_mbps = (total * 8 / 1_000_000) / dt if dt > 0 else 0
    except Exception as e:
        report("error", ping=ping_val, error="Falha no teste de download: " + str(e))
        return

    report("upload", down=down_mbps, ping=ping_val, progress=0.65)

    # 3. Upload Test (Cloudflare 12MB payload, streaming chunks with live speed)
    up_mbps = 0.0
    chunk_size = 262144  # 256 KB
    num_chunks = 48  # ~12.5 MB total
    chunk = b"\0" * chunk_size
    total_bytes = chunk_size * num_chunks

    try:
        conn = http.client.HTTPSConnection("speed.cloudflare.com", timeout=6)
        conn.connect()
        conn.putrequest("POST", "/__up")
        conn.putheader("User-Agent", "curl/8.0")
        conn.putheader("Content-Type", "application/octet-stream")
        conn.putheader("Content-Length", str(total_bytes))
        conn.endheaders()

        t0 = time.time()
        uploaded = 0
        last_report = t0
        for i in range(num_chunks):
            conn.send(chunk)
            uploaded += chunk_size
            now = time.time()
            dt = now - t0
            if dt >= 3.5:
                break
            if now - last_report >= 0.20:
                cur_up = (uploaded * 8 / 1_000_000) / dt if dt > 0 else 0
                prog = min(0.95, 0.65 + 0.30 * (dt / 3.5))
                report("upload", down=down_mbps, up=cur_up, ping=ping_val, progress=prog)
                last_report = now

        resp = conn.getresponse()
        resp.read()
        dt = time.time() - t0
        up_mbps = (uploaded * 8 / 1_000_000) / dt if dt > 0 else 0
        conn.close()
    except Exception as e:
        report("error", down=down_mbps, ping=ping_val, error="Falha no teste de upload: " + str(e))
        return

    # Done!
    report(
        "done",
        down=down_mbps,
        up=up_mbps,
        ping=ping_val,
        progress=1.0,
        done=True,
    )


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, SystemExit):
        pass
