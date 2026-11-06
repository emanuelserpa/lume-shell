# Instalação limpa da sessão labwc + Lume

Base: Arch/CachyOS. Este guia cobre integração opcional com labwc; Lume pode
ser instalado e usado sem yadm, dotfiles ou este perfil. Testado em CachyOS
(repositórios `*-v3`); no Arch puro, o runtime Quickshell pode precisar do AUR.

## 1. Instalar Lume

Construa ou instale o pacote Arch seguindo
[`../packaging/arch/README.md`](../packaging/arch/README.md). O pacote inclui o
serviço `lume-shell.service` e instala os arquivos em `/usr/share/lume-shell`;
não é necessário clonar o código em `~/.config/quickshell` para uso normal.

## 2. Pacotes

```bash
sudo pacman -S --needed \
  labwc uwsm \
  kanshi swayidle wlopm \
  fcitx5 fcitx5-qt hyprlock wtype \
  awww zenity easyeffects kitty \
  power-profiles-daemon networkmanager bluez bluez-utils \
  wl-clipboard grim slurp swappy brightnessctl upower \
  noto-fonts ttf-noto-nerd bibata-cursor-theme \
  python-requests python-pillow \
  htop polkit hyprpolkitagent
```

Per-feature (só se usar): `blueberry`, `nm-connection-editor`, `kdeconnect`,
`waypaper` (se preferir o seletor externo à galeria do Theme Studio),
`imagemagick` (prévia de formatos especiais), `fd` (busca de arquivos),
`yt-dlp` (downloads no Spotlight), `gtk3`/`xdg-utils` (abertura de aplicativos
e arquivos), `system-config-printer` (abrir a fila), `cups`, Flatpak e Steam.
Use `power-profiles-daemon` como único gerenciador de perfil; não instale TLP
junto dele. O limite de carga ThinkPad é uma integração separada e opcional,
instalada com `sudo scripts/install-battery-charge-limit-system.sh`.
Não instale `network-manager-applet` (`nm-applet` é desativado de propósito; os
segredos de Wi-Fi são solicitados pelo diálogo do shell).

## 3. Correções em `/etc` (não versionadas — reaplicar à mão)

Leitor Synaptics `06cb:00bd` pode exigir a regra udev abaixo para evitar
suspensão USB seletiva. PPD não replica as políticas gerais de autosuspend USB
e runtime PM do TLP:

```bash
# /etc/udev/rules.d/99-fingerprint.rules
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="06cb", ATTRS{idProduct}=="00bd", ATTR{power/control}="on"
sudo udevadm control --reload && sudo udevadm trigger
```

Não instale TLP junto de PPD. Esta regra mantém o leitor Synaptics acordado;
os outros dispositivos seguem a política do kernel/driver.

Para alternar automaticamente o perfil AC/bateria e restaurar o limite de
carga ThinkPad ao desconectar, instale o helper e serviço com
`sudo /usr/share/lume-shell/scripts/install-battery-charge-limit-system.sh`.

```bash
# /usr/lib/systemd/system-sleep/fprintd-reset  (chmod +x)
#!/bin/sh
[ "$1" = "post" ] && systemctl restart fprintd
```

## 4. Serviços do usuário

```bash
systemctl --user daemon-reload
systemctl --user enable lume-shell.service
```

`hypridle` só sobe no Hyprland (drop-in já versionado);
`lume-shell.service` sobe pelas sessões via `graphical-session.target`.

## 5. Primeiro login

1. No greeter, escolha **labwc (uwsm-managed)** (nunca o `labwc` puro).
2. Valide o shell:
   ```bash
   cd ~/.config/quickshell && ./scripts/validate.sh
   ```
3. Manual, uma vez: escolha e aplique um papel de parede pela galeria do
   Theme Studio no Spotlight, informe a senha do Wi-Fi no popup da barra e
   cadastre digitais com `fprintd-enroll $USER`.

## 6. Atalhos opcionais para configurar em `rc.xml`

`Win+Return` terminal, `Win+D/C/A/E/K/Tab` spotlight,
`Win+1..0` desktops, `Win+L` lock (hyprlock), `Win+Tab` janelas. Esses atalhos
pertencem à configuração do compositor e são opcionais; Lume também oferece
comandos CLI para controlar o Spotlight. Detalhes em `docs/system-setup.md`.
