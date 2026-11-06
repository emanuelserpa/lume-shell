# Inventário de dependências e portabilidade

Data: 05/11/2026. Escopo: snapshot atual de `~/.config/quickshell`, incluindo
`shell.qml` e componentes montados; inventário estático de código e dos guias
de instalação Hyprland/labwc. O único alvo de reprodução atual é Arch Linux
x86_64 com Wayland e systemd. A máquina de desenvolvimento usa CachyOS; isso
não é prova de instalação limpa de Arch Linux nem confirma versões mínimas.

O primeiro manifesto executável está em [`../data/dependencies.json`](../data/dependencies.json)
(schema 1). `scripts/doctor.sh` lê dele os comandos-base, ferramentas por
recurso e grupos de alternativas. Ele registra executáveis e capacidades, não
versões mínimas. Cada comando agora tem uma referência ao pacote Arch, inclusive
origem oficial/AUR/externa; grupos de alternativas registram os pacotes
instaláveis recomendados. Isso ainda não enumera todas as dependências por
feature: comandos específicos do compositor e verificações de arquivos/serviços
continuam diretamente no doctor, enquanto módulos Qt/QML, imports Python e
integrações de sessão ainda precisam entrar no manifesto. Os nomes dos pacotes
foram comparados com os guias e com a base de pacotes Arch disponível no host;
isso não fixa versão nem substitui a validação numa instalação Arch limpa.

## Runtime e arquivos da shell

| Dependência | Classificação | Evidência e observações |
| --- | --- | --- |
| Quickshell + Qt 6 / QML | Obrigatória | `shell.qml`; módulos `QtQuick`, Controls, Dialogs, Effects, Layouts, Shapes, Window e `Qt5Compat.GraphicalEffects` (usado pela bateria); módulos Quickshell de Wayland, I/O, WindowManager, Widgets, MPRIS, Notifications, Pipewire, SystemTray e UPower. README diz Quickshell 0.3.x, sem revisão exata nem lista dos plugins Qt necessários. |
| Python 3 | Obrigatória | Helpers chamados por QML, em especial rede, tema, clipboard, notificações, clima, energia, impressão e atualizações. Versão mínima não declarada. |
| `python-requests` | Feature de clima | `scripts/weather-cities.py` e `scripts/waybar-wttr.py`; o clima fica indisponível sem o módulo `requests`. |
| `python-pillow` | Feature de imagem | `scripts/theme-manager.py`, `wallpaper-action.py` e `clipboard_store.py`; habilita extração Chameleon e processamento aprimorado de imagens, com fallback parcial. |
| Bash / POSIX shell | Obrigatória | Scripts `.sh` usam `bash` e `/bin/sh`; scripts também chamam utilitários GNU comuns. O alvo de reprodução agora é Arch Linux. |
| Arquivos e assets do projeto | Obrigatórios | QML agrupado em `bar/`, `components/`, `controlcenter/`, `launcher/`, `notifications/`, `osd/`, `services/`; `qmldir` define imports `qs.*`; SVG Tabler é local. A árvore inclui implementação Python vendorizada de Material You Color em `scripts/vendor/materialyoucolor`. |
| Fontconfig + fontes | Obrigatórios para fidelidade visual | `fc-match`/`fc-list`; Noto Sans e Nerd Font são as famílias esperadas nos guias. O fallback permite iniciar sem elas, mas muda métricas e ícones. Licenças e versões a fixar. |
| `systemd --user` | Obrigatório no alvo Arch Linux | O shell é iniciado por `quickshell.service` associado a `graphical-session.target`; scripts usam `systemctl --user`. |
| D-Bus de sessão e ambiente Wayland | Obrigatórios | Integrações nativas Quickshell dependem de serviços de sessão (notificações, tray, MPRIS, PipeWire, UPower e portais). `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP` e ambiente importado para systemd precisam estar corretos. |

