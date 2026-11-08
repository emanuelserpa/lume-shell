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

Quickshell 0.3.x, a Wayland compositor (Hyprland, Sway, niri, MangoWC, labwc,
or another compositor with the required protocols), PipeWire,
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

Compositor integration is capability based. See the setup guides for
[generic Wayland](docs/wayland-install.md), [Hyprland](docs/hyprland-install.md),
and [labwc](docs/labwc-install.md). Sway, niri and Mango use shared Wayland
protocols for workspaces and window actions when their installed versions
advertise them.

## Development

Start with the [documentation index](docs/README.md). For code changes, read
[contribution rules](AGENTS.md) and the guide for the affected feature.

The [project dashboard](dashboard/) summarizes the current priority and recent
commits.

```sh
./scripts/validate.sh
```

See [build and validation](docs/deploy-and-validation.md) for checks and
[visual review](docs/visual-regression-checklist.md) for desktop scenarios.
