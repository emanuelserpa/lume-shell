#!/usr/bin/env python3
"""KDE Connect status helper for the Quickshell phone module.

Contract (v1):
  QML (bar/Phone.qml) -> this script -> kdeconnect-cli (+ gdbus battery) -> JSON -> QML

Output envelope (always JSON, never crashes):
{
    "ok": bool,            # binary present and list command ran
    "version": 1,
    "available": bool,     # kdeconnect-cli installed
    "daemon": bool,        # daemon answered the list command
    "visible": bool,       # pill should be shown (available)
    "reachable_count": int,
    "devices": [
        {"id": str, "name": str, "reachable": bool, "paired": bool,
         "battery": int, "charging": bool}
    ],
    "text": str,           # glanceable pill glyph
    "tooltip": str,
    "error": str | None
}

Notes:
- kdeconnect-cli has no --battery flag on current KDE (checked against
  kdeconnect-kde master cli/kdeconnect-cli.cpp); battery is best-effort
  via gdbus org.kde.kdeconnect battery interface, -1 when unknown.
- Polling is intentionally light; QML polls slower when popup is closed.
"""
import json
import re
import shutil
import sys
from command_utils import run_command as run

VERSION = 1

STATUS_RE = re.compile(
    r"^-\s+(?P<name>.*?):\s+(?P<id>\S+)\s*(?P<tail>.*)$"
)
STATUS_PAREN = re.compile(r"\(([^)]*)\)\s*$")
INT_RE = re.compile(r"(?<![A-Za-z0-9])(-?\d{1,3})(?![A-Za-z0-9])")


def parse_id_only(text):
    ids = []
    for line in (text or "").splitlines():
        s = line.strip()
        if s:
            ids.append(s.split()[0])
    return ids


def parse_list_human(text):
    """Parse `kdeconnect-cli -l` human output.

    Example lines:
      - Pixel 8: abc123def456 on 192.168.1.10 via lan (paired and reachable)
      - Tablet: xyz789 (paired)
      - Laptop: qwe123 (reachable)
    """
    devices = []
    for line in (text or "").splitlines():
        s = line.strip()
        if not s.startswith("- "):
            continue
        m = STATUS_RE.match(s)
        if not m:
            continue
        name = m.group("name").strip()
        dev_id = m.group("id").strip()
        tail = m.group("tail") or ""
        pm = STATUS_PAREN.search(tail)
        status = (pm.group(1) if pm else "").lower()
        paired = "paired" in status
        reachable = "reachable" in status
        if not dev_id:
            continue
        devices.append({
            "id": dev_id,
            "name": name or dev_id,
            "reachable": reachable,
            "paired": paired,
        })
    return devices


def parse_battery_gdbus_output(text):
    """Extract 0-100 charge from gdbus Get output. Returns -1 when unknown."""
    if not text:
        return -1
    for token in INT_RE.findall(text):
        try:
            v = int(token)
        except ValueError:
            continue
        if 0 <= v <= 100:
            return v
    return -1


def query_battery(dev_id, timeout=2):
    """Best-effort battery via gdbus. Returns (charge, charging)."""
    if not shutil.which("gdbus") or not dev_id:
        return -1, False
    obj = "/modules/kdeconnect/devices/%s/battery" % dev_id
    rc, out, _ = run([
        "gdbus", "call", "--session",
        "--dest", "org.kde.kdeconnect",
        "--object-path", obj,
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.kde.kdeconnect.device.battery", "charge",
    ], timeout=timeout)
    charge = parse_battery_gdbus_output(out) if rc == 0 else -1
    charging = False
    rc2, out2, _ = run([
        "gdbus", "call", "--session",
        "--dest", "org.kde.kdeconnect",
        "--object-path", obj,
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.kde.kdeconnect.device.battery", "isCharging",
    ], timeout=timeout)
    if rc2 == 0 and out2:
        low = out2.lower()
        charging = "true" in low or " 1" in low
    return charge, charging


def build_payload(devices, ok, available, daemon, error):
    reachable = [d for d in devices if d.get("reachable")]
    reachable.sort(key=lambda d: (d.get("name") or "").lower())
    offline = sorted(
        (d for d in devices if not d.get("reachable")),
        key=lambda d: (d.get("name") or "").lower(),
    )
    ordered = reachable + offline
    if not available:
        text = "󰏲"
        tooltip = "KDE Connect não instalado"
    elif not daemon:
        text = "󰏲"
        tooltip = "KDE Connect indisponível (daemon parado?)"
    elif not ordered:
        text = "󰏲"
        tooltip = "Nenhum aparelho KDE Connect"
    elif len(reachable) == 1:
        d = reachable[0]
        bat = " • %d%%" % d["battery"] if d.get("battery", -1) >= 0 else ""
        text = "󰏲"
        tooltip = "KDE Connect: %s%s" % (d.get("name") or d["id"], bat)
    elif reachable:
        names = ", ".join((d.get("name") or d["id"]) for d in reachable[:2])
        if len(reachable) > 2:
            names += " +%d" % (len(reachable) - 2)
        text = "󰏲 %d" % len(reachable)
        tooltip = "KDE Connect: %s" % names
    else:
        text = "󰏲"
        tooltip = "KDE Connect: %d pareado(s), nenhum alcançável" % len(ordered)
    return {
        "ok": bool(ok),
        "version": VERSION,
        "available": bool(available),
        "daemon": bool(daemon),
        "visible": bool(available),
        "reachable_count": len(reachable),
        "devices": ordered,
        "text": text,
        "tooltip": tooltip,
        "error": error,
    }


def get_status():
    if shutil.which("kdeconnect-cli") is None:
        return build_payload([], False, False, False, "kdeconnect-cli não encontrado")
    rc_list, out_list, err_list = run(["kdeconnect-cli", "-l"], timeout=8)
    if rc_list != 0 and not out_list:
        raw = (err_list or out_list or "Falha ao listar aparelhos.").splitlines()
        return build_payload([], False, True, False, raw[0][:180] if raw else "Falha ao listar aparelhos.")
    devices = parse_list_human(out_list)
    # Cross-check reachable set (cheap, authoritative for reachability).
    rc_av, out_av, _ = run(["kdeconnect-cli", "-a", "--id-only"], timeout=8)
    reachable_ids = set(parse_id_only(out_av)) if rc_av == 0 else None
    if reachable_ids is not None:
        for d in devices:
            d["reachable"] = d["id"] in reachable_ids
    # Battery only for reachable devices, capped to avoid spawn storms.
    for d in devices:
        d["battery"] = -1
        d["charging"] = False
    for d in [x for x in devices if x.get("reachable")][:5]:
        charge, charging = query_battery(d["id"])
        d["battery"] = charge
        d["charging"] = charging
    return build_payload(devices, True, True, True, None)


def main():
    print(json.dumps(get_status(), ensure_ascii=False))


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    main()
