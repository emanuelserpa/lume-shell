# Spotlight Launcher

O launcher nativo do Lume (`launcher/Spotlight.qml`) reúne busca universal de
aplicativos, arquivos, janelas, área de transferência, calculadora, emoji, ações
do sistema e estúdio de temas.

Com o pacote Arch instalado, também é possível abrir diretamente pelos comandos:

```sh
lume-shell spotlight toggle
lume-shell spotlight clipboard
lume-shell spotlight actions
lume-shell spotlight emoji
lume-shell spotlight kill
```

## Modos de busca

| Prefixo | Modo | Comportamento principal |
| --- | --- | --- |
| *(sem prefixo)* | Busca universal | Aplicativos (`DesktopEntries`), abas rápidas, URLs (`http`/`https`) para download com `yt-dlp` e ações correspondentes |
| `@` | Arquivos | Busca sob a pasta pessoal usando `fd` (com fallback em Python) e abre via `xdg-open` |
| `~` | Janelas | Lista janelas abertas e foca a selecionada pelo adaptador do compositor |
| `#` | Clipboard | Visão em duas colunas com pré-visualização, miniaturas e histórico persistido ([detalhes](clipboard.md)) |
| `:` | Ações e rotas | Sub-rotas `:tema` (`:theme`, `:config`), `:tela`, `:luz`, `:energia`, `:captura`, `:conexoes`, `:sistema`, `:sessao` |
| `>` | Comando | Abre um terminal visível e executa o comando digitado |
| `=` | Calculadora | Avalia expressões aritméticas; `Enter` e `Ctrl+C` copiam o resultado via `wl-copy` |
| `;` | Emoji | Catálogo Unicode CLDR PT-BR com busca por gírias/aliases, `Theme.emojiFontFamily` e ranking de uso |
| `!` | Encerrar janela | Mata o processo (Hyprland) ou solicita fechamento da janela via `ToplevelManager` (labwc) |

## Painel de ações (`Ctrl+K`)

Cada resultado expõe ações contextuais organizadas em `SpotlightActionCatalog.qml`
(`Principal`, `Copiar`, `Ações`, `Gerenciar`). Digitar filtra as ações, `↑↓`
navega, `Enter` executa a primária, `Ctrl+Enter` executa a secundária e `Esc`
retorna à lista principal.

## Comportamento por compositor e persistência

- **Abertura de aplicativos:** a ação principal e “Nova instância” iniciam
  a entrada desktop em um escopo próprio do systemd de usuário. Reiniciar o
  serviço do Lume deixa esses aplicativos em execução.
- **Hyprland:** integra atalhos globais (`quickshell:spotlight*`) e despacho de
  janelas via `scripts/compositor-dispatch.sh`.
- **labwc:** como `hyprland_global_shortcuts_v1` não está disponível, o
  `Spotlight.qml` define `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`
  e retenta `searchInput.forceActiveFocus()` até garantir foco de teclado ao
  abrir por IPC (`quickshell ipc call spotlight …`).
- **Estúdio de temas (`:tema`):** navega entre galeria de wallpapers e catálogo
  de temas (`F6` alterna entre os painéis, setas movem e `Enter` aplica). Veja
  [Temas e wallpapers](theme-management.md).
- **Persistência de uso:** lançamentos de aplicativos ficam em
  `$XDG_STATE_HOME/lume-shell/launcher-usage.json` e emojis usados em
  `$XDG_STATE_HOME/lume-shell/launcher-emoji-usage.json`.

## Referências relacionadas

- [Plano do Spotlight](../plans/spotlight-raycast-plan.md)
- [Clipboard nativo](clipboard.md)
- [Downloads com yt-dlp](ytdlp-downloads.md)
- [Temas e wallpapers](theme-management.md)
