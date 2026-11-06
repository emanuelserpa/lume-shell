#!/usr/bin/env bash
set -u

MODE="${1:-all}"
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$DIR/system-update.sh"

# Prefer Kitty, the configured terminal, then common alternatives.
if command -v kitty >/dev/null 2>&1; then
  exec kitty "$RUNNER" "$MODE"
elif command -v ghostty >/dev/null 2>&1; then
  exec ghostty -e "$RUNNER" "$MODE"
elif command -v foot >/dev/null 2>&1; then
  exec foot "$RUNNER" "$MODE"
elif command -v alacritty >/dev/null 2>&1; then
  exec alacritty -e "$RUNNER" "$MODE"
elif command -v wezterm >/dev/null 2>&1; then
  exec wezterm start -- "$RUNNER" "$MODE"
fi

printf 'Nenhum terminal suportado encontrado.\n' >&2
exit 1
