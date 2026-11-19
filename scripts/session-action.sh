#!/usr/bin/env bash
# =============================================================================
# session-action.sh — Desktop Session Action Dispatcher
# =============================================================================
# Encapsulates session commands (lock, suspend, logout, reboot, poweroff)
# so that UI QML components remain decoupled from specific compositor tools.
# Uses compositor-specific commands only in that compositor's session.
# =============================================================================
set -euo pipefail

ACTION="${1:-}"
CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}"
CURRENT_DESKTOP="${CURRENT_DESKTOP,,}"

if [ -z "$ACTION" ]; then
    echo "Usage: session-action.sh <lock|suspend|logout|reboot|poweroff>" >&2
    exit 1
fi

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

is_hyprland() {
    [ -z "${LABWC_PID:-}" ] && [[ ":${CURRENT_DESKTOP}:" == *:hyprland:* ]]
}

is_mango() {
    [[ ":${CURRENT_DESKTOP}:" == *:mango:* ]]
}

case "$ACTION" in
    lock)
        if [ -n "${LABWC_PID:-}" ] || [[ ":${CURRENT_DESKTOP}:" == *:labwc:* ]]; then
            exec hyprlock
        elif is_mango; then
            exec hyprlock
        fi
        exec loginctl lock-session
        ;;

    suspend)
        exec systemctl suspend
        ;;

    logout)
        if [ -n "${LABWC_PID:-}" ] || [[ ":${CURRENT_DESKTOP}:" == *:labwc:* ]]; then
            exec labwc --exit
        elif is_mango && has_cmd mmsg; then
            exec mmsg dispatch quit
        elif is_hyprland && has_cmd hyprctl; then
            exec hyprctl dispatch exit
        else
            echo "Compositor sem ação de saída configurada." >&2
            exit 1
        fi
        ;;

    reboot)
        exec systemctl reboot
        ;;

    poweroff|shutdown)
        exec systemctl poweroff
        ;;

    *)
        echo "Unknown session action: $ACTION" >&2
        echo "Valid actions: lock, suspend, logout, reboot, poweroff" >&2
        exit 1
        ;;
esac
