# Lume Shell

Lume is a Wayland desktop shell built with Quickshell. It provides a compact
status bar, Spotlight launcher, quick settings, native notifications, OSD,
clipboard history, weather, power controls, and dynamic themes.

## Features

- **Status bar** with workspaces, weather, clock, media, network, Bluetooth,
  battery, printing, updates, recording, and notifications.
- **Spotlight** for apps, files, windows, clipboard, system actions, emoji,
  shell commands, and calculations.
- **Clipboard history** backed by `wl-clipboard`, SQLite, and local image storage.
- **Theme Studio** with static palettes and wallpaper-adaptive Chameleon themes.
- **Native notifications**, audio and brightness OSD, night light, power
  profiles, and multi-city Open-Meteo weather.

## Requirements

Quickshell 0.3.x, a Wayland compositor (Hyprland, labwc, or MangoWC), PipeWire,
Python 3 with `requests` and `Pillow`, Noto Sans, Nerd Fonts, and Kitty.
Optional integrations use the corresponding system tools, such as `nmcli`,
`bluetoothctl`, `checkupdates`, `brightnessctl`, `upower`, `grim`, and `slurp`.

## Install

On Arch Linux, build or install the package described in
[`packaging/arch/README.md`](packaging/arch/README.md). For a development
checkout, clone this repository and run a separate instance with
`quickshell --path ~/.config/quickshell`; do not run it alongside
`lume-shell.service`.

```sh
git clone https://github.com/emanuelserpa/lume-shell.git ~/.config/quickshell
```

Compositor integration is optional. See the current setup guides for
[Hyprland](docs/hyprland-install.md) and [labwc](docs/labwc-install.md).

## Development

Read `AGENTS.md`, `docs/current-state.md`, `docs/architecture.md`, and the
relevant feature guide before changing behavior.

```sh
./scripts/validate.sh
```

See `docs/visual-regression-checklist.md` for manual visual checks.
