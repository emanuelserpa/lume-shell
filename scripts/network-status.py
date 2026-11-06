#!/usr/bin/env python3
import json
import re
import sys
import time
from command_utils import run_command

def run(args, timeout=8):
    return run_command(args, timeout, error_code=1, timeout_code=None)

def lines(args, timeout=8):
    rc, out, err = run(args, timeout=timeout)
    if rc != 0:
        return []
    return [x for x in out.splitlines() if x.strip()]

def parse_bool(s):
    return str(s).strip().lower() in ("enabled", "yes", "true", "on")

def wifi_icon_5level(signal):
    if signal >= 80: return "󰤨"
    if signal >= 60: return "󰤥"
    if signal >= 40: return "󰤢"
    if signal >= 20: return "󰤟"
    return "󰤯"

def parse_saved_connections(raw_lines):
    saved = {}
    vpn_profiles = []
    for line in raw_lines:
        parts = line.split(":")
        if len(parts) < 3:
            continue
        name, uuid, ctype = parts[0], parts[1], ":".join(parts[2:])
        rec = {"name": name, "uuid": uuid, "type": ctype}
        if ctype in ("802-11-wireless", "wifi"):
            saved[name] = rec
        elif ctype in ("vpn", "wireguard"):
            vpn_profiles.append(rec)
    return saved, vpn_profiles

def parse_active_connections(raw_lines):
    active_uuids = set()
    active_connection = ""
    active_ssid = ""
    active_device = ""
    active_type = "none"
    for line in raw_lines:
        parts = line.split(":")
        if len(parts) < 4:
            continue
        name, uuid, ctype, dev = parts[0], parts[1], parts[2], ":".join(parts[3:])
        active_uuids.add(uuid)
        if ctype in ("802-11-wireless", "wifi") and not active_connection:
            active_connection = name
            active_ssid = name
            active_device = dev
            active_type = "wifi"
        elif ctype in ("ethernet", "802-3-ethernet") and not active_connection:
            active_connection = name
            active_ssid = name
            active_device = dev
            active_type = "ethernet"
    return active_uuids, {
        "active_connection": active_connection,
        "active_ssid": active_ssid,
        "active_device": active_device,
        "active_type": active_type,
    }

