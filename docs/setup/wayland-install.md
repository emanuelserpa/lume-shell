# Generic Wayland integration

Lume runs on compositors that support Quickshell's Wayland surfaces. Workspace
and window controls appear when the compositor advertises the protocols that
Quickshell exposes. Sway 1.12+, niri 25.08+, MangoWC and current labwc provide
the shared workspace protocol; their exact versions and actions can differ.

## Install

Install the Lume package and Quickshell 0.3.x, then install the desktop services
used by the features you want. `wayland-utils` provides optional `wayland-info`
diagnostics. `wtype` is only needed for the labwc compatibility shortcut used
with older sessions; current labwc workspace buttons use the protocol.

Enable the user service in your Wayland session:

```sh
systemctl --user daemon-reload
systemctl --user enable lume-shell.service
```

## Provider mode

The default `auto` mode uses Hyprland's native metadata in a Hyprland session
and shared Wayland protocols elsewhere. Mango keeps a small `mmsg` stream for
the focused output, which the workspace protocol does not report.

Set `LUME_COMPOSITOR_MODE` in the environment inherited by the Quickshell
process:

- `auto`: select the normal provider for the active session.
- `wayland`: select protocol providers for workspaces and windows; output
  focused state falls back to the first screen.
- `hyprland`: enable Hyprland integration when the active session is Hyprland.
  The shell reports a configuration error if another session is active.

For a one-off development session:

```sh
LUME_COMPOSITOR_MODE=wayland quickshell --path ~/.config/quickshell
```

For the installed systemd service, run `systemctl --user edit
lume-shell.service` and add this drop-in, then restart that service:

```ini
[Service]
Environment=LUME_COMPOSITOR_MODE=wayland
```

This mode selects workspace and window providers; it does not change
compositor-specific logout, lock, theme, or screenshot commands.

## Diagnose

Run `scripts/doctor.sh --skip-validate` from the session. When `wayland-info` is
installed, the report lists compositor-advertised protocols. Quickshell's
`WindowManager` does not currently expose whether an empty workspace list means
“protocol absent” or “no workspace object received”; the report therefore
labels empty runtime lists as unreported instead of declaring the protocol
unsupported.

The original dwl build may expose window listing without the control protocol
used by Quickshell's task list, and may lack common workspaces. Patched builds
can differ. Lume hides controls whose protocol state is empty; no fake
workspaces are created.
