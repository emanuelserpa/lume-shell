#!/usr/bin/env bash
set -euo pipefail

led=/sys/class/leds/platform::micmute/brightness

sync_led() {
    local mute value current

    [[ -w "$led" ]] || return 0
    mute="$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null)" || return 0
    case "$mute" in
        *"Mute: yes"*) value=1 ;;
        *"Mute: no"*) value=0 ;;
        *) return 0 ;;
    esac

    current="$(<"$led")" || return 0
    [[ "$current" == "$value" ]] || printf '%s\n' "$value" > "$led"
}

sync_led

# pactl emits only state-change events; ignore unrelated playback/device noise.
pactl subscribe 2>/dev/null | while IFS= read -r event; do
    case "$event" in
        *" on source #"*|*" on server #"*) sync_led ;;
    esac
done