def main():
    do_scan = "--scan" in sys.argv

    data = {
        "ok": True,
        "version": 1,
        "text": "",
        "tooltip": "",
        "wifi_enabled": False,
        "active_ssid": "",
        "active_connection": "",
        "active_device": "",
        "active_type": "none",
        "active_ip": "",
        "active_signal": 0,
        "active_freq": "",
        "rx_bytes": 0,
        "tx_bytes": 0,
        "portal": False,
        "networks": [],
        "vpns": [],
        "status": "ok",
        "error": None,
    }

    rc, wifi_state, err = run(["nmcli", "-t", "-f", "WIFI", "general"])
    if rc != 0:
        data["ok"] = False
        data["status"] = "error"
        data["text"] = "󰤭"
        data["tooltip"] = "NetworkManager indisponível"
        data["error"] = err or "NetworkManager indisponível"
        print(json.dumps(data, ensure_ascii=False))
        return

    data["wifi_enabled"] = parse_bool(wifi_state)

    # Saved connections
    saved, vpn_profiles = parse_saved_connections(
        lines(["nmcli", "-t", "--escape", "no", "-f", "NAME,UUID,TYPE", "connection", "show"])
    )

    # Active connections
    active_uuids, active_info = parse_active_connections(
        lines(["nmcli", "-t", "--escape", "no", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show", "--active"])
    )
    if active_info["active_connection"]:
        data["active_connection"] = active_info["active_connection"]
        data["active_ssid"] = active_info["active_ssid"]
        data["active_device"] = active_info["active_device"]
        data["active_type"] = active_info["active_type"]

    dev = data["active_device"]
    if dev:
        # Local IPv4
        _, ip_out, _ = run(["nmcli", "-t", "-g", "IP4.ADDRESS", "dev", "show", dev])
        if ip_out:
            data["active_ip"] = ip_out.splitlines()[0].split("/")[0]

        # sysfs traffic stats
        try:
            with open(f"/sys/class/net/{dev}/statistics/rx_bytes") as f:
                data["rx_bytes"] = int(f.read().strip())
            with open(f"/sys/class/net/{dev}/statistics/tx_bytes") as f:
                data["tx_bytes"] = int(f.read().strip())
        except Exception:
            pass

        # Wi-Fi active signal and frequency
        if data["active_type"] == "wifi":
            _, wout, _ = run(["nmcli", "-t", "-f", "IN-USE,SIGNAL,FREQ", "dev", "wifi", "list", "ifname", dev, "--rescan", "no"])
            for wline in wout.splitlines():
                if wline.startswith("*"):
                    wparts = wline.split(":")
                    if len(wparts) >= 3:
                        try:
                            data["active_signal"] = int(wparts[1] or 0)
                        except ValueError:
                            pass
                        m = re.search(r"(\d+)", wparts[2])
                        if m:
                            f_mhz = int(m.group(1))
                            if 2400 <= f_mhz <= 2500:
                                data["active_freq"] = "2.4 GHz"
                            elif 5000 <= f_mhz <= 5900:
                                data["active_freq"] = "5 GHz"
                            elif f_mhz > 5900:
                                data["active_freq"] = "6 GHz"
                    break

        # Captive portal check
        rc, conn_check, _ = run(["nmcli", "networking", "connectivity", "check"], timeout=2)
        if conn_check.strip().lower() == "portal":
            data["portal"] = True

    # Visible Wi-Fi networks are intentionally scanned only on explicit
    # request (--scan). Normal bar polling never triggers a radio scan.
    visible = {}
    if do_scan and data["wifi_enabled"]:
        # NetworkManager starts scans asynchronously. Poll its cache briefly
        # so the first popup open does not mistake an in-progress scan for an
        # empty network list.
        run(["nmcli", "device", "wifi", "rescan"], timeout=3)
        wifi_list_args = [
            "nmcli", "-t", "--escape", "no",
            "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "--rescan", "no"
        ]
        scan_deadline = time.monotonic() + 3.0
        scan_lines = []
        while True:
            scan_lines = lines(wifi_list_args, timeout=3)
            if scan_lines or time.monotonic() >= scan_deadline:
                break
            time.sleep(0.4)

        for line in scan_lines:
            parts = line.split(":")
            if len(parts) < 4:
                continue
            in_use = parts[0].strip() == "*"
            ssid = parts[1].strip()
            if not ssid:
                continue
            try:
                signal = int(parts[2].strip() or "0")
            except ValueError:
                signal = 0
            security = ":".join(parts[3:]).strip()
            prev = visible.get(ssid)
            if prev is None or signal > prev["signal"]:
                saved_rec = saved.get(ssid)
                visible[ssid] = {
                    "ssid": ssid,
                    "signal": signal,
                    "security": security,
                    "secure": bool(security and security != "--"),
                    "active": in_use or ssid == data["active_ssid"],
                    "saved": saved_rec is not None,
                    "uuid": saved_rec["uuid"] if saved_rec else "",
                }

    networks = list(visible.values())
    networks.sort(key=lambda x: (not x["active"], -x["signal"], x["ssid"].lower()))
    data["networks"] = networks

    vpns = []
    for rec in vpn_profiles:
        vpns.append({
            "name": rec["name"],
            "uuid": rec["uuid"],
            "type": rec["type"],
            "active": rec["uuid"] in active_uuids,
        })
    vpns.sort(key=lambda x: (not x["active"], x["name"].lower()))
    data["vpns"] = vpns

    if data["active_type"] == "wifi" and data["active_ssid"]:
        short = data["active_ssid"]
        if len(short) > 18:
            short = short[:17] + "…"
        icon = wifi_icon_5level(data["active_signal"])
        data["text"] = icon + " " + short
        extra = []
        if data["active_freq"]:
            extra.append(data["active_freq"])
        if data["active_ip"]:
            extra.append(data["active_ip"])
        extra_str = f" • {' • '.join(extra)}" if extra else ""
        data["tooltip"] = f"Wi‑Fi: {data['active_ssid']}{extra_str}"
    elif data["active_type"] == "ethernet":
        short = data["active_connection"] or data["active_device"]
        data["text"] = "󰈀 " + short
        extra_ip = f" • {data['active_ip']}" if data["active_ip"] else ""
        data["tooltip"] = f"Ethernet: {short}{extra_ip}"
    elif data["wifi_enabled"]:
        data["text"] = "󰤯"
        data["tooltip"] = "Wi‑Fi: Desconectado"
    else:
        data["text"] = "󰤮"
        data["tooltip"] = "Rede desconectada"

    print(json.dumps(data, ensure_ascii=False))

if __name__ == "__main__":
    main()
