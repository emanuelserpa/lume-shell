# Spotlight launcher — v0.20.27

Native Quickshell Spotlight-style launcher. With the Arch package installed,
use `lume-shell spotlight clipboard` (or `actions`, `emoji`, `windows`, and
other supported commands) as a short CLI for the running launcher.

## labwc keyboard-focus note

On labwc the launcher is driven via IPC (`quickshell ipc call spotlight …`,
bound in `~/.config/labwc/rc.xml`) because `hyprland_global_shortcuts_v1`
is unsupported. Two labwc-specific measures live in `Spotlight.qml`:

- explicit `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`
  (`import Quickshell.Wayland`) — `PanelWindow.focusable` alone does not
  make labwc transfer keyboard focus to the layer surface, so without this
  no keystroke reaches the search field;
- a short `focusRetry` timer re-issues `searchInput.forceActiveFocus()`
  until the input holds active focus, covering the map/focus latency that
  can eat the first keystrokes.

No behavior change on Hyprland, where the first request already succeeds.
On labwc, window switching and closing use Quickshell's Wayland
`ToplevelManager`; the `!` mode requests a window close rather than sending a
signal to a process. Hyprland keeps its PID-based kill mode.

In theme mode (`:tema`), keyboard coverage is complete without a mouse:
the active wallpaper starts centered in the Cover Flow, `↑↓` move through
wallpapers, `F6` toggles between gallery and theme catalog, arrows move in the
catalog grid, `Enter` applies the selected wallpaper or theme. Open
latency is guarded: `Spotlight.qml` logs app-side open time and
`validate.sh` warns past a 150ms budget.

## Action panel (`Ctrl+K`)

Per-result actions from `SpotlightActionCatalog.qml`, grouped as
Principal / Copiar / Ações / Gerenciar. Typing with the panel open
filters the actions; `↑↓` navigate, `Enter` runs, `Esc` closes the panel
back to the list. The bottom bar always mirrors primary (`↵`) and
secondary (`Ctrl+↵`) actions.

Current Hyprland bindings are in `~/.config/hypr/hyprland.lua`: `SUPER+D`
opens Spotlight, `SUPER+C` opens its clipboard history, `SUPER+A` opens
actions, `SUPER+SHIFT+E` opens emoji, `SUPER+SHIFT+C` reads a screen QR Code
into the clipboard (`scripts/scan-qr.sh`), and `SUPER+K` opens the window killer.
The Spotlight action “Ler QR Code da Tela” also starts that scanner; search for
“QR” anywhere in the launcher, or use `:captura qr`, press Enter, then select
the screen region. Screenshots and screen recordings are grouped under
`:captura` as well.
Versioned sections below record earlier bindings and feature changes.

In clipboard mode, clicking a result selects it for preview; `Enter` restores
the selected item to the clipboard and closes Spotlight. Long text can be
scrolled with the wheel or by dragging the preview scrollbar.

## Modes

Normal:
- searches DesktopEntries
- fuzzy/subsequence matching
- matches name, executable (`Exec=` basename; Flatpak wrappers resolve to
  the app id and `--command`), generic name, keywords, categories, comment
- app-use ranking when empty

`@ query`
- file/folder search under the user's home directory
- prefers `fd`, with a conservative Python fallback
- Enter opens through `xdg-open`

`~ query`
- window switcher across Hyprland workspaces
- Enter switches workspace and focuses window via native Lua dispatcher

`# query`
- clipboard history through native Wayland backend (`wl-clipboard` + SQLite)
- 2-column split view (Raycast / Alfred style) with live preview pane
- up to 50 search results with full multi-line text search
- instant unblocked Enter (no waiting for background sync)
- PageUp / PageDown navigation and Shift+Up / Shift+Down preview scrolling
- semantic badges and syntax detection: `TEXTO`, `LINK`, `CÓDIGO`, `IMAGEM`
- instant item deletion via `Shift+Delete` or `󰆴 Del` button

`: query`
- session/system actions:
  - lock
  - suspend
  - logout seguro com `hyprshutdown`
  - reboot
  - desligamento seguro com `hyprshutdown`, seguido de `systemctl poweroff`

`> command`
- opens a visible terminal and runs the command

`= expression`
- arithmetic calculator
- Enter copies the calculated result directly through `wl-copy` and closes launcher
- Ctrl+C also copies the current calculator text through `wl-copy`
- In the action panel, “Copiar expressão” copies the original arithmetic expression

## Recent-app ranking

App launches are persisted at:

    ~/.local/state/quickshell/launcher-usage.json

When the search field is empty, frequently launched apps rise to the top.

## Dependencies

Core:
- Quickshell / Hyprland

Recommended:
- `fd` for fast file search
- `wl-clipboard` (`wl-paste`, `wl-copy`) for native clipboard capture and restore

Without `fd`, file search falls back to common user directories.
Clipboard mode uses a persistent native Wayland daemon with local SQLite storage (see `docs/clipboard.md`).

## Historical Hyprland shortcut example

    bind = SUPER, SPACE, global, quickshell:spotlight

For hyprland.lua, keep using your existing global binding for:

    quickshell:spotlight


## Hyprland integration / replacing Wofi

Additional global shortcuts:

    quickshell:spotlight-emoji
    quickshell:spotlight-kill

