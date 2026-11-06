#!/usr/bin/env bash
# scan-qr.sh — Lê QR Code da tela para o clipboard.
#
# Fluxo: slurp (seleciona região, Esc cancela) -> grim -> zbarimg --raw
# -> wl-copy. O conteúdo nunca aparece na notificação (pode ser senha/URL).
set -uo pipefail

REGION="$(slurp 2>/dev/null)" || exit 0
[ -z "${REGION:-}" ] && exit 0

TMP="$(mktemp --suffix=.png)"
trap 'rm -f "$TMP"' EXIT

grim -g "$REGION" "$TMP" 2>/dev/null || exit 0

DATA="$(zbarimg --raw --quiet "$TMP" 2>/dev/null | head -n 1)"
if [ -z "${DATA:-}" ]; then
    notify-send -a quickshell "QR Code" "Nenhum código encontrado na região."
    exit 1
fi

printf '%s' "$DATA" | wl-copy
notify-send -a quickshell "QR Code" "Copiado para o clipboard."
