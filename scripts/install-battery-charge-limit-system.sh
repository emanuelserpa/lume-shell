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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -D -o root -g root -m 0755 \
    "$repo_root/system/battery-charge-limit-privileged" \
    /usr/local/libexec/quickshell-battery-charge-limit
install -D -o root -g root -m 0644 \
    "$repo_root/system/polkit/50-quickshell-battery-charge-limit.rules.in" \
    /etc/polkit-1/rules.d/50-quickshell-battery-charge-limit.rules
sed -i "s/@QUICKSHELL_USER@/$target_user/g" \
    /etc/polkit-1/rules.d/50-quickshell-battery-charge-limit.rules
install -D -o root -g root -m 0644 \
    "$repo_root/system/systemd/quickshell-power-source-policy.service" \
    /etc/systemd/system/quickshell-power-source-policy.service

runtime_dir="/run/user/$target_uid"
if [[ -S "$runtime_dir/bus" ]]; then
    session_env=(env "XDG_RUNTIME_DIR=$runtime_dir" "DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime_dir/bus")
    runuser -u "$target_user" -- "${session_env[@]}" \
        systemctl --user disable --now tlp-battery-monitor.service 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable --now quickshell-power-source-policy.service
echo "Installed the charge helper and power-source policy service for $target_user."
