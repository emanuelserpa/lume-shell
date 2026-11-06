#!/usr/bin/env bash
set -u
CHAR="${1:-}"
[ -n "$CHAR" ] || exit 0

if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$CHAR" | wl-copy
fi

sleep 0.15

if command -v wtype >/dev/null 2>&1; then
    wtype -M ctrl -k v -m ctrl
fi
