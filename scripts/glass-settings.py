#!/usr/bin/env python3
"""Read and persist the shell glass opacity preference."""

import json
import math
import os
import sys
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "quickshell"
STATE_FILE = STATE_DIR / "glass.json"
DEFAULT_ALPHA = 0.68
MIN_ALPHA = 0.35
MAX_ALPHA = 0.90


def result(ok, **values):
    print(json.dumps({"ok": ok, "version": 1, **values}, ensure_ascii=False))


def read_alpha():
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        value = float(data.get("alpha", DEFAULT_ALPHA))
        if not math.isfinite(value):
            return DEFAULT_ALPHA
        return max(MIN_ALPHA, min(MAX_ALPHA, value))
    except FileNotFoundError:
        return DEFAULT_ALPHA
    except (OSError, ValueError, TypeError, AttributeError):
        return DEFAULT_ALPHA


def main(argv):
    action = argv[1] if len(argv) > 1 else "get"
    if action == "get":
        result(True, alpha=read_alpha())
        return 0
    if action == "set" and len(argv) == 3:
        try:
            alpha = round(max(MIN_ALPHA, min(MAX_ALPHA, float(argv[2]))), 2)
            STATE_DIR.mkdir(parents=True, exist_ok=True)
            temporary = STATE_FILE.with_suffix(".json.tmp")
            temporary.write_text(json.dumps({"version": 1, "alpha": alpha}) + "\n", encoding="utf-8")
            temporary.replace(STATE_FILE)
            result(True, alpha=alpha)
            return 0
        except (OSError, ValueError) as error:
            result(False, error=str(error))
            return 1
    result(False, error="Uso: glass-settings.py [get|set <alpha>]")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
