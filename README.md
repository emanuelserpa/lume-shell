# Lume Shell

Lume is a Wayland desktop shell built with Quickshell.

![Lume's Spotlight launcher on an empty workspace, with the current status bar](assets/screenshots/lume-shell-spotlight.png)

## Features

- **Status bar** with workspaces, weather, clock, media, network, Bluetooth,
  battery, printing, updates, recording, and notifications.
- **Spotlight** for apps, files, windows, clipboard, system actions, emoji,
  shell commands, and calculations.
- **Clipboard history** backed by `wl-clipboard`, SQLite, and local image storage.
- **Theme Studio** with built-in palettes and wallpaper-based Chameleon themes.
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

Start with the [documentation index](docs/README.md) for setup, architecture,
and feature guides.

```sh
./scripts/validate.sh
```

See [build and validation](docs/deploy-and-validation.md) for details about
the checks.

## License

Lume is licensed under the [MIT License](LICENSE). Third-party assets and
dependencies retain their own licenses.
