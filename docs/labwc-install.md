# labwc integration

Lume runs as a Wayland shell and can be installed independently of a personal
dotfiles setup. This guide covers optional labwc integration on Arch Linux.

## Install

Build or install the Arch package described in
[`../packaging/arch/README.md`](../packaging/arch/README.md). The package
installs the shell under `/usr/share/lume-shell` and provides
`lume-shell.service`.

Install labwc and the core session tools:

```sh
sudo pacman -S --needed \
  labwc uwsm kanshi swayidle wlopm wtype \
  fcitx5 fcitx5-qt hyprlock awww zenity kitty \
  power-profiles-daemon networkmanager bluez bluez-utils \
  wl-clipboard grim slurp swappy brightnessctl upower \
  noto-fonts ttf-noto-nerd-fonts python-requests python-pillow
```

Optional features may use `fd`, `yt-dlp`, `imagemagick`, CUPS, Flatpak,
KDE Connect, or additional media players. Install only the tools for the
features you use.

Enable the shell service for the session:

```sh
systemctl --user daemon-reload
systemctl --user enable lume-shell.service
```

Choose the labwc UWSM session at login. Configure session shortcuts and display
layout in your compositor settings. Wi-Fi credentials are entered through the
shell's network popup.
