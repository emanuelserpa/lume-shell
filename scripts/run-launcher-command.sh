#!/usr/bin/env bash
set -u

CMD="${1:-}"

if [[ -z "$CMD" ]]; then
    exit 0
fi

SHELL_BIN="${SHELL:-/bin/bash}"

run_shell=(sh -lc "$CMD; status=\$?; printf '\n[exit %s]\n' \"\$status\"; exec \"$SHELL_BIN\"")

if command -v kitty >/dev/null 2>&1; then
    exec kitty "${run_shell[@]}"
elif command -v ghostty >/dev/null 2>&1; then
    exec ghostty -e "${run_shell[@]}"
elif command -v foot >/dev/null 2>&1; then
    exec foot "${run_shell[@]}"
elif command -v alacritty >/dev/null 2>&1; then
    exec alacritty -e "${run_shell[@]}"
elif command -v wezterm >/dev/null 2>&1; then
    exec wezterm start -- "${run_shell[@]}"
fi

printf 'Nenhum terminal suportado encontrado.\n' >&2
exit 1
