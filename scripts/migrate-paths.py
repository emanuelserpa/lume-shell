#!/usr/bin/env python3
"""Run one-shot idempotent XDG path migration from legacy names to lume-shell."""

import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from lume_paths import migrate_all


def main() -> int:
    try:
        data = migrate_all()
        print(json.dumps({"ok": True, "version": 1, "data": data, "error": None}))
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "version": 1, "data": None, "error": str(exc)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
