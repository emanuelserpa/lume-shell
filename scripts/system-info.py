#!/usr/bin/env python3
"""Return normalized system details for the Spotlight system-info popup."""

import json
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True

VERSION = 1
STRUCTURE = (
    "OS:Host:Kernel:Uptime:Packages:Shell:WM:Terminal:CPU:GPU:Memory:Disk:Battery:Display"
)


def _module_map(modules):
    if not isinstance(modules, list):
        raise ValueError("Fastfetch retornou uma estrutura inválida")
    return {
        str(module.get("type", "")).lower(): module.get("result")
        for module in modules
        if isinstance(module, dict) and "result" in module
    }


def _first(value):
    return value[0] if isinstance(value, list) and value else {}


def _positive_int(value):
    try:
        return max(0, int(value))
    except (TypeError, ValueError, OverflowError):
        return 0


def parse_fastfetch(payload):
    """Map Fastfetch's module-oriented JSON to the shell's stable contract."""
    modules = _module_map(payload)
    os_info = modules.get("os") or {}
    host = modules.get("host") or {}
    kernel = modules.get("kernel") or {}
    packages = modules.get("packages") or {}
    shell = modules.get("shell") or {}
    wm = modules.get("wm") or {}
    terminal = modules.get("terminal") or {}
    cpu = modules.get("cpu") or {}
    memory = modules.get("memory") or {}
    disk = _first(modules.get("disk"))
    battery = _first(modules.get("battery"))
    display = _first(modules.get("display"))
    disk_bytes = disk.get("bytes") if isinstance(disk, dict) else {}
    display_output = display.get("output") if isinstance(display, dict) else {}

    os_name = str(os_info.get("prettyName") or os_info.get("name") or "").strip()
    if not os_name:
        raise ValueError("Fastfetch não encontrou o sistema operacional")

    gpu_items = modules.get("gpu") or []
    gpus = []
    if isinstance(gpu_items, dict):
        gpu_items = [gpu_items]
    for gpu in gpu_items:
        if not isinstance(gpu, dict):
            continue
        name = str(gpu.get("name") or "").strip()
        vendor = str(gpu.get("vendor") or "").strip()
        if name and vendor and not name.lower().startswith(vendor.lower()):
            name = vendor + " " + name
        if name:
            gpus.append({
                "name": name,
                "type": str(gpu.get("type") or "").strip(),
                "driver": str(gpu.get("driver") or "").strip(),
            })

    battery_status = battery.get("status") if isinstance(battery, dict) else []
    if isinstance(battery_status, list):
        battery_status = ", ".join(str(status) for status in battery_status if status)

    return {
        "os": os_name,
        "osId": str(os_info.get("id") or ""),
        "host": str(host.get("family") or host.get("version") or host.get("name") or ""),
        "kernel": str(kernel.get("release") or ""),
        "architecture": str(kernel.get("architecture") or ""),
        "uptimeSeconds": _positive_int((modules.get("uptime") or {}).get("uptime")),
        "shell": " ".join(filter(None, (
            str(shell.get("prettyName") or shell.get("exeName") or "").strip(),
            str(shell.get("version") or "").strip(),
        ))),
        "desktop": " ".join(filter(None, (
            str(wm.get("prettyName") or wm.get("processName") or "").strip(),
            str(wm.get("version") or "").strip(),
        ))),
        "protocol": str(wm.get("protocolName") or "").strip(),
        "terminal": " ".join(filter(None, (
            str(terminal.get("prettyName") or terminal.get("processName") or "").strip(),
            str(terminal.get("version") or "").strip(),
        ))),
        "cpu": str(cpu.get("cpu") or "").strip(),
        "cpuCores": _positive_int((cpu.get("cores") or {}).get("physical")),
        "cpuThreads": _positive_int((cpu.get("cores") or {}).get("logical")),
        "gpu": gpus,
        "memory": {
            "used": _positive_int(memory.get("used")),
            "total": _positive_int(memory.get("total")),
        },
        "disk": {
            "used": _positive_int(disk_bytes.get("used")),
            "total": _positive_int(disk_bytes.get("total")),
            "mountpoint": str(disk.get("mountpoint") or "/"),
        },
        "battery": {
            "capacity": _positive_int(battery.get("capacity")),
            "status": str(battery_status or ""),
        },
        "display": {
            "name": str(display.get("name") or ""),
            "width": _positive_int(display_output.get("width")),
            "height": _positive_int(display_output.get("height")),
        },
        "packages": {
            "total": _positive_int(packages.get("all")),
            "pacman": _positive_int(packages.get("pacman")),
            "flatpak": _positive_int(packages.get("flatpakUser")),
            "brew": _positive_int(packages.get("brew")),
            "appimage": _positive_int(packages.get("appimage")),
        },
    }


def get_status(binary=None):
    fastfetch = binary or shutil.which("fastfetch")
    if not fastfetch:
        return {
            "ok": False,
            "version": VERSION,
            "data": {},
            "error": "Fastfetch não encontrado",
        }

    try:
        completed = subprocess.run(
            [fastfetch, "--config", "none", "--structure", STRUCTURE, "--format", "json"],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
        )
        if completed.returncode != 0:
            message = completed.stderr.strip() or "Falha ao consultar Fastfetch"
            raise ValueError(message)
        data = parse_fastfetch(json.loads(completed.stdout))
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, ValueError) as error:
        return {"ok": False, "version": VERSION, "data": {}, "error": str(error)}

    return {"ok": True, "version": VERSION, "data": data, "error": None}


def main():
    print(json.dumps(get_status(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
