# Instalação limpa da sessão Hyprland + Lume

Base: Arch/CachyOS. Este guia cobre integração opcional com Hyprland; Lume pode
ser instalado e usado sem yadm, dotfiles ou este perfil. O guia do labwc está
em `docs/labwc-install.md`.

Para Fedora Silverblue/Ublue e o projeto Hyprland Atomic, consulte o
[guia de portabilidade de temas](theme-portability.md). Ele documenta as
lacunas de integração e o plano de melhoria; os comandos Arch abaixo não
são instruções de instalação para Fedora.

## 1. Instalar Lume

Construa ou instale o pacote Arch seguindo
[`../packaging/arch/README.md`](../packaging/arch/README.md). O pacote inclui o
serviço `lume-shell.service` e instala os arquivos em `/usr/share/lume-shell`;
não é necessário clonar o código em `~/.config/quickshell` para uso normal.

## 2. Pacotes

```bash
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprpolkitagent hyprsunset \
  xdg-desktop-portal-hyprland hyprshutdown \
  uwsm qt6ct nwg-displays \
  kitty awww zenity easyeffects \
  power-profiles-daemon networkmanager \
  wl-clipboard grim slurp swappy brightnessctl upower \
  noto-fonts ttf-noto-nerd bibata-cursor-theme \
  python-requests python-pillow \
  bluez bluez-utils \
  htop polkit fcitx5 fcitx5-qt
```

Para uma sessão labwc, instale também o perfil próprio descrito em
`docs/labwc-install.md §2` (kanshi, swayidle, wlopm e wtype).
No Hyprland, `nwg-displays` gera `hypr/monitors.conf`.
Ferramentas opcionais por recurso: `waypaper` (se preferir o seletor externo
em vez da galeria do Theme Studio), `blueberry`, `nm-connection-editor`,
`imagemagick` (prévia de formatos especiais), `fd` (busca de arquivos),
`yt-dlp` (downloads no Spotlight), `gtk3`/`xdg-utils` (abertura de aplicativos
e arquivos), `system-config-printer` (abrir a fila), KDE Connect, CUPS, Flatpak,
Homebrew e Gear Lever. `grimblast-git` (AUR) habilita atalhos de captura do
perfil Hyprland; o restante do shell continua utilizável sem esse helper.
Use `power-profiles-daemon` como único gerenciador de perfil; não instale TLP
junto dele. O limite de carga ThinkPad é uma integração separada e opcional,
instalada com `sudo scripts/install-battery-charge-limit-system.sh`. Não instale
`swaync` (notificações são nativas do shell).

Para reproduzir também a correção de retomada da digital deste host, use a
receita no projeto separado `~/Projetos/hyprlock-fingerprint`.
Ela substitui explicitamente o pacote upstream `hyprlock` pelo pacote Arch
`hyprlock-fingerprint`; faça o build e a instalação somente se precisar desse
patch. Outras distros continuam usando Hyprlock upstream até existir uma
receita equivalente e validada para elas.

O hook de retomada de fprintd é específico do Synaptics `06cb:00bd` e não é
instalado pelo pacote. Seus modelos estão na pasta `host-integration` da
receita; só aplique após confirmar que a máquina usa esse leitor e revisar as
instruções locais. Regras udev, USB/TLP e autenticação PAM seguem a configuração
de cada host.

## 3. Correções em `/etc` (não versionadas — reaplicar à mão)

Regra udev e hook `fprintd-reset` para o Synaptics `06cb:00bd`, conforme
`docs/labwc-install.md §3`. PPD controla perfis de plataforma, mas não replica
as políticas adicionais de autosuspend USB e runtime PM do TLP.

Para reproduzir a alternância de perfil AC/bateria e o limite ThinkPad, instale
o helper e serviço do projeto com
`sudo /usr/share/lume-shell/scripts/install-battery-charge-limit-system.sh`.

## 4. Serviços do usuário

```bash
systemctl --user daemon-reload
systemctl --user enable lume-shell.service hypridle.service
```

## 5. Primeiro login

1. No greeter, escolha **Hyprland (uwsm-managed)**.
2. Valide o shell:
   ```bash
   systemctl --user status lume-shell.service
   ```
3. Manual, uma vez: escolha e aplique um papel de parede pela galeria do
   Theme Studio no Spotlight, configure monitores no nwg-displays, informe a
   senha do Wi-Fi no popup da barra e cadastre digitais com
   `fprintd-enroll $USER`.

## 6. Atalhos (versão curta; completa em `docs/system-setup.md`)

`Win+Return` terminal, `Win+D/C/A/E/K/Tab` spotlight,
`Win+L` lock, `Win+Shift+C` QR da tela, `Print` screenshots.