Os imports QML ativos e os respectivos pacotes Arch estão registrados em
`data/dependencies.json`; `Qt5Compat.GraphicalEffects` depende de
`qt6-5compat`, enquanto os módulos `Quickshell.*` vêm do pacote `quickshell`.
Os imports `qs.*` são locais e resolvidos pelo `qmldir` do projeto. A lista foi
extraída dos QML montados, mas ainda precisa de instalação de verificação limpa.

## Ferramentas externas por capacidade

| Capacidade | Dependências externas observadas | Classificação / ausência |
| --- | --- | --- |
| Área de transferência | `wl-clipboard` (`wl-copy`, `wl-paste`), Python; SQLite é da biblioteca padrão | Base do histórico e ações de clipboard; indisponível sem compositor Wayland/clipboard utilities. Pillow melhora suporte a conteúdo de imagem. |
| Rede e VPN | NetworkManager + `nmcli`; `curl` no speedtest; `nm-connection-editor` opcional | UI de rede pressupõe NetworkManager; não é backend genérico de qualquer daemon de rede. |
| Bluetooth | BlueZ + `bluetoothctl`; `blueberry` opcional para configurações avançadas | Controles indisponíveis sem BlueZ/ferramenta; aparelho Bluetooth é requisito de hardware apenas para testar. |
| Áudio e microfone | PipeWire (API nativa Quickshell), compatibilidade `wpctl`/`pactl`; `pwvucontrol` opcional; `easyeffects` integração opcional | Áudio básico requer servidor PipeWire; EasyEffects não é requisito do popup. |
| Brilho e bateria | `brightnessctl`, UPower/API nativa, sysfs `/sys/class/power_supply`; PPD para perfis; helper Polkit opcional para limite de carga ThinkPad | Ajuste de brilho/bateria é dependente de hardware. O helper de limite escreve somente os thresholds expostos pelo kernel e não é um recurso universal de bateria. |
| Energia / CPU | `power-profiles-daemon`, `systemctl`, Polkit/`pkexec`; helpers opcionais de limite de carga e CPU boost | PPD controla perfil de plataforma, mas não substitui as otimizações adicionais do TLP (por exemplo runtime PM/autosuspend). TLP e PPD não devem competir. Helpers privilegiados são específicos do hardware e do usuário. |
| Temas e wallpaper | um entre `awww`/`swww` (Hyprland também pode consultar `hyprctl hyprpaper`); `zenity` ou `kdialog`; `magick` para previews especiais; Pillow para extração Chameleon | Seleção/preview/restauração requer backend disponível; `hyprctl` é adaptador de compositor, não dependência geral. Paletas estáticas não dependem do Pillow. Waypaper é opcional: o Theme Studio já seleciona e aplica wallpapers; seu `config.ini` é lido apenas como legado. |
| Captura, gravação e QR | `grim`, `slurp`, `wl-copy`; `wf-recorder`; `swappy`; `zbarimg`; `notify-send`; `grimblast` apenas Hyprland | Recursos independentes; gravação de tela/áudio também depende de portais, PipeWire e permissões da sessão conforme compositor. |
| Clima | `curl` e acesso à rede; `requests` nos helpers | Opcional para a shell; cidades/dados persistidos no diretório XDG state. |
| Atualizações | `pacman`, `checkupdates`, `vercmp` e AUR via scripts próprios; `flatpak`, `brew` e Gear Lever/AppImage como provedores opcionais | Provedor Arch é específico da distro. AUR pressupõe ecossistema Arch; Flatpak/Brew/AppImage independem do provedor Arch. Nenhum provedor deve ser requisito de inicialização. |
| Impressoras | CUPS (`lpstat`, `cancel`, `ippfind`); `system-config-printer` para abrir a fila | O código de estado usa executáveis CLI, sem binding Python CUPS. Serviço e dispositivos são opcionais; ausência deve ocultar/desativar a capacidade, não impedir a shell. |
| Mídia / integração de telefone | MPRIS via Quickshell; `kdeconnect-cli` e `gdbus` opcionais | Spotify/players exigem um serviço MPRIS ativo; telefone depende de KDE Connect e dispositivo pareado. |
| Launcher e sistema | `fd` para buscas de arquivos, `fastfetch` para painel de sistema, `kitty` para ações/terminal, `htop` para monitor; `gtk-launch` para abrir apps via desktop entries | `fd`, Kitty e Fastfetch estão usados diretamente e atualmente tratados pelo doctor como requisito/ferramenta de feature. Terminal deve virar preferência configurável. |
| Downloads | `yt-dlp` | Integração opcional do Spotlight; preferências e jobs usam diretórios XDG. Ausência deve desativar somente a ação de download. |
| Abrir arquivos e notificações | `xdg-open`, `gtk-launch`, `notify-send` | Dependem de handlers/MIME e sessão desktop. `gtk-launch` usa desktop entries; podem ser necessárias bibliotecas GTK mesmo que a shell seja Qt. |
| Tema GTK | `gsettings`, schemas GTK, temas GTK instalados | Adapter opcional; o arquivo CSS do projeto não garante que GTK/libadwaita ou apps Flatpak o carreguem. |
| Energia | `powerprofilesctl` para `power-profiles-daemon`, `systemctl`, Polkit/`pkexec` | Operação depende de serviço instalado/ativo e compatibilidade da plataforma. O perfil recomendado usa PPD sozinho; ele não reproduz todas as políticas de baixo nível do TLP. |
| Importação de clipboard | `copyq` nativo ou CopyQ via Flatpak | Ferramenta de migração única para importar histórico legado; não é dependência do clipboard ativo da shell. |
| Projeção de monitores | `hyprctl` e API/configuração Hyprland | Recurso atualmente restrito ao Hyprland; exposição no menu é condicional. Não existe backend genérico para labwc/Mango. |
| Encerrar/bloquear sessão | `loginctl`, `systemctl`, comandos do compositor; `hyprshutdown` opcional no Hyprland | Bloquear depende de integração de sessão/logind; logout requer dispatcher específico. Suspensão e desligamento dependem de systemd/logind e autorização do host. |
| Jogos em execução | `/proc` e manifests Steam em `~/.local/share/Steam/steamapps` | Exibição é opcional e detecta processos Steam sem exigir Steam para iniciar. Biblioteca Steam pode estar em outro caminho e não é configurável hoje. |
| Sistema e sensores | `/proc`, `/sys` (thermal, hwmon, CPU, backlight, power supply); `brightnessctl` para ajuste | Leitura básica usa interfaces do kernel; sensores podem faltar ou ser negados por permissões/driver. Frequência, fan, backlight e bateria variam por máquina. |

