#!/usr/bin/env bash
set -u

TARGET_DIR=""
if [[ "${1:-}" == "--dir" ]]; then
    TARGET_DIR="${2:-}"
    shift 2
fi
if [[ "${1:-}" == "--" ]]; then
    shift
fi

if [[ -n "$TARGET_DIR" && -d "$TARGET_DIR" ]]; then
    cd "$TARGET_DIR" || exit 1
fi

run_candidate() {
    local term="$1"
    shift || true
    local base="${term##*/}"
    case "$base" in
        kitty)
            if [[ $# -gt 0 ]]; then
                exec "$term" "$@"
            fi
            exec "$term"
            ;;
        ghostty)
            if [[ $# -gt 0 ]]; then
                exec "$term" -e "$@"
            fi
            exec "$term"
            ;;
        foot)
            if [[ $# -gt 0 ]]; then
                exec "$term" "$@"
            fi
            exec "$term"
            ;;
        alacritty)
            if [[ $# -gt 0 ]]; then
                exec "$term" -e "$@"
            fi
            exec "$term"
            ;;
        wezterm)
            if [[ $# -gt 0 ]]; then
                exec "$term" start -- "$@"
            fi
            exec "$term" start
            ;;
        *)
            if [[ $# -gt 0 ]]; then
                exec "$term" -e "$@"
            fi
            exec "$term"
            ;;
    esac
}

if [[ -n "${TERMINAL:-}" ]] && command -v "$TERMINAL" >/dev/null 2>&1; then
    run_candidate "$TERMINAL" "$@"
fi

for candidate in kitty ghostty foot alacritty wezterm; do
    if command -v "$candidate" >/dev/null 2>&1; then
        run_candidate "$candidate" "$@"
    fi
done

printf 'Nenhum terminal suportado encontrado.\n' >&2
exit 1
