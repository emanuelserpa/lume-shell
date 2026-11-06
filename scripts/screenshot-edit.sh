#!/usr/bin/env bash
# screenshot-edit.sh — Screenshot normal e/ou abre no swappy.
#
# Uso:
#   screenshot-edit.sh [output|area]  salva + clipboard e abre no editor
#   screenshot-edit.sh last           abre o último screenshot no editor
set -uo pipefail

DIR="${XDG_SCREENSHOT_DIR:-$(xdg-user-dir PICTURES 2>/dev/null)/Screenshots}"
DIR="${DIR%/}"
mkdir -p "$DIR" 2>/dev/null || true

if [ "${1:-output}" = "last" ]; then
    FILE="$(ls -t "$DIR"/*.png 2>/dev/null | head -n 1)"
    if [ -z "${FILE:-}" ] || [ ! -f "$FILE" ]; then
        notify-send -a quickshell "Screenshot" "Nenhum screenshot em $DIR."
        exit 1
    fi
    exec swappy -f "$FILE"
fi

MODE="${1:-output}"
FILE="$(XDG_SCREENSHOT_DIR="$DIR" "$(dirname "$0")/screenshot.sh" "$MODE" 2>/dev/null | tail -n 1)"
[ -n "${FILE:-}" ] && [ -f "$FILE" ] || exit 0

exec swappy -f "$FILE"