## Serviços do sistema por recurso

O manifesto também relaciona os serviços que habilitam integrações. Eles são
opcionais e condicionais: instalar o pacote não implica habilitar o serviço em
todos os perfis. NetworkManager e BlueZ sustentam rede/Bluetooth; PipeWire e
WirePlumber sustentam áudio; UPower expõe estado de bateria; CUPS habilita
impressão; PPD habilita perfis de energia. Nenhum deles deve ser iniciado como
daemon concorrente pelo shell.

## Temas, paletas e wallpaper

| Parte | Onde vive / dependências | Implicação para reprodução |
| --- | --- | --- |
| Paletas internas | `scripts/theme_catalog.py` define as paletas embutidas; `services/ThemeState.qml` também mantém definições/valores consumidos diretamente pela UI. `catppuccin-mocha` é o padrão. Há variantes de Catppuccin, Dracula Pro e Rosé Pine, além de Tokyo Night, Nord, Gruvbox, Everforest, Kanagawa, Solarized, Ghostty e Chameleon Dark/Light/OLED. | Não exige baixar temas para a shell renderizar sua própria interface. A duplicação entre Python e QML é risco de divergência e precisa virar uma fonte de verdade ao empacotar. |
| Chameleon | `theme-manager.py`, `theme_colors.py` e código vendorizado `scripts/vendor/materialyoucolor`; Pillow para ler/extrair cores das imagens. Preferência manual ou automática é guardada em XDG state por identidade/hash do wallpaper. | O catálogo e algoritmo são distribuídos no repo; o wallpaper pessoal e sua preferência são dados de usuário e não vêm no pacote. Sem Pillow ou imagem legível, a extração/preview falha, embora paletas estáticas continuem disponíveis. |
| Wallpaper | `wallpaper-action.py` salva preferência em `$XDG_STATE_HOME/quickshell/wallpaper.json`, usa `$XDG_CACHE_HOME/current_wallpaper` e `$XDG_CACHE_HOME/quickshell/wallpaper-previews`, e lê `~/.config/waypaper/config.ini` apenas como legado. `ThemeState.qml` e `theme-manager.py` ainda observam/consultam `~/.cache/current_wallpaper`. A galeria procura pasta salva, pasta herdada de Waypaper, wallpaper atual e `~/Pictures/Wallpapers`; seleção usa `zenity` (ou `kdialog` para escolher um arquivo). | Waypaper não é dependência da shell nem do fluxo recomendado de primeiro login; pode ser instalado à parte. Biblioteca de imagens não é fornecida pelo projeto. Caminhos absolutos persistidos podem não existir na nova máquina; a migração deve pedir nova pasta ou degradar claramente. O cache de wallpaper ainda não usa XDG de forma consistente entre helper e tema. |
| Aplicar wallpaper | Um backend `awww` ou `swww`; `hyprpaper` é consultado como fonte de estado somente no perfil Hyprland. | Backend de imagem é escolhido no host e não pode ser presumido presente. O shell deve continuar usando o tema estático quando não houver backend ou wallpaper. |
| Sincronização de tema | Adapters opcionais em `theme-manager.py`: Kitty, Ghostty, Fastfetch, GTK, Qt/qt6ct + Kvantum, btop, Hyprland, hyprlock, labwc e Mango. | A paleta do próprio Quickshell é independente. Cada adapter depende de app/configuração própria; escrever um arquivo não prova que o aplicativo carregou o tema. GTK pode depender de tema base disponível. |
| Pastas de config de adapters | Maioria usa XDG, mas `~/.themes` é fixo para GTK e `~/.config/Kvantum` ignora `XDG_CONFIG_HOME` em alguns caminhos. Hyprland/hyprlock geram arquivos em `$XDG_CACHE_HOME/hypr`; labwc e Mango alteram configurações externas. | Esses caminhos e decisões do usuário precisam ser corrigidos ou documentados como exceções antes de suportar instalação relocável. Integrações não devem sobrescrever escolhas existentes sem migração explícita. |
| Preferências de adapters | `$XDG_CONFIG_HOME/quickshell/theme-integrations.json` controla individualmente os adapters externos; valores ausentes mantêm o comportamento atual (habilitado). | A preferência é portável como configuração, mas os arquivos/configs de destino permanecem locais. Desabilitar para futuras sincronizações não apaga arquivos existentes. |
| Recursos visuais | 89 SVGs Tabler locais e tokens QML; fontes de texto/ícones vêm do sistema (Noto Sans/Nerd Font). Templates GTK estão em `scripts/templates/`. | SVGs e templates fazem parte do pacote; fontes exigem redistribuição/licença/versionamento. Imagens de wallpaper e temas externos não devem ser tratados como assets do shell. |
| Luz noturna | `hyprsunset` ou `wlsunset` | Backends alternativos; comportamento/capacidade depende de compositor e deve ser detectado. |
| Sessão / bloqueio | `uwsm` no serviço atual; `hyprlock` no perfil Hyprland/labwc; `swayidle`/`wlopm` no autostart labwc; fontes Noto Sans e Noto Sans Nerd Font | Bloqueio e idle pertencem ao perfil externo de sessão, não ao runtime genérico. O `hyprlock.conf` usa `$HOME` para wallpaper, cores e helper da bateria; o helper precisa acompanhar os dotfiles. ThemeState gera o include de cores ao inicializar, em `~/.cache/hypr`; os demais temas Hyprland respeitam `XDG_CACHE_HOME`. `doctor.sh` verifica os requisitos do perfil quando Hyprland ou labwc está ativo. |
| Digital no bloqueio | `fprintd`, backend `libfprint` compatível com o leitor e dedo cadastrado; `hyprlock` com autenticação de digital | Hyprlock upstream funciona como backend padrão. No Arch, a recuperação após suspensão deste host está empacotada como `hyprlock-fingerprint`; a receita e os hooks ficam no projeto separado `~/Projetos/hyprlock-fingerprint`, fora do Quickshell. Hooks adicionais de systemd são modelos separados para Synaptics `06cb:00bd`; não se aplicam automaticamente a outro hardware. O patch ainda não foi adaptado nem validado fora do Arch, e cada máquina exige teste físico. |

