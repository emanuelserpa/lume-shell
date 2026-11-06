#!/usr/bin/env python3
"""Read the active backlight as a versioned JSON result for QML."""
import csv
import json
import sys

sys.dont_write_bytecode = True

from command_utils import run_command

VERSION = 1


def parse_status(output: str, returncode: int = 0, error: str = "") -> dict:
    if returncode != 0:
        return {
            "ok": False,
            "version": VERSION,
            "available": False,
            "brightness": 0,
            "device": "",
            "error": error.strip() or "Não foi possível ler o brilho.",
        }

    line = next((row for row in output.splitlines() if row.strip()), "")
    try:
        fields = next(csv.reader([line]))
    except (csv.Error, StopIteration):
        fields = []

    percent_text = next((field.strip()[:-1] for field in fields
                         if field.strip().endswith("%")), "")
    try:
        percent = int(percent_text)
    except ValueError:
        percent = -1

    if not 0 <= percent <= 100:
        return {
            "ok": False,
            "version": VERSION,
            "available": False,
            "brightness": 0,
            "device": fields[0].strip() if fields else "",
            "error": "Saída inválida do brightnessctl.",
        }

    return {
        "ok": True,
        "version": VERSION,
        "available": True,
        "brightness": percent,
        "device": fields[0].strip() if fields else "",
        "error": None,
    }


def get_status() -> dict:
    returncode, output, error = run_command(
        ["brightnessctl", "-m"], timeout=8, timeout_code=None
    )
    return parse_status(output, returncode, error)


def main() -> None:
    print(json.dumps(get_status(), ensure_ascii=False))


if __name__ == "__main__":
    main()