Recommended Lua bindings:

    hl.bind(mainMod .. " + D", hl.dsp.global("quickshell:spotlight"))
    hl.bind(mainMod .. " + SHIFT + E", hl.dsp.global("quickshell:spotlight-emoji"))
    hl.bind(mainMod .. " + K", hl.dsp.global("quickshell:spotlight-kill"))

Use the active `~/.config/hypr/hyprland.lua` for these bindings.

Emoji mode uses an integrated Unicode CLDR Portuguese (PT-BR) dataset
with English aliases and intelligent scoring. It supports Portuguese terms,
gírias (ex: joinha, kkk, s2), accents/diacritics, and popularity ranking.
The picker filters non-emoji punctuation from the catalog before ranking.
Choosing or copying an emoji records its usage in
`$XDG_STATE_HOME/quickshell/launcher-emoji-usage.json` (defaulting to
`~/.local/state/quickshell/launcher-emoji-usage.json`). Repeated use adds a
bounded ranking bonus in both the initial grid and matching search results.
`wl-copy` and `wtype` are used to paste the chosen emoji back into the active app.

Kill mode reads current windows from `hyprctl clients -j` on Hyprland and
from `ToplevelManager` on labwc (where `!` closes the window instead of
killing by PID), preserving the previous kill-by-PID behavior on Hyprland.


## v1.1.0 — Raycast / Alfred-style Clipboard Split View & Instant Enter

The `#` clipboard manager has been thoroughly redesigned:

1. **Two-Column Split View**:
   - In clipboard mode (`#` or `SUPER+C`), the Spotlight window smoothly expands from 560px to 820px wide and 500px high with easing animations (`NumberAnimation { duration: 160 }`).
   - Left column (360px): keyboard-navigable list showing up to 50 matching results with semantic icons.
   - Right column: live preview pane with a metadata header and a Catppuccin mantle preview card.
   - Other launcher modes (`>`, `=`, `@`, `:`, `;`, `!`, `~`) remain compact at 560px.

2. **Live Preview Pane**:
   - **Type Badges**: `TEXTO` (blue), `LINK` (cyan), `CÓDIGO` (green), and `IMAGEM` (pink).
   - **Metrics**: Displays line and character counts (e.g. `20 linhas · 903 caracteres`) or image format details.
   - **Text Preservation**: Preserves raw formatting, newlines, and indentation (up to 8,000 characters) displayed in `JetBrainsMono Nerd Font` with text selection support.
   - **Image Preview**: Full aspect-ratio thumbnail previews for PNG, JPEG, SVG, WebP.
   - **Scroll & Controls**: Supports mouse wheel (`WheelHandler`), a custom thin scrollbar, and `Shift+Up`/`Shift+Down` keyboard scrolling. The preview scroll position resets to the top when navigating between items.

3. **Instant Enter Unblocking**:
   - `Enter` restores the selected item by its permanent SQLite ID and SHA-256 signature through `wl-copy`, then closes Spotlight.

4. **Expanded Search & Navigation**:
   - Searches across both summary preview and `fullText`.
   - Result limit raised to 50 items (backend snapshots 60 items in ~0.15s).
   - Supports `PageDown` and `PageUp` to page through 6 items at a time.

5. **Mouse-Friendly Paste & Header Actions**:
   - Clicking an unselected item previews it without closing the launcher.
   - Clicking an already-selected item (or double-clicking) immediately restores and closes.
   - Clickable interactive `↵ Colar` pill button in the preview header.

6. **Item Deletion (`Shift+Delete` / `󰆴 Del`)**:
   - Delete items directly via `Shift+Delete` (or `Delete` when cursor is at the end of the query).
   - Interactive `󰆴 Del` button in the preview header.
   - Removes item safely matching its ID and SHA-256 signature and removes it from the local list instantly.


## v1.2.0 — Native Wayland Clipboard Manager (SQLite Backend)

The `#` clipboard manager backend was completely migrated from CopyQ to an internal native Wayland backend:

1. **Architecture & Persistence**:
   - **Daemon**: `scripts/clipboard-daemon.py` acts as a supervisor using `wl-paste --watch` with a singleton flock (`daemon.lock`).
   - **Database**: `scripts/clipboard_store.py` stores items in SQLite at `~/.local/share/quickshell/clipboard/clipboard.db` (`WAL` mode, `busy_timeout = 5000`).
   - **Blob Storage**: Image content is saved in `~/.local/share/quickshell/clipboard/blobs/<sha256>.<ext>`, preventing large binary data from bloating SQLite tables.
   - **Lifecycle Management**: Managed directly by Quickshell via `services/ClipboardService.qml` instantiated in `ShellRoot` (daemon supervisor; clipboard data itself flows through `scripts/launcher-data.py`).

2. **Permanent IDs & Atomic Deletion**:
   - Every item receives a permanent SQLite autoincrement `id`.
   - Item removal (`Shift+Delete` / `󰆴 Del`) deletes by exact ID and content hash, eliminating previous bugs where deleted items reappeared due to CopyQ index shifting.
   - Instant local filtering in `Spotlight.qml` provides zero-latency removal feedback.

3. **Loop Prevention & Deduplication**:
   - Restoring an item via `wl-copy` does not create a duplicate or trigger an infinite loop in `wl-paste --watch`.
   - Copying an existing item promotes it to the top of the history without creating duplicate rows.

4. **Preserved UX**:
   - The entire frontend experience in `launcher/Spotlight.qml` is 100% preserved (820×500 geometry, Raycast/Alfred split view, badges, preview metrics, image thumbnails, keyboard shortcuts).
