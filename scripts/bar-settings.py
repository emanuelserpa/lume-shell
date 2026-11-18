#!/usr/bin/env python3
"""Read and persist the bar's visual surface preference."""

import json
import os
import sys
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "quickshell"
CONFIG_FILE = CONFIG_DIR / "bar.json"
MODES = {"islands", "continuous"}
DEFAULT_MODE = "islands"


def read_mode():
    try:
        data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        mode = data.get("surface", DEFAULT_MODE)
        return mode if mode in MODES else DEFAULT_MODE
    except (FileNotFoundError, OSError, ValueError, TypeError, AttributeError):
        return DEFAULT_MODE


def write_mode(mode):
    if mode not in MODES:
        raise ValueError("modo deve ser 'islands' ou 'continuous'")
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    temporary = CONFIG_FILE.with_suffix(".json.tmp")
    temporary.write_text(json.dumps({"version": 1, "surface": mode}) + "\n", encoding="utf-8")
    temporary.replace(CONFIG_FILE)


def main(argv):
    action = argv[1] if len(argv) > 1 else "get"
    if action == "get":
        print(json.dumps({"ok": True, "version": 1, "surface": read_mode()}))
        return 0
    if action == "set" and len(argv) == 3:
        try:
            write_mode(argv[2])
            print(json.dumps({"ok": True, "version": 1, "surface": argv[2]}))
            return 0
        except (OSError, ValueError) as error:
            print(json.dumps({"ok": False, "version": 1, "error": str(error)}))
            return 1
    print(json.dumps({"ok": False, "version": 1, "error": "Uso: bar-settings.py [get|set islands|continuous]"}))
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
