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
    /usr/lib/lumeshell/lumeshell-battery-charge-limit
install -D -o root -g root -m 0644 \
    "$repo_root/system/polkit/50-lumeshell-battery-charge-limit.rules" \
    /etc/polkit-1/rules.d/50-lumeshell-battery-charge-limit.rules
install -D -o root -g root -m 0644 \
    "$repo_root/system/systemd/lumeshell-power-source-policy.service" \
    /etc/systemd/system/lumeshell-power-source-policy.service

systemctl daemon-reload
systemctl disable --now quickshell-power-source-policy.service 2>/dev/null || true
systemctl enable lumeshell-power-source-policy.service
systemctl restart lumeshell-power-source-policy.service || systemctl start lumeshell-power-source-policy.service
echo "Installed the charge helper and power-source policy service for $target_user."
