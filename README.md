# Lume

Lume é uma shell desktop Linux construída sobre o runtime
[Quickshell](https://quickshell.org/) e compositores Wayland. Inclui barra,
popups, notificações nativas, OSD e launcher Spotlight com histórico de
clipboard Wayland.

Evolved from a Waybar migration into a self-contained shell. Currently in
daily use on Arch Linux (Hyprland, UWSM session).

## Features

- **Top bar** — explicit compact layout (Catppuccin Mocha, Noto Sans / Nerd
  Fonts): workspaces, weather + clock center cluster with dashboard popup
  (forecast, calendar, hardware controls), tray, media, audio, network,
  Bluetooth, battery, conditional updates pill, screen recording, and
  notification center.
- **Spotlight launcher** (`SUPER+D`) — apps with usage ranking, files (`@`),
  windows (`~`), clipboard history (`#`), session/system actions (`:`),
  emoji (`;`), kill-by-PID (`!`), shell commands (`>`), calculator (`=`).
- **Native clipboard manager** — `wl-clipboard` + persistent Python daemon +
  SQLite (WAL) + blob storage with thumbnails. No CopyQ dependency
  (one-shot importer in `scripts/clipboard-import-copyq.py`).
- **Dynamic themes** — 17 palettes (Catppuccin, Dracula family, Kanagawa,
  Everforest, Solarized, …) plus wallpaper-adaptive `Chameleon` variants,
  synced live to Kitty, Hyprland borders/groupbar, and hyprlock.
- **Native notifications** (Quickshell NotificationServer), volume/mic/
  brightness OSD, night light, power profiles, multi-city Open-Meteo weather.

## Requirements

Quickshell 0.3.x, a Wayland compositor (Hyprland, labwc, MangoWC), PipeWire, `wl-clipboard`, Python 3
(`requests`, `Pillow`), Noto Sans / Nerd Fonts, Kitty.
Máquina nova? `docs/hyprland-install.md` ou `docs/labwc-install.md`
(lista de pacotes, fixes de `/etc`, primeiro login).

Per-feature helpers: `nmcli`, `bluetoothctl`, `checkupdates`
(`pacman-contrib`), `curl`, `fd`, `brightnessctl`, `upower`,
`power-profiles-daemon`, `grim`, `slurp`, `grimblast` (Hyprland), `swappy`, `blueberry`,
`nm-connection-editor`, `pwvucontrol`, `htop`.

## Install

Lume é instalado e executado sem yadm ou outro repositório de dotfiles. No
Arch Linux, construa ou instale o pacote conforme
[`packaging/arch/README.md`](packaging/arch/README.md); ele instala a shell e
`lume-shell.service`. Veja também o
[plano de instalação reproduzível](docs/reproducibility-plan.md). A receita
atual é privada e ainda não foi validada em uma instalação Arch limpa; outras
distribuições estão fora do escopo atual.

Para desenvolvimento pelo checkout, clone este repositório e rode uma instância
com `quickshell --path ~/.config/quickshell`. Não execute essa instância junto
com `lume-shell.service`.

```bash
git clone git@github.com:emanuelserpa/lume-shell-clean.git ~/.config/quickshell
```

Compositor e atalhos são integrações opcionais configuradas pelo usuário. O
launcher pode ser controlado por CLI, por exemplo:

```bash
lume-shell spotlight toggle
lume-shell spotlight clipboard
lume-shell spotlight actions
lume-shell spotlight emoji
```

Consulte `docs/hyprland-install.md` e `docs/labwc-install.md` para notas de
integração específicas de cada compositor; elas não são requisito para instalar
ou executar Lume.

Validate before deploying:

```bash
./scripts/validate.sh
python3 -B -m unittest discover -s tests -p "test_*.py"
```

## Layout

```text
shell.qml
├── bar/            # Bar modules + popups (explicit layout in Bar.qml)
├── launcher/       # Spotlight + per-mode modules
├── notifications/  # Native toasts
├── osd/            # Volume / mic / brightness overlay
├── services/       # Shared singletons (Theme, Media, Notifications, …)
├── components/     # Shared visuals (Pill, PopupCard, …)
├── scripts/        # Python/shell backends (JSON contracts)
└── docs/           # Architecture, domains, contracts
```

Start with `AGENTS.md`, then `docs/current-state.md`,
`docs/architecture.md`, and `docs/stability-contract.md`.

## History

See `CHANGELOG.md` and `docs/version-history.md` for the staged evolution
(Waybar migration → Control Center → native clipboard → current shell).
