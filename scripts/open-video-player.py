#!/usr/bin/env python3
"""Open a validated HTTP(S) URL in Aurora MPV, falling back to mpv."""

import os
import shutil
import sys
from urllib.parse import urlsplit


def valid_url(value: str) -> bool:
    if not value or len(value) > 2048 or any(ch.isspace() or ord(ch) < 32 for ch in value):
        return False
    try:
        parsed = urlsplit(value)
        return parsed.scheme.lower() in ("http", "https") and bool(parsed.netloc)
    except ValueError:
        return False


def find_player(which=shutil.which):
    return which("aurora-mpv") or which("mpv")


def main(argv: list[str]) -> int:
    if len(argv) != 2 or not valid_url(argv[1]):
        print("Uso: open-video-player.py <URL HTTP(S)>", file=sys.stderr)
        return 2

    executable = find_player()
    if not executable:
        print("Aurora MPV ou mpv não está instalado.", file=sys.stderr)
        return 127

    os.execv(executable, [executable, argv[1]])
    return 127


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
