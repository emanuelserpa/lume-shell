#!/usr/bin/env bash
# Copia texto para o clipboard SEM colar (ação secundária Etapa 1 Raycast).
# Conteúdo via argv apenas para textos curtos não sensíveis (emoji etc.);
# segredos (clipboard) passam pelo daemon, nunca por aqui.
set -u
CHAR="${1:-}"
[ -n "$CHAR" ] || exit 0
if command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$CHAR" | wl-copy
fi
