#!/usr/bin/env python3
"""Apply a backlight percentage and return a versioned JSON result."""
import json
import sys

sys.dont_write_bytecode = True

from command_utils import run_command

VERSION = 1


def set_brightness(value: str) -> tuple[dict, int]:
    try:
        percent = int(value)
    except (TypeError, ValueError):
        return ({"ok": False, "version": VERSION, "brightness": None,
                 "error": "Brilho inválido."}, 2)
    if not 1 <= percent <= 100:
        return ({"ok": False, "version": VERSION, "brightness": None,
                 "error": "O brilho deve ficar entre 1 e 100."}, 2)

    code, _output, error = run_command(
        ["brightnessctl", "set", f"{percent}%"], timeout=12, timeout_code=None
    )
    if code != 0:
        return ({"ok": False, "version": VERSION, "brightness": percent,
                 "error": error or "Não foi possível alterar o brilho."}, 1)
    return ({"ok": True, "version": VERSION, "brightness": percent,
             "error": None}, 0)


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2 or args[0] != "set":
        result = {"ok": False, "version": VERSION, "brightness": None,
                  "error": "Uso: brightness-action.py set <1-100>"}
        code = 2
    else:
        result, code = set_brightness(args[1])
    print(json.dumps(result, ensure_ascii=False))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
