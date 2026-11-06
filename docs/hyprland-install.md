# Hyprland integration

Lume runs as a Wayland shell and can be installed independently of a personal
dotfiles setup. This guide covers the optional Hyprland session integration on
Arch Linux.

## Install

Build or install the Arch package described in
[`../packaging/arch/README.md`](../packaging/arch/README.md). The package
installs the shell under `/usr/share/lume-shell` and provides
`lume-shell.service`.

Install the compositor and core session tools:

```sh
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprpolkitagent hyprsunset \
  xdg-desktop-portal-hyprland uwsm qt6ct kitty awww zenity \
  power-profiles-daemon networkmanager bluez bluez-utils \
  wl-clipboard grim slurp swappy brightnessctl upower \
  noto-fonts ttf-noto-nerd-fonts python-requests python-pillow
```

Optional features may use `fd`, `yt-dlp`, `grimblast`, `imagemagick`, CUPS,
Flatpak, KDE Connect, or additional media players. Install only the tools for
the features you use.

Enable the user services for the session:

```sh
systemctl --user daemon-reload
systemctl --user enable lume-shell.service hypridle.service
```

At first login, choose the Hyprland UWSM session, select a wallpaper in Theme
Studio, configure displays, and connect to Wi-Fi from the shell's network
popup. Compositor shortcuts and monitor rules remain user configuration.