Esta lista agrupa comandos confirmados em `scripts/doctor.sh`, comandos
invocados em QML/helpers e os dois guias. `doctor.sh` já os classifica em
obrigatórios e recursos opcionais, mas isso ainda não é um contrato automático
do manifesto: há divergências entre a lista e os comandos realmente montados.

Nos guias Arch, use nomes de pacotes, não nomes dos executáveis: a verificação
local de `pacman -Qo` confirmou que `nmcli` pertence a `networkmanager` e
`bluetoothctl` pertence a `bluez-utils` (com `bluez` para o serviço). Os nomes
inválidos `nmcli` e `bluetoothctl` foram removidos das linhas de instalação;
`network-manager-applet` também foi removido porque o applet não faz parte do
perfil do shell. Os perfis também declaram `awww` para aplicar wallpapers e
`zenity` para escolher imagens/pastas; `imagemagick` permanece opcional para
pré-visualizações de formatos especiais. As versões presentes no host são
evidência de ownership, não versões mínimas suportadas.

## Perfis de compositor e sessão

| Perfil | Integração atual | Lacunas para reprodução |
| --- | --- | --- |
| Hyprland | APIs `Quickshell.Hyprland`, `hyprctl`, dispatcher `scripts/compositor-dispatch.sh`, atalhos/regras em `~/.config/hypr/hyprland.lua`, `grimblast`, `hyprsunset`/`hyprpaper` | Arquivo de configuração, sessão UWSM e regras continuam externos ao repositório do shell; algumas integrações são específicas do Hyprland. |
| labwc | `ext-workspace-v1`/WindowManager genérico, `wtype`, `labwc --reconfigure`; atalhos em `~/.config/labwc/rc.xml`; perfil do autostart usa UWSM, kanshi, swayidle e hyprlock | `~/.config/labwc/autostart` contém caminho literal `/home/USER/.config/quickshell/...`; launcher da sessão e bloqueio ainda são próprios do perfil pessoal. `wlr-randr` e `swaylock` não são usados por esse perfil; `swaylock` permanece específico do perfil Mango. |
| Mango | `mmsg` via `MangoState.qml` e dispatcher; `MANGO_INSTANCE_SIGNATURE`; script pessoal exporta ambiente e inicia `mango-session.target` | `~/.config/mango/start-session.sh` contém caminho literal `/home/USER/...`; suporte existe mas não tem validação reprodutível equivalente. |

