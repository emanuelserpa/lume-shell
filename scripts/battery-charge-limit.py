#!/usr/bin/env python3
"""Battery charge-limit helper (ThinkPad ACPI sysfs).

Reads the firmware charge threshold and toggles between the eco limit
(75/80) and a one-shot full charge (100, "travel mode").

Usage:
    battery-charge-limit.py status        -> JSON envelope with current limit
    battery-charge-limit.py set 80|100    -> apply limit, JSON envelope

JSON contract (same envelope as the other helpers):
    {"ok": bool, "version": 1, "error": str | None, ...}

The `set` path uses a fixed, allowlisted Polkit helper.
"""
import glob
import json
import shutil
from command_utils import run_command
import sys
from pathlib import Path

VERSION = 1
ECO_START = 75
ECO_STOP = 80
FULL = 100
PRIVILEGED_HELPER = Path("/usr/local/libexec/quickshell-battery-charge-limit")


def detect_battery():
    """First available BAT* supply, preferring BAT0. None when absent."""
    candidates = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    if not candidates:
        return None
    names = [Path(c).name for c in candidates]
    if "BAT0" in names:
        return "BAT0"
    return names[0]


def end_threshold_path(bat):
    return Path(f"/sys/class/power_supply/{bat}/charge_control_end_threshold")


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))


def run(args, timeout=10.0):
    return run_command(args, timeout, error_code=127, timeout_code=None)


def read_int_file(path):
    try:
        return int(Path(path).read_text(encoding="utf-8").strip())
    except Exception:
        return None


def on_ac():
    for candidate in glob.glob("/sys/class/power_supply/AC*/online"):
        value = read_int_file(candidate)
        if value == 1:
            return True
    return False


def current_state():
    bat = detect_battery()
    limit = read_int_file(end_threshold_path(bat)) if bat else None
    if bat is None or limit is None:
        return {
            "ok": False,
            "version": VERSION,
            "available": False,
            "limit": 0,
            "on_ac": on_ac(),
            "error": "Sensor de limite de carga não encontrado.",
        }
    return {
        "ok": True,
        "version": VERSION,
        "available": True,
        "battery": bat,
        "limit": limit,
        "on_ac": on_ac(),
        "error": None,
    }


def apply_limit(limit, runner=run, which=shutil.which, helper_path=PRIVILEGED_HELPER,
                ac_power=on_ac):
    if not ac_power():
        return False, "Conecte o carregador para alterar o limite de carga."

    if Path(helper_path).is_file():
        pkexec = which("pkexec")
        if not pkexec:
            return False, "É necessária autorização administrativa (pkexec não encontrado)."
        rc, _, err = runner([pkexec, str(helper_path), str(limit)], timeout=60.0)
        return (rc == 0, "" if rc == 0 else err or "A alteração foi cancelada ou não autorizada.")

    return False, "A integração segura de limite de carga não está instalada."


def main():
    args = sys.argv[1:]

    if not args or args[0] == "status":
        emit(current_state())
        return 0

    if args[0] == "set":
        if len(args) < 2 or args[1] not in ("80", "100"):
            emit({"ok": False, "version": VERSION, "error": "Limite inválido (use 80 ou 100)."})
            return 2
        limit = int(args[1])
        ok, err = apply_limit(limit)
        result = current_state()
        result.update({"ok": ok, "error": err or None})
        emit(result)
        return 0 if ok else 1

    emit({"ok": False, "version": VERSION, "error": "Comando desconhecido."})
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
