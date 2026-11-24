# Plano de padronização de caminhos em `lume-shell`

## Objetivo

Unificar todos os diretórios XDG, locks, diretórios privados de runtime,
identificadores de notificação/User-Agent e metadados do adaptador de temas de
propriedade do Lume sob o identificador único `lume-shell`, preservando:

1. O funcionamento do runtime Quickshell (`import Quickshell`, `/usr/bin/quickshell`, `quickshell ipc`).
2. Os caches/diretórios internos gerenciados pelo próprio binário Quickshell (`by-shell`, `qmlcache`, `qt*`, `crashes`, `migrations`, `/run/user/$UID/quickshell/by-id`).
3. Os dados já existentes do usuário, migrados de forma automática e idempotente sem sobrescrever destinos já presentes.
4. Consumidores externos legados — em especial a leitura da paleta canônica em `~/.local/state/quickshell/current_palette.json`, o bloco de tema do Kitty e os atalhos globais do Hyprland (`quickshell:spotlight*`).

## Inventário e classificação

### 1. Diretórios XDG migrados para `lume-shell`

| Categoria XDG | Caminho canônico (`lume-shell`) | Origens legadas migradas | Observações |
| --- | --- | --- | --- |
| Config (`$XDG_CONFIG_HOME`) | `lume-shell/bar.json`, `lume-shell/workspaces.json`, `lume-shell/power/{cpu-boost,power-profile}.json` | `quickshell/*`, `lumeshell/power/*` | Remove `lumeshell/power` e `lumeshell` após vacância. |
| State (`$XDG_STATE_HOME`) | `lume-shell/{theme,chameleon-palette,wallpaper-color-preferences,current_palette,adapters,display-projection,glass,clipboard-capture,launcher-*,nightlight,wallpaper,weather}.json`, `kitty-theme.conf`, `theme-manager.lock`, `ytdlp/` | `quickshell/*` | `current_palette.json` e `kitty-theme.conf` mantêm symlink de compatibilidade no diretório `quickshell/`. |
| Data (`$XDG_DATA_HOME`) | `lume-shell/clipboard/`, `lume-shell/notifications/` | `quickshell/{clipboard,notifications}/` | Reescreve prefixos antigos na coluna `image` de `notifications.db` mantendo miniaturas válidas. |
| Cache (`$XDG_CACHE_HOME`) | `lume-shell/{weather.json,clipboard-index.json,clipboard-change,update.log,update.status.json}`, `clipboard-thumbs/`, `wallpaper-previews/` | `quickshell/*` | Preserva intactos `qmlcache/`, `qt*`, `by-shell/` e `crashes/`. |

### 2. Runtime, processos auxiliares e adaptadores

- **QML (`services/ShellPaths.qml`)**: expõe `appName: "lume-shell"`, `configDirectory`, `cacheDirectory`, `stateDirectory`, `dataDirectory` e os helpers `configFile()`, `cacheFile()`, `stateFile()`, `dataFile()`.
- **Python (`scripts/lume_paths.py` e `scripts/migrate-paths.py`)**: centraliza resolução XDG dinâmica por `os.environ`, isolamento seguro em testes (quando `lume-shell` não compõe o path sobrescrito, `legacy_siblings()` retorna lista vazia), movimentação atômica e `migrate_all()`.
- **Locks e logs em `/tmp` / `XDG_RUNTIME_DIR`**: `lume-shell-bluetoothctl.lock`, `lume-shell-<uid>/wifi-qr.png`, `lume-shell-recording`, `lume-shell-update-<uid>.log`, `lume-shell-lock.lock`, prefixo `lume-shell-clipboard:` e serviço de usuário `system/systemd/user/micmute-led.service` (`/usr/share/lume-shell/scripts/micmute-led.sh`).
- **Notificações e rede**: `appName ?? "Lume Shell"` em `NotificationState.qml`, `notify-send -a lume-shell` nos scripts de QR/screenshot, `User-Agent` `lume-shell Weather` / `lume-shell Weather City Manager`.
- **Tema e adaptadores (`scripts/theme-manager.py`, `services/ThemeState.qml`, `controlcenter/SettingsWindow.qml`)**: chave `syncedAdapters["lume-shell"]`, temas GTK `lume-shell-<id>`, socket do Kitty `lume-shell-kitty-{kitty_pid}` com substituição automática do bloco legado `# BEGIN Quickshell theme integration` sem duplicação.

### 3. Fronteiras mantidas sem alteração

- **Contrato Hyprland (`GlobalShortcut`)**: mantém `appid: "quickshell"` em `launcher/Spotlight.qml` para não quebrar atalhos globais existentes (`global, quickshell:spotlight*`).
- **Filtro de áudio PipeWire (`bar/Audio.qml`)**: aceita tanto streams `quickshell` quanto `lume-shell`.
- **Camada root de empacotamento (`packaging/arch/PKGBUILD`, `system/polkit/`, `system/systemd/`, `packaging/pam/`)**: mantém os nomes estáveis `/usr/lib/lumeshell/lumeshell-*`, regras Polkit `50-lumeshell-*.rules` e perfis PAM `lumeshell-lock*` para evitar conflitos `.pacsave` ou unidades órfãs em upgrades Arch existentes.

## Verificação

- Suite completa de testes unitários Python, incluindo `tests/test_lume_paths.py` cobrindo migração completa, não-sobrescrita, preservação de caches internos Quickshell, reescrita de imagens no SQLite de notificações, symlink `current_palette.json` e upgrade do bloco Kitty.
- Validador completo `./scripts/validate.sh --offline` (`qmllint` estrito em todos os arquivos QML, verificação de bits executáveis, links Markdown locais e `qmltestrunner`).
