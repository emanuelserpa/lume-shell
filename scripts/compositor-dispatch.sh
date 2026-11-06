#!/usr/bin/env bash
# =============================================================================
# compositor-dispatch.sh — Agnostic Compositor Dispatcher
# =============================================================================
# Encapsulates compositor-specific IPC and syntax (Lua vs classic conf) so that
# visible QML surfaces remain decoupled from compositor internal syntax.
# =============================================================================
set -euo pipefail

ACTION="${1:-}"
CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}"
CURRENT_DESKTOP="${CURRENT_DESKTOP,,}"

if [ -z "$ACTION" ]; then
    echo "Usage: compositor-dispatch.sh <workspace|window|close-window|submap|display-projection> [args...]" >&2
    exit 1
fi

# Mango uses numeric tags rather than the ext-workspace protocol. Keep its
# native IPC and argument grammar at this backend boundary; UI passes a stable
# tag number and optional output name only.
if [[ ":${CURRENT_DESKTOP}:" == *:mango:* ]]; then
    case "$ACTION" in
        workspace)
            TARGET="${2:-1}"
            OUTPUT="${3:-}"
            if [[ ! "$TARGET" =~ ^[1-9]$ ]]; then
                echo "mango: only numeric tags 1-9 are supported (got '$TARGET')" >&2
                exit 1
            fi
            if ! command -v mmsg >/dev/null 2>&1; then
                echo "mango: mmsg not found" >&2
                exit 1
            fi
            if [ -n "$OUTPUT" ]; then
                if [[ ! "$OUTPUT" =~ ^[[:alnum:]_.:-]+$ ]]; then
                    echo "mango: invalid output name" >&2
                    exit 1
                fi
                exec mmsg dispatch "viewcrossmon,$TARGET,$OUTPUT"
            fi
            exec mmsg dispatch "view,$TARGET"
            ;;
        *)
            echo "Unknown action: $ACTION" >&2
            exit 1
            ;;
    esac
fi

# labwc has no IPC: numeric desktop switching is injected as Logo+N through
# wtype, which requires matching W-1..N keybinds (GoToDesktop) in rc.xml.
# Checked before hyprctl because the binary may exist while idle in a labwc
# session. Only numeric targets are supported (no e±1 scrolling, no direct
# window focus).
if [ -n "${LABWC_PID:-}" ] || [[ "${XDG_CURRENT_DESKTOP:-}" == *labwc* ]]; then
    case "$ACTION" in
        workspace)
            TARGET="${2:-1}"
            if [[ ! "$TARGET" =~ ^([1-9]|10)$ ]]; then
                echo "labwc: only numeric desktops supported (got '$TARGET')" >&2
                exit 1
            fi
            if ! command -v wtype >/dev/null 2>&1; then
                echo "labwc: wtype not found" >&2
                exit 1
            fi
            if [ "$TARGET" = 10 ]; then TARGET=0; fi
            exec wtype -M logo -k "$TARGET"
            ;;
        window)
            echo "labwc: direct window focus unsupported" >&2
            exit 1
            ;;
        *)
            echo "Unknown action: $ACTION" >&2
            exit 1
            ;;
    esac
fi

# Hyprland dispatch handling
if command -v hyprctl >/dev/null 2>&1; then
    case "$ACTION" in
        submap)
            exec hyprctl submap
            ;;
        display-projection)
            MODE="${2:-}"
            case "$MODE" in
                computer|duplicate|extend|external) ;;
                *) echo "hyprland: invalid display projection mode" >&2; exit 1 ;;
            esac
            SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
            exec python3 -B "$SCRIPT_DIR/display-projection.py" apply "$MODE"
            ;;
        workspace)
            TARGET="${2:-1}"
            # 1. Try Lua dispatcher (Hyprland 0.55+ with Lua configuration)
            if hyprctl dispatch "hl.dsp.focus({ workspace = \"$TARGET\" })" >/dev/null 2>&1; then
                exit 0
            fi
            # 2. Fallback to classic hyprlang dispatcher syntax
            exec hyprctl dispatch workspace "$TARGET"
            ;;

        window)
            ADDR="${2:-}"
            WS="${3:-}"
            [ -z "$ADDR" ] && exit 1

            if [ -n "$WS" ] && [[ ! "$WS" =~ ^special: ]]; then
                LUA="(function() hl.dispatch(hl.dsp.focus({ workspace = \"$WS\" })); return hl.dsp.focus({ window = \"address:$ADDR\" }) end)()"
                if hyprctl dispatch "$LUA" >/dev/null 2>&1; then
                    exit 0
                fi
                hyprctl dispatch workspace "$WS" >/dev/null 2>&1 || true
            else
                LUA="hl.dsp.focus({ window = \"address:$ADDR\" })"
                if hyprctl dispatch "$LUA" >/dev/null 2>&1; then
                    exit 0
                fi
            fi

            # Fallback to classic hyprlang dispatcher syntax
            exec hyprctl dispatch focuswindow "address:$ADDR"
            ;;

        close-window)
            ADDR="${2:-}"
            [ -z "$ADDR" ] && exit 1
            exec hyprctl dispatch killwindow "address:$ADDR"
            ;;

        *)
            echo "Unknown action: $ACTION" >&2
            exit 1
            ;;
    esac
fi

# Fallback for future compositor support (e.g. swaymsg, niri msg)
echo "No supported compositor detected or command failed." >&2
exit 1