O serviço usado nesta máquina, `~/.config/systemd/user/quickshell.service`,
executa `/usr/bin/uwsm app -- /usr/bin/quickshell`. O repositório tem modelos
de unidades de CPU boost e LED de microfone, mas a unidade principal do shell
e alguns drop-ins estão fora dele. O perfil labwc/Mango ainda chama `awww`,
EasyEffects, Fcitx5, kanshi, swayidle, hyprlock ou outros processos no
autostart; isso pertence à sessão e não ao runtime mínimo da shell.

## Caminhos, dados e personalização

- O código usa XDG para parte do estado/cache (`XDG_CONFIG_HOME`,
  `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`), mas há exceções: o
  wallpaper ativo fica em `~/.cache/current_wallpaper`; o serviço usa
  `~/.config/quickshell`; caminhos de scripts usam `Quickshell.shellDir`.
- `labwc/autostart`, `mango/start-session.sh`, algumas unidades e docs atuais
  contêm caminhos ou comandos da configuração pessoal. `system-update.sh`
  e `brew-updates.sh` incluem caminhos fixos de Homebrew, incluindo
  `/home/linuxbrew/.linuxbrew`.
- Monitores, nomes de impressora, bateria/LED ThinkPad, regras udev, políticas
  locais de energia, Synaptics `06cb:00bd`, credenciais de rede e Polkit são
  características do host e não devem ser embutidas no pacote portátil.
