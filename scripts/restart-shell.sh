#!/usr/bin/env bash
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_UNIT="lume-shell.service"
if [[ ! -e /usr/lib/systemd/user/lume-shell.service && ! -e "$CONFIG_HOME/systemd/user/lume-shell.service" ]]; then
    SHELL_UNIT="quickshell.service"
fi

exec systemctl --user restart "$SHELL_UNIT"
