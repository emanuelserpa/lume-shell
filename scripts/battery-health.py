#!/usr/bin/env python3
"""Report battery health from Linux power-supply design capacity."""
import glob
import json
from pathlib import Path

VERSION = 1


def detect_battery():
    candidates = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    return Path(candidates[0]).name if candidates else None


def read_int_file(path):
    try:
        return int(Path(path).read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None


def current_state():
    battery = detect_battery()
    base = Path("/sys/class/power_supply") / battery if battery else None
    full = read_int_file(base / "energy_full") if base else None
    design = read_int_file(base / "energy_full_design") if base else None
    if full is None or design is None or full <= 0 or design <= 0:
        return {
            "ok": True,
            "version": VERSION,
            "available": False,
            "health_percentage": 0,
            "error": None,
        }

    health = max(0.0, min(100.0, full / design * 100))
    return {
        "ok": True,
        "version": VERSION,
        "available": True,
        "battery": battery,
        "health_percentage": round(health, 1),
        "error": None,
    }


def main():
    print(json.dumps(current_state(), ensure_ascii=False))


if __name__ == "__main__":
    main()