- Capturas têm `XDG_SCREENSHOT_DIR` como override, mas o helper de edição volta
  a usar `$HOME/Imagens/Screenshots`; as pastas de procura do launcher usam
  nomes ingleses (`Documents`, `Downloads`, `Pictures`, `Videos`, `Music`) e
  precisam considerar `xdg-user-dir`/idioma local. A pasta Steam também é
  assumida em caminho padrão.
- Display Projection é somente Hyprland; lock/idle e atalhos não são recursos
  do pacote isolado, pois vêm dos perfis de sessão e suas dependências.
- Configurações/tokens de aplicativos integrados (Kitty, Ghostty, GTK,
  Fastfetch, Hyprland, labwc, Mango) são adapters opcionais do tema. Ausência
  do aplicativo deve resultar em adapter ignorado/indisponível.
- Dados do usuário, cache, histórico de clipboard/notificações e downloads
  precisam permanecer fora da árvore imutável do pacote. A exportação de
  preferências não deve incluir credenciais nem históricos privados.

## Lacunas prioritárias para o manifesto Arch Linux

1. Confirmar conjunto mínimo e versão/revisão Quickshell + Qt/QML plugins,
   incluindo o plugin `Qt5Compat.GraphicalEffects`, usado pela bateria.
2. Converter esta lista estática em manifesto por recurso e alinhar
   `doctor.sh` ao que é realmente obrigatório, opcional ou específico de perfil.
3. Fixar versões/revisões de Quickshell, Qt, Python, `python-requests`,
   `python-pillow` e dos módulos QML; verificar imports condicionais e licença
   do código vendorizado.
4. Remover caminhos literais pessoais, externalizar unidade principal e
   preferências de compositor/terminal/launcher, mantendo compatibilidade com
   a instalação atual.
5. Validar requisitos por perfil de compositor, serviços do sistema, agentes
   Polkit, portais e dependências Qt numa instalação Arch limpa.
6. Rever licenças e origem dos SVG Tabler, fontes e código Python vendorizado;
   fixar versões e gerar SBOM/licenças no pacote.

## Estado da inspeção

Mapeamento estático ampliado para imports QML e Python, ferramentas por
capacidade, serviços, caminhos externos, temas e wallpaper. A classificação cobre os
principais recursos, mas uma varredura seguinte ainda encontrou ferramentas
que precisavam ser registradas; portanto, não é possível garantir completude
até cruzar cada execução condicional com manifesto e `doctor.sh`. Faltam também
versões mínimas, licenças e comportamento em Arch Linux limpo. A etapa 1 segue
**em andamento**, sem fechar o critério de aceitação.
