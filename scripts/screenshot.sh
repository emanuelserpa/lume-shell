#!/usr/bin/env bash
# Capture a screenshot to the usual folder and copy it to the clipboard.
set -euo pipefail

mode="${1:-output}"
pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || printf '%s' "$HOME/Pictures")"
dir="${XDG_SCREENSHOT_DIR:-$pictures_dir/Screenshots}"
mkdir -p "$dir"

case "$mode" in
    output|area) ;;
    *) echo "Usage: screenshot.sh [output|area]" >&2; exit 2 ;;
esac

if [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] && command -v grimblast >/dev/null 2>&1; then
    exec env DEFAULT_TARGET_DIR="$dir" grimblast copysave "$mode"
fi

geometry=()
if [ "$mode" = area ]; then
    region="$(slurp)" || exit 0
    [ -n "$region" ] || exit 0
    geometry=(-g "$region")
fi

file="$dir/$(date +%Y-%m-%d_%H-%M-%S_%N).png"
grim "${geometry[@]}" "$file"
wl-copy --type image/png < "$file"
printf '%s\n' "$file"
