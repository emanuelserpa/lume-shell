#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

target_uid="${SUDO_UID:-}"
if [[ -z "$target_uid" || "$target_uid" == 0 ]]; then
    echo "Run this script with sudo from the target user's session." >&2
    exit 1
fi

target_user="$(id -un "$target_uid")"
target_home="$(getent passwd "$target_uid" | cut -d: -f6)"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_dir="$target_home/.local/share/quickshell/migrations"
backup_file="$backup_dir/tlp-config-$(date +%Y%m%d-%H%M%S).tar.gz"

if pacman -Qq tlp >/dev/null 2>&1; then
    install -d -o "$target_uid" -g "$(id -g "$target_uid")" -m 0700 "$backup_dir"
    config_items=()
    [[ ! -e /etc/tlp.conf ]] || config_items+=(tlp.conf)
    [[ ! -d /etc/tlp.d ]] || config_items+=(tlp.d)
    if ((${#config_items[@]})); then
        tar -C /etc -czf "$backup_file" "${config_items[@]}"
        chown "$target_uid:$(id -g "$target_uid")" "$backup_file"
        chmod 0600 "$backup_file"
        echo "Saved TLP configuration to $backup_file"
    else
        echo "No /etc/tlp.conf or /etc/tlp.d configuration found to back up."
    fi
fi

# Install PPD before starting the replacement system policy service.
pacman -S --needed power-profiles-daemon

if pacman -Qq tlp >/dev/null 2>&1; then
    for unit in tlp.service tlp-sleep.service; do
        if systemctl cat "$unit" >/dev/null 2>&1; then
            systemctl disable --now "$unit"
        fi
    done
    # Remove TLP and its installed NetworkManager companion only; keep all
    # other dependencies and preserve the config archive.
    packages_to_remove=(tlp)
    pacman -Qq tlp-rdw >/dev/null 2>&1 && packages_to_remove+=(tlp-rdw)
    pacman -R "${packages_to_remove[@]}"
fi

SUDO_UID="$target_uid" bash "$repo_root/scripts/install-battery-charge-limit-system.sh"

echo "Migrated $target_user to power-profiles-daemon; the power-source service selects balanced on AC and power-saver on battery."
echo "TLP's extra runtime-PM/autosuspend policies are not reproduced by PPD."
powerprofilesctl get
