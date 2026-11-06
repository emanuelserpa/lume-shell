#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

target_uid="${SUDO_UID:-${PKEXEC_UID:-}}"
if [[ -z "$target_uid" || "$target_uid" == 0 ]]; then
    echo "Run this installer through sudo from the target user's session." >&2
    exit 1
fi

target_user="$(id -un "$target_uid")"
if [[ ! "$target_user" =~ ^[a-z_][a-z0-9_-]*\$?$ ]]; then
    echo "Unsupported account name: $target_user" >&2
    exit 1
fi

target_gid="$(id -g "$target_uid")"
target_home="$(getent passwd "$target_uid" | cut -d: -f6)"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install -D -o root -g root -m 0755 \
    "$repo_root/system/cpu-boost-privileged" \
    /usr/local/libexec/quickshell-cpu-boost
install -D -o root -g root -m 0644 \
    "$repo_root/system/polkit/50-quickshell-cpu-boost.rules.in" \
    /etc/polkit-1/rules.d/50-quickshell-cpu-boost.rules
sed -i "s/@QUICKSHELL_USER@/$target_user/g" \
    /etc/polkit-1/rules.d/50-quickshell-cpu-boost.rules

runuser -u "$target_user" -- mkdir -p "$target_home/.config/systemd/user"
install -D -o "$target_uid" -g "$target_gid" -m 0644 \
    "$repo_root/system/systemd/user/cpu-boost-restore.service" \
    "$target_home/.config/systemd/user/cpu-boost-restore.service"

if ! runuser -u "$target_user" -- python3 \
    "$repo_root/scripts/cpu-boost.py" initialize-default; then
    echo "Could not initialize the CPU boost preference to off." >&2
fi

echo "Installed the CPU boost helper, its scoped polkit rule, and the user service."
runtime_dir="/run/user/$target_uid"
if [[ -S "$runtime_dir/bus" ]]; then
    session_env=(env "XDG_RUNTIME_DIR=$runtime_dir" "DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime_dir/bus")
    runuser -u "$target_user" -- "${session_env[@]}" systemctl --user daemon-reload || true
    if runuser -u "$target_user" -- "${session_env[@]}" \
        systemctl --user enable --now cpu-boost-restore.service; then
        echo "Enabled and started cpu-boost-restore.service for $target_user."
    else
        echo "Install succeeded; enable the user service with: systemctl --user enable --now cpu-boost-restore.service" >&2
    fi
else
    echo "Install succeeded; enable the user service at login with: systemctl --user enable cpu-boost-restore.service"
fi
