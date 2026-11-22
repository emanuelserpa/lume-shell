#!/bin/bash
# Show ping latency when ICMP is available, but use NetworkManager's
# connectivity state so networks that block ICMP aren't reported offline.
latency=$(LC_ALL=C ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'time=' '/time=/ { print $2 }' | cut -d' ' -f1)
if [[ -z "$latency" ]]; then
    # Fallback to Portuguese pattern if not localized
    latency=$(ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'tempo=' '/tempo=/ { print $2 }' | cut -d' ' -f1)
fi

if [[ -n "$latency" ]]; then
    val=$(echo "$latency" | cut -d. -f1 | tr -d '[:space:]')
    echo "{\"ping\": ${val:-0}, \"status\": \"online\"}"
else
    connectivity=$(nmcli -g CONNECTIVITY general status 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$connectivity" in
        full) status="online" ;;
        limited) status="limited" ;;
        portal) status="portal" ;;
        none) status="offline" ;;
        *) status="unknown" ;;
    esac
    printf '{"ping": -1, "status": "%s"}\n' "$status"
fi
