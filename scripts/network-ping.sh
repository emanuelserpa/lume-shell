#!/bin/bash
# Real-time ping latency check for Quickshell network popup
latency=$(LC_ALL=C ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'time=' '/time=/ { print $2 }' | cut -d' ' -f1)
if [[ -z "$latency" ]]; then
    # Fallback to Portuguese pattern if not localized
    latency=$(ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'tempo=' '/tempo=/ { print $2 }' | cut -d' ' -f1)
fi

if [[ -n "$latency" ]]; then
    val=$(echo "$latency" | cut -d. -f1 | tr -d '[:space:]')
    echo "{\"ping\": ${val:-0}, \"status\": \"online\"}"
else
    echo "{\"ping\": -1, \"status\": \"offline\"}"
fi
