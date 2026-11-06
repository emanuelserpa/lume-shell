#!/usr/bin/env python3
"""Running Steam game detector. JSON contract for QML.

Detects games by the ``steam_app_<id>`` token Steam places in game
process command lines (covers Proton and native titles) and resolves
display names from ``appmanifest_<id>.acf``.

Usage:
    game-status.py            -> JSON envelope, no side effects

Env overrides (tests):
    QSGAME_PROC       fake /proc root
    QSGAME_STEAMAPPS  fake steamapps dir
"""
import json
import os
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True

VERSION = 1
APP_RE = re.compile(r"steam_app_(\d+)", re.IGNORECASE)
NAME_RE = re.compile(r'"name"\s+"([^"]+)"')


def find_steam_apps(proc_root="/proc"):
    """Return sorted unique Steam app ids seen in process command lines."""
    found = set()
    try:
        entries = os.listdir(proc_root)
    except OSError:
        return []
    for pid in entries:
        if not pid.isdigit():
            continue
        try:
            with open(os.path.join(proc_root, pid, "cmdline"), "rb") as fh:
                raw = fh.read().decode("utf-8", "replace")
        except OSError:
            continue
        for match in APP_RE.finditer(raw):
            found.add(match.group(1))
    return sorted(found, key=int)


def default_steamapps():
    override = os.environ.get("QSGAME_STEAMAPPS")
    if override:
        return Path(override)
    return Path.home() / ".local" / "share" / "Steam" / "steamapps"


def app_name(steamapps_dir, app_id):
    manifest = Path(steamapps_dir) / f"appmanifest_{app_id}.acf"
    try:
        text = manifest.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    match = NAME_RE.search(text)
    return match.group(1).strip() if match else ""


def get_status(proc_root=None, steamapps_dir=None):
    proc_root = proc_root or os.environ.get("QSGAME_PROC", "/proc")
    steamapps_dir = steamapps_dir or default_steamapps()
    ids = find_steam_apps(proc_root)
    games = []
    for app_id in ids:
        name = app_name(steamapps_dir, app_id)
        games.append({
            "app_id": app_id,
            "name": name or f"App {app_id}",
        })
    return {
        "ok": True,
        "version": VERSION,
        "available": True,
        "active": len(games) > 0,
        "count": len(games),
        "games": games,
        "error": None,
    }


def main():
    print(json.dumps(get_status(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
