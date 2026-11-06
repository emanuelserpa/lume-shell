#!/usr/bin/env python3
import json
import re
import sys

from bt_ctl import run_bt as run

def is_address_like(s):
    return bool(re.match(r"^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$", s, re.I))

def is_uuid_like(s):
    return bool(re.match(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", s, re.I)) or bool(re.match(r"^[0-9a-f]{32}$", s, re.I))

def has_human_name(name):
    if not name:
        return False
    name = name.strip()
    if not name:
        return False
    if is_address_like(name) or is_uuid_like(name):
        return False
    # Filter out hex dumps like 68-45-78-90-AB-CD
    if bool(re.match(r"^([0-9A-Fa-f]{2}[-_:]){2,}", name)):
        return False
    return True

def parse_bt_show(out, rc=0, err=""):
    powered = False
    discoverable = False
    pairable = False
    controller = ""
    alias = ""

    if rc == 0:
        for line in out.splitlines():
            s = line.strip()
            if s.startswith("Controller "):
                parts = s.split()
                if len(parts) >= 2:
                    controller = parts[1]
            elif s.startswith("Alias:"):
                alias = s.split(":", 1)[1].strip()
            elif s.startswith("Powered:"):
                powered = s.split(":", 1)[1].strip().lower() == "yes"
            elif s.startswith("Discoverable:"):
                discoverable = s.split(":", 1)[1].strip().lower() == "yes"
            elif s.startswith("Pairable:"):
                pairable = s.split(":", 1)[1].strip().lower() == "yes"

    available = rc == 0 and bool(controller)

    return {
        "ok": available,
        "version": 1,
        "available": available,
        "error": None if available else (
            err or out or "Nenhum controlador Bluetooth disponível."
        ),
        "powered": powered,
        "discoverable": discoverable,
        "pairable": pairable,
        "controller": controller,
        "controller_alias": alias,
    }

def bt_show():
    rc, out, err = run(["bluetoothctl", "show"], timeout=4)
    return parse_bt_show(out, rc, err)

def parse_device_list(out, rc=0):
    devs = []
    if rc != 0:
        return devs
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith("Device "):
            continue
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        mac = parts[1].strip()
        name = parts[2].strip()
        devs.append((mac, name))
    return devs

def get_devices(arg=None):
    cmd = ["bluetoothctl", "devices"]
    if arg:
        cmd.append(arg)
    rc, out, _ = run(cmd, timeout=4)
    return parse_device_list(out, rc)

def parse_device_info(out, mac, fallback_name, rc=0):
    rec = {
        "mac": mac,
        "name": fallback_name,
        "alias": fallback_name,
        "paired": False,
        "trusted": False,
        "connected": False,
        "blocked": False,
        "icon": "",
        "battery": -1,
    }

    if rc != 0:
        return rec

    for line in out.splitlines():
        s = line.strip()
        if s.startswith("Name:"):
            rec["name"] = s.split(":", 1)[1].strip()
        elif s.startswith("Alias:"):
            rec["alias"] = s.split(":", 1)[1].strip()
        elif s.startswith("Paired:"):
            rec["paired"] = s.split(":", 1)[1].strip().lower() == "yes"
        elif s.startswith("Trusted:"):
            rec["trusted"] = s.split(":", 1)[1].strip().lower() == "yes"
        elif s.startswith("Connected:"):
            rec["connected"] = s.split(":", 1)[1].strip().lower() == "yes"
        elif s.startswith("Blocked:"):
            rec["blocked"] = s.split(":", 1)[1].strip().lower() == "yes"
        elif s.startswith("Icon:"):
            rec["icon"] = s.split(":", 1)[1].strip()
        elif s.startswith("Battery Percentage:"):
            value = s.split(":", 1)[1].strip()
            if "(" in value and ")" in value:
                try:
                    rec["battery"] = int(value.split("(", 1)[1].split(")", 1)[0])
                except Exception:
                    pass

    return rec

def info(mac, fallback_name):
    rc, out, _ = run(["bluetoothctl", "info", mac], timeout=3)
    return parse_device_info(out, mac, fallback_name, rc)

def main():
    state = bt_show()
    connected = []
    paired = []
    discovered = []

    if state["powered"]:
        # 1. Connected devices
        conn_tuples = get_devices("Connected")
        conn_macs = set()
        for mac, name in conn_tuples:
            conn_macs.add(mac)
            d = info(mac, name)
            d["connected"] = True
            connected.append(d)

        # 2. Paired devices
        paired_tuples = get_devices("Paired")
        paired_macs = set()
        for mac, name in paired_tuples:
            paired_macs.add(mac)
            if mac not in conn_macs:
                d = info(mac, name)
                paired.append(d)

        # 3. Discovered / nearby devices (from general list, excluding paired/connected and non-human names)
        all_devs = get_devices()
        for mac, name in all_devs:
            if mac in conn_macs or mac in paired_macs:
                continue
            if not has_human_name(name):
                continue
            discovered.append({
                "mac": mac,
                "name": name,
                "alias": name,
                "paired": False,
                "trusted": False,
                "connected": False,
                "blocked": False,
                "icon": "",
                "battery": -1,
            })

    connected.sort(key=lambda d: (d["alias"] or d["name"]).lower())
    paired.sort(key=lambda d: (d["alias"] or d["name"]).lower())
    discovered.sort(key=lambda d: (d["alias"] or d["name"]).lower())

    data = {
        **state,
        "connected_count": len(connected),
        "connected": connected,
        "paired_devices": paired,
        "discovered": discovered,
        "text": "" if state["powered"] else "󰂲",
    }

    if not state["available"]:
        data["tooltip"] = "Bluetooth indisponível"
    elif not state["powered"]:
        data["tooltip"] = "Bluetooth desligado"
    elif len(connected) == 0:
        data["tooltip"] = "Bluetooth: Nenhum dispositivo"
    elif len(connected) == 1:
        dev = connected[0]
        name = dev["alias"] or dev["name"]
        bat = f" • {dev['battery']}%" if dev["battery"] >= 0 else ""
        data["tooltip"] = f"Bluetooth: {name}{bat}"
    else:
        names = ", ".join((d["alias"] or d["name"]) for d in connected[:2])
        if len(connected) > 2:
            names += f" +{len(connected) - 2}"
        data["tooltip"] = f"Bluetooth: {names}"

    print(json.dumps(data, ensure_ascii=False))

if __name__ == "__main__":
    main()
