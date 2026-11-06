# Unreleased — privacy and media hover

- Spotlight yt-dlp downloads: pasting a link offers video/audio actions with
  a small confirm panel (title, thumbnail, duration, quality, format,
  destination with remembered choices). `scripts/ytdlp-download.py`
  (`info|start|status|cancel|recent|prefs`, detached spawn, no shell)
  backs `launcher/DownloadPanel.qml` and the `DownloadState` singleton,
  which polls only while jobs run and notifies on completion. `downloads`
  lists recent jobs (open folder, retry, cancel). See
  `docs/ytdlp-downloads.md`.

- Popup Material You M3 elevation: elevate shell popups (`NetworkPopup`, `BluetoothPopup`, `PhonePopup`, `AudioPopup`, `SinkSelector`, `ScreenRecordingPopup`, `NotificationPopup`, `SystemUpdatePopup`, `MediaPopup`) to pure Material Design 3 principles. Systematically replace fixed/hardcoded `theme.green` and `theme.cyan` on active rows, hero icons, and toggle switches with the dynamic wallpaper Chameleon tokens `primary` / `primaryContainer` / `onPrimary`, strictly reserving `theme.green` for semantic status (battery health > 20%, low ping latency < 60ms, speed test and process completion). Standardize all popup section headers in uppercase letter-spaced typography (`pixelSize: 9`, `letterSpacing: 0.5`, `color: theme.onSurfaceVariant`, `weight: DemiBold`) and upgrade micro-labels from low-contrast `theme.grey` to `theme.onSurfaceVariant` for WCAG 2.1 AA compliance.
- Network popup design system harmonization: refactor `bar/NetworkPopup.qml` to match the exact shell design language of `BluetoothPopup.qml` and `PhonePopup.qml`. Replace dual rigid Flickables (`wifiScroll` + `vpnScroll`) with a single fluid `scrollArea` powered by `WheelKinetic` and a sleek vertical `scrollIndicator`. Eliminate loud electric cyan styling and hardcoded alpha magic in favor of canonical Material 3 tokens (`cardBackgroundSubtle`, `cardBackgroundHover`, `borderSubtle`, `outlineVariant`, `primary`, `onPrimary`, and `green` for active/connected indicators). Unify uppercase letter-spaced section headers (`REDES WI‑FI`, `VPN`), responsive anchored left/right rows, and dynamic popup sizing without empty layout letterboxing.

- Material You M3 Chameleon optimization: elevate Quickshell to Google Material Design 3 (M3)
  tonal surfaces and state layer opacities. Unlock native M3 roles in `theme-manager.py`
  via `SchemeTonalSpot` (`surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`,
  `surfaceContainerHigh`, `surfaceContainerHighest`, `outlineVariant`, `secondary`, `tertiary`)
  and expose them as tokens in `Theme.qml` alongside canonical M3 State Layer opacities
  (`stateHover`: 0.08, `statePress`: 0.12, `stateFocus`: 0.12, `stateDragged`: 0.16).
  Harmonize dividers across popups and Spotlight to use `outlineVariant`. Eliminate legacy
  Catppuccin `theme.blue` leaks in interactive elements, form focus borders, buttons, and badges
  across 27 files, systematically routing actions and selections through `primary`, `onPrimary`,
  `primaryContainer`, and `onPrimaryContainer`.
- Central dashboard popup theme harmony: replace legacy hardcoded Catppuccin Mocha
  RGB decimals and arbitrary blue tints across `CalendarCard.qml`, `WeatherCard.qml`,
  and `ControlCenterCard.qml` with dynamic semantic theme tokens (`theme.accent`,
  `theme.cardBackgroundSubtle`, `theme.cardBackgroundHover`, `theme.glassBorderSubtle`,
  `theme.onPrimary`, etc.); add a centralized `theme.sliderTrack` neutral grey token
  to replace `cardBackgroundActive` (which leaked purple `surfaceSelected` onto the inactive
  track) across `SliderRow.qml`, telemetry bars, battery, audio, and brightness popups.
- Validation test suite: enhance QML color verification in `scripts/validate.sh`
  to check for numeric `Qt.rgba`, `Qt.rgb`, `Qt.hsla`, and `Qt.hsva` literals in addition
  to hex `#...` values, preventing hardcoded color regressions outside `Theme.qml`.
- QML color cleanup: remove all 181 validator findings across 22 UI files, route
  translucent palette variants through `Theme.withAlpha()`, and preserve the
  Catppuccin Mocha audio selection and media hero gradient while adapting them
  to other palettes.
- Notification battery icons: replace low-res/blurry Breeze desktop status SVGs with sharp Nerd Font
  battery glyphs and tinted container badges in both toast popups and notification history; dynamically
  adapt glyphs and theme colors (`󰂄` green for charging, `󰂃` red for critical, `󰁺` yellow for low
  battery); move low-battery detection and alerts into the global Quickshell services, sharing the
  native toast, DND, history, count, and dismissal flow instead of the standalone notification service.
- Spotlight consistency pass: unify action bar visibility across clipboard and search modes,
  align emoji grid cursor with `selectedIndex` and action execution, use dedicated
  theme/settings prefix icons (`󰔎` and `󰒓`), complete Backspace category transitions for
  `:tela` and `:captura`, and register missing kind labels and glyphs in `SpotlightActionPanel`.
- Spotlight `:tema` mode visual and UX refinement: integrate Raycast-style action bar
  footer with dynamic primary actions and theme context, add Ghostty/Hyprland sync
  indicator pills, upgrade wallpaper gallery controls and floating filename badge,
  transform Material You swatches into responsive capsule pills, and support
  bidirectional keyboard navigation (Tab/F6 zone toggle, 2D grid arrows, Enter to apply).
- Media popup hover previews dismiss on outside click under Hyprland while
  retaining delayed open, hover transfer, and click-to-pin behavior.
- QML clean-code pass: bind nested components explicitly, qualify delegate
  model and owner state, remove unused imports, and add the `qs.launcher`
  module declaration. `qmllint` now checks all 86 QML files with zero warnings
  and blocks unqualified access; narrowly scoped suppressions document gaps in
  the installed Qt/Quickshell type metadata.
- Fix QML state/API collisions found during the audit: `CommandJson` exposes
  decoded JSON as `payload` instead of shadowing `Item.data`; `WheelKinetic`
  uses `scrollTarget`/`scrollOrientation`; night-light state uses
  `nightLightEnabled`; and the theme service exports `currentPalette`.
- Fix the Spotlight emoji hover binding to use `MouseArea.containsMouse` and
  preserve existing delegate IDs while qualifying model access, preventing
  duplicate IDs from breaking Quickshell reloads.

- Notification actions share one button component across toasts and history,
  keeping label mapping and interaction behavior in one place.
- QML component boundaries, state ownership, shared UI, and isolated-test
  practices are now documented.
- Notification “Limpar” now dismisses history in small timed batches so clearing a large list does not freeze the shell.
- `Ctrl+Shift+Space` restores notification toasts from an in-memory queue,
  newest first, then advances to older notifications on repeated presses.

- Central dashboard: move the five session shortcuts out of the calendar into
  a labeled `Sessão` menu beside system updates; confirm logout, reboot, and
  poweroff in both entry points, with keyboard navigation and Spotlight search retained.

- Spotlight themes now feature a larger active wallpaper preview and a virtualized gallery with a selectable folder and persistent image choice. A single click selects with a visible border; left/right arrows move selection, and Enter or a double click applies it.
- Gallery touchpad scrolling has kinetic motion and follows the user's conventional direction (fingers down advance). The native folder picker opens above Spotlight, which returns to theme mode after it closes.
- The wallpaper helper lists the full library, preserves the chosen folder, and restores the saved image at login; local Hyprland and labwc startup commands now call it instead of Waypaper.
- Chameleon gains `chameleon-tonal` (Material You Tonal Spot roles) and
  `chameleon-light` variants; `Modo Claro` targets the light variant.
- Theme view: wallpaper gallery with keyboard nav (arrows + Enter,
  WheelKinetic scroll), theme catalog grid, adapter pills; `:config`
  index consolidated from 6 to 4 categories.
- Helper JSON envelopes carry `"version": 1`, pinned by contract tests.
- Labwc support uses native workspaces and Wayland toplevels; session,
  recording, screenshots, and visual checks choose the active compositor.
- The labwc network UI prompts for protected Wi-Fi passwords directly
  (stdin to `nmcli --ask`); `nm-applet` is not used in any session.
- labwc theme follows the shell palette: `theme-manager.py` syncs a new
  `labwc` adapter (`themerc-override` + live reconfigure), and `Theme.qml`
  floors opacity without blur.
- Workspace icons are user-editable: copy `workspaces.json.example` to
  `workspaces.json` (gitignored), set glyphs per position 1–10, and the bar
  hot-reloads on save with fallback to defaults.

- Bar pills: right-click now carries context actions (DND on the bell,
  caffeine on the clock, power on Bluetooth, refresh on Network/Printer/
  Weather, ping on Phone, mute on Audio); middle-click does nothing except
  tray app menus. Tooltips advertise each action; settings stay behind the
  popup header gear.
- Media pill: clicking a hover preview pins it open instead of closing it.
- Tray filters hidden items at the icon source so nm-applet/fcitx5 never
  load theme icons (past KIconLoader SIGSEGV).
- Spotlight matches executables (`Exec=` basename; Flatpak resolves to app
  id + `--command`) and the docs gain `docs/system-setup.md` (Hyprland
  bindings, Flatpak theming, CUPS landscape, retired CopyQ, kdeconnect).

- Traditional start menu (`bar/StartButton.qml` + `bar/StartMenu.qml`):
  left-end pill opening a category browser (categories + app counts on
  the left, apps on the right). Search stays in Spotlight. Entries
  without a resolvable theme icon are hidden.

- Moves Steam game activity from the right-side bar pill into the central
  dashboard's former Theme tile; the tile opens Steam and checks only while
  the dashboard is visible. Theme switching remains in Spotlight.

- Adds a dedicated printing queue window from the compact printer popup, with
  a scrollable pending-document list, manual refresh, and cancellation.

- Self-hiding gaming indicator pill (`bar/Gaming.qml` + `scripts/game-status.py`):
  shows while a Steam game runs (click opens Steam), zero bar space otherwise.

- Shared `components/WheelKinetic.qml`: touchpad 1:1 tracking with kinetic
  glide, adopted by notification, Bluetooth, network, dashboard, clipboard
  and printer scroll views (mouse-notch feel preserved per view).

- Serialize concurrent `bluetoothctl` calls through shared `scripts/bt_ctl.py`
  (lockfile + one retry on SIGABRT) to work around upstream bluez#2434.

- Add battery charge-limit control (Eco 80% / Viagem 100%) to the battery
  popup via `scripts/battery-charge-limit.py`, reusing the power-profile
  selector UI; requires the sudoers rule for `tlp setcharge`/`fullcharge`.
- Auto-restore the 80% limit when the charger is unplugged via the user
  service `tlp-battery-monitor.service`.

- Pass manually entered Wi-Fi passwords and copied network text to helpers
  through stdin instead of command-line arguments.
- Save generated Wi-Fi QR images in a private runtime directory with restricted
  permissions.
- Exclude common local secrets and caches from Git and document a source-only
  sharing workflow; replace personal location examples in documentation.
- Open the compact media panel on hover without grabbing focus, keep it open
  while moving into the panel, and allow a click to keep it open.
- Standardize helper script JSON output contracts across network, bluetooth,
  printer, energy profiles, and weather cities with a predictable envelope:
  `{"ok": bool, "error": str | null, ...}`.
- Catch network and API exceptions in `scripts/weather-cities.py` and output
  structured JSON errors rather than raw Python tracebacks.
- Add `tests/test_contracts.py` ensuring contract conformance and error envelope
  integrity across all helpers.
- Eliminate redundant network and bluetooth background processes by sharing
  bar widget state with the central dashboard ControlCenterCard, avoiding
  duplicate polling when the dashboard is open.
- Add visual regression checklist (`docs/visual-regression-checklist.md`) and
  automated surface and typography verification script (`scripts/visual-check.sh`
  and `./scripts/validate.sh --visual`).
- Decouple QML UI from compositor-specific CLI syntax and commands by introducing
  `scripts/compositor-dispatch.sh`, encapsulating workspace and window focus dispatch
  with automatic Lua (`hl.dsp.*`) and classic hyprlang dual compatibility.
- Ensure native Wayland layer-shell grab focus (`grabFocus: true`) is consistently used across all popups for reliable outside-click dismissal.

- Add an automated compositor agnosticism check to `scripts/validate.sh`, failing
  if any UI QML component directly invokes `hyprctl` or contains Lua dispatcher syntax.
- Document compositor boundary rules in `AGENTS.md` and `docs/architecture.md`.
- Add audio recording toggle to screen recording:
  - Support `--audio` (`-a`) in `scripts/screen-recording.py` to capture audio via PipeWire with `wf-recorder`.
  - Add interactive audio toggle card with animated switch in `bar/ScreenRecordingPopup.qml`.
  - Display audio status indicator (`󰕾`) in bar pill and tooltip during active recordings with sound.
  - Add regression unit tests in `tests/test_screen_recording.py`.
- Add multi-theme support with 7 popular community color palettes:
  - Implement `services/ThemeState.qml` singleton managing live palette switching.
  - Dynamically bind all color tokens in `Theme.qml` to the active theme palette.
  - Curate 7 community themes: Catppuccin Mocha, Tokyo Night, Nord, Gruvbox Dark, Dracula, Rosé Pine, and Catppuccin Latte.
  - Implement `scripts/theme-manager.py` CLI helper with state persistence in `~/.local/state/quickshell/theme.json`.
  - Add interactive theme card to `bar/ControlCenterCard.qml` for single-click theme cycling.
  - Integrate theme switching into Spotlight launcher (`launcher/Spotlight.qml`) via `:tema` and `:theme` filters.
  - Add unit test suite in `tests/test_theme.py`.

# v1.2.0 — Native Wayland Clipboard Backend (SQLite + wl-clipboard)

- **Complete CopyQ Independence**:
  - Migrated clipboard manager from external CopyQ to a native Wayland architecture.
  - Implemented `scripts/clipboard-daemon.py` supervisor using `wl-paste --watch` with singleton file locking (`daemon.lock`).
  - Implemented `scripts/clipboard_store.py` SQLite persistence layer (`WAL` mode, `busy_timeout = 5000`) with dedicated blob store (`~/.local/share/quickshell/clipboard/blobs/`) for image assets.
  - Managed daemon lifecycle directly in Quickshell root via `services/ClipboardService.qml` and `services/ClipboardState.qml`.
- **Notification Hardening (Elimination of Empty/Ghost Notifications)**:
  - Fixed logic flaw where notifications with valid `appName` (e.g. Spotify, Zen Browser) but empty summary and body bypassed filtering.
  - Implemented strict useful content verification (`notificationHasUsefulContent`): requires non-placeholder summary, non-placeholder body, genuine image attachment, or actionable buttons.
  - Added explicit immediate dismissal (`n.dismiss()`) and un-tracking (`n.tracked = false`) for discarded notifications.
  - Enforced content filter directly in `NotificationState.tracked` dynamic property so empty entries are excluded from history and count badge.
  - Added defensive guards in `NotificationToasts.qml` and `NotificationPopup.qml` delegates.
  - Added comprehensive unit test suite in `tests/test_notifications.py`.
- **Bug Fix: Deleted Items Reappearing ("sempre volta")**:
  - Replaced fragile positional indices with permanent SQLite autoincrement IDs and SHA-256 signatures.
  - Item deletion (`Shift+Delete` / `󰆴 Del`) targets exact ID and hash, preventing index shifting race conditions.
  - Added instant local QML filtering in `Spotlight.qml` for instantaneous UI feedback without waiting for background process completion.
- **Loop Prevention & Deduplication**:
  - Automatic detection and suppression of duplicate copies when restoring items via `wl-copy`.
  - Re-copying an existing item bumps it to the top of the history without creating duplicate database rows.
- **Preserved Frontend UX**:
  - Maintained 100% of the Spotlight clipboard UI (`#` / `SUPER+C`): 820×500 split-view, 360px list, preview pane, type badges (`TEXTO`, `LINK`, `CÓDIGO`, `IMAGEM`), aspect-ratio preserved thumbnails, and keyboard navigation.
- **Migration & Testing**:
  - Added `scripts/clipboard-import-copyq.py` for safe one-shot import of existing CopyQ history.
  - Added comprehensive test suite `tests/test_clipboard.py` covering store operations, pruning, restore, deletion, deduplication, and daemon execution.
  - Created detailed architecture documentation in `docs/clipboard.md`.

# v1.1.0 — Spotlight Clipboard Split View, Speedtest & Network Polish

- **Spotlight Clipboard Redesign (Raycast / Alfred Style)**:
  - Dynamically expands from 560px to 820×500px in clipboard mode (`#` or `SUPER+C`) with smooth easing transitions.
  - Implements 2-column split view: 360px filterable results list on the left, live preview pane on the right.
  - Preserves full text formatting, indentation, and newlines up to 8,000 characters in `JetBrainsMono Nerd Font` with mouse selection.
  - Renders image previews with preserved aspect ratio for PNG, JPEG, WebP, and SVG formats.
  - Adds semantic badges (`TEXTO`, `LINK`, `CÓDIGO`, `IMAGEM`) and live metrics (line/char counters).
  - Unblocks `Enter` activation immediately without waiting for background cache refresh.
  - Expands history search to 50 items with full text search across content.
  - Adds `PageUp`/`PageDown` navigation (6 items per page) and `Shift+Up`/`Shift+Down` preview scrolling.
  - Introduces `monoFontFamily` design token in `Theme.qml`.
- **Network Speedtest & IPv6 Fix**:
  - Forces IPv4 address resolution in `scripts/network-speedtest.py` to prevent 30-second socket timeouts on dual-stack connections.
  - Implements live chunked upload test over `HTTPSConnection`.
  - Harmonizes Network popup (`bar/NetworkPopup.qml`) with `glassBorder`, `glassBorderSubtle`, and unified `󰅖` close action.
- **Notification Subsystem**:
  - Adds dedicated documentation (`docs/notifications.md`) covering toasts, server, popup contract, and HTML entity decoding.

# v1.0.0 — first stable release

- Promotes the proven v0.21.3 configuration to the first stable 1.0 release.
- Establishes the current bar, Spotlight launcher, popup, OSD, network,
  Bluetooth, weather, media, clipboard, and SwayNC integrations as the stable
  baseline.
- Keeps the v0.21.3 simplified bar and leaves the Control Center disabled.
- Introduces no runtime or visual changes.

# v0.21.3 — simplified bar, Control Center disabled

- Based on `v0.21.1-mousefix`.
- Disables the Control Center from `shell.qml`.
- Removes the `SUPER+A` Control Center binding from the bundled `hyprland.lua`.
- Removes the far-right Control Center button from the bar.
- Removes the far-left launcher magnifier button from the bar.
- Keeps the Spotlight launcher itself available through its keyboard shortcuts.
- Reclaims the left/right bar spacing now that the edge buttons are gone.
- Keeps the v0.21.1 media-state and contrast fixes.
- Keeps the outside-click Control Center fix in the source tree for future re-enabling,
  although the Control Center is not instantiated in this version.

# v0.21.1-mousefix — v0.21.1 + outside-click dismissal

- Restores the v0.21.1 layout and bar behavior exactly.
- Keeps the v0.21.1 media-state and contrast fixes.
- Adds only the Control Center outside-click dismissal fix.
- Clicking outside the Control Center closes it.
- Clicking inside the Control Center does not dismiss it.
- Escape continues to close the Control Center.
- Does NOT include the v0.21.3 compact-bar changes.

# v0.21.1 — Control Center polish + shared media state

- Fixes low-contrast text in energy profile buttons.
- Fixes low-contrast text/icons in the footer action buttons.
- Caps large notification counts at `99+` in the compact DND tile.
- Adds `qs.services.MediaState` as the single MPRIS player-selection source.
- The bar and Control Center now share the same manual/sticky player selection.
- Prevents the Control Center from independently picking a browser/WhatsApp
  MPRIS session while the bar is already tracking another player.
- Keeps duplicate-player suppression and artist fallback logic in one service.
- Shows the player identity in the Control Center media card as a subtle third line.

# v0.21.0 — Control Center

- Adds a compact upstream-Quickshell Control Center anchored below the top-right bar.
- `SUPER+A` now toggles `quickshell:control-center`.
- The far-right bar button opens the Control Center; right-click still opens launcher actions.
- Adds native PipeWire output-volume control.
- Adds brightness control through the existing `brightnessctl` backend.
- Adds Wi-Fi and Bluetooth quick toggles using the existing stable helper backends.
- Adds battery summary and energy profile switching.
- Adds shared idle-inhibit state between the bar and Control Center.
- Adds SwayNC DND and notification-count controls.
- Adds compact MPRIS media controls.
- Shows printer status when a reachable printer exists.
- Adds lock, suspend and a safe handoff to the existing `:` power/action menu.
- Removes the stale duplicate `SUPER+Space` launcher bind from the bundled Hyprland Lua.
- Uses upstream Quickshell APIs only; no Noctalia fork dependency.

# v0.20.47 — optimized CopyQ clipboard backend

- Replaces per-item CopyQ client spawning with one `copyq eval` snapshot.
- Indexes up to 200 history entries in one CopyQ scripting/IPC call.
- Adds persistent `~/.cache/quickshell/clipboard-index.json` for instant display.
- Search/filtering is entirely local after the snapshot.
- Makes image loading lazy: only visible image results fetch image MIME bytes.
- Adds automatic native CopyQ and official CopyQ Flatpak detection.
- Prevents activating stale cached rows until the live CopyQ snapshot arrives.
- Keeps `SUPER+V` / `quickshell:spotlight-clipboard` unchanged.

# v0.20.46 — fast staged clipboard loading

- Fixes the 200-item CopyQ scan blocking recent clipboard items from appearing quickly.
- Loads the 20 most recent CopyQ entries first.
- Starts the full 200-item history scan 450 ms later in the background.
- Replaces the recent list with the full history only when the deep scan finishes.
- Stops re-reading all 200 CopyQ items on every character typed in `#` search mode.
- `SUPER+V` still refreshes the clipboard immediately when opening the direct clipboard view.
- Adds lightweight loading hints while the recent/deep scan is in progress.

# v0.20.45 — deeper clipboard history + direct shortcut

- Expands CopyQ history scanning from 30/50 recent entries to up to 200 items.
- Search in `#` mode now filters across the full loaded 200-item history.
- Keeps the visible result list compact; only matching top rows are rendered at once.
- Stops scanning CopyQ every time the normal launcher opens.
- Clipboard history is loaded only when `#` mode is entered.
- Adds global shortcut `quickshell:spotlight-clipboard`.
- Adds `SUPER+V` to the bundled `hyprland.lua` for direct clipboard access.

# v0.20.44 — larger clipboard image previews

- Makes clipboard image rows taller than normal text rows.
- Expands image thumbnails from the tiny 36x36 icon slot to a 96x56 preview.
- Keeps text/app rows unchanged.
- Uses aspect-fit rendering so screenshots and photos remain recognizable.
- Adds a small “Enter para restaurar” hint for image clipboard entries.

# v0.20.43 — battery energy profiles

- Adds a compact “Perfil de energia” selector to the battery popup.
- Shows Economia, Balanceado and Performance when supported.
- Detects backend automatically:
  - active power-profiles-daemon → `powerprofilesctl`
  - otherwise → firmware `/sys/firmware/acpi/platform_profile`
- When TLP is active, the popup labels the fallback backend as `TLP / platform profile`
  instead of enabling power-profiles-daemon.
- Runtime platform-profile changes request authorization through `pkexec` only when
  direct sysfs access is not permitted.
- Active profile is highlighted; errors are shown inline.
- Existing battery percentage, power draw and remaining-time UI is preserved.

# v0.20.42 — network printer reachability

- Fixes configured network printers appearing as “Pronta” while on another network.
- `lpstat -e` is now treated only as the CUPS destination list, not proof of reachability.
- Resolves each queue device URI with `lpstat -v`.
- Verifies network reachability by protocol:
  - IPP/IPPS → TCP 631/443
  - JetDirect/socket → TCP 9100
  - LPD → TCP 515
  - DNS-SD → `ippfind` when available
- Unreachable network printers occupy zero bar width and disappear from the popup.
- Stale queue jobs for unreachable printers are hidden as well.
- Local USB/file-backed printers remain visible when CUPS reports them.

# v0.20.41 — printer queue document names

- Adds document/job titles to the printer queue using `lpq -P <printer>`.
- Shows the document title as the main row text.
- Keeps printer, owner, and canonical CUPS job id as secondary metadata.
- Falls back to the CUPS job id if `lpq` is unavailable or the title cannot be parsed.
- Cancel continues to use the canonical job id.

# v0.20.40 — Nerd Font coffee icons

- Replaces the custom QML coffee drawing with Nerd Font glyphs.
- Idle inhibited: U+F0176.
- Idle normal: U+F0FAA.
- Keeps the existing idle tooltip text and active orange highlight.

# v0.20.39 — coffee idle icon fix

- Replaces the font-dependent coffee glyph with a QML-drawn cup.
- Idle normal: plain cup with no steam.
- Idle inhibited: orange cup with foam/coffee surface and visible steam.
- Removes the “café frio/com espuma” wording from the tooltip.
- No changes to the printer module or other bar widgets.

# v0.20.38 — fix Printer QML registration

- Registers `Printer.qml` and `PrinterPopup.qml` in `bar/qmldir`.
- Fixes Quickshell startup error: `Printer is not a type`.
- No functional changes to the printer module or coffee idle icon.

# v0.20.37 — Printer + coffee Idle

- Adds a conditional `Printer` module backed by CUPS (`lpstat`).
- The printer icon occupies zero width and is hidden when no CUPS destination is detected.
- Shows queue count in the bar, status color, tooltip, compact popup, queue list, cancel-job action, refresh, and printer settings.
- Polling adapts automatically: 10 s hidden, 5 s detected, 2 s while jobs exist.
- Replaces Idle's eye icon with coffee:
  - cold/simple cup while normal idle behavior is enabled;
  - hot/foamy cup while idle inhibition is active.
- Keeps all existing bar order/layout otherwise unchanged.

# v0.20.36

- Launcher clipboard agora mostra imagens do CopyQ com miniatura e permite recolocá-las no clipboard.
- Itens do clipboard usam `copyq select`, preservando texto e imagens.

# v0.20.35 — read CopyQ's configured clipboard tab

Base: v0.20.34.

- Fixes `#` mode appearing empty when CopyQ's currently selected tab is not
  the clipboard-history tab.
- Resolves the configured CopyQ history tab with:
  `copyq config clipboard_tab`
- Uses explicit tab-scoped commands:
  `copyq tab <clipboard_tab> count`
  `copyq tab <clipboard_tab> read <index>`
- Falls back to CopyQ's standard `&clipboard` tab when no setting is returned.
- Selection/copy-back now uses the same configured tab.
- No changes outside the clipboard backend.

# v0.20.34 — use CopyQ for Spotlight clipboard mode

Base: v0.20.33.

- Replaces the launcher clipboard backend from cliphist to CopyQ.
- Reads CopyQ history with `copyq count` + `copyq read <index>`.
- `#` mode now shows the user's actual CopyQ text history.
- Selecting an item writes it back to the Wayland clipboard with wl-copy,
  falling back to `copyq copy -` if wl-copy is unavailable.
- Binary/image-only CopyQ entries are skipped in the current text list.
- Updates the unavailable message and launcher documentation accordingly.
- No changes to bar layout, launcher search, actions, emoji, or Kill App.

# v0.20.33 — safer spacing around edge buttons

Base: v0.20.32.

- Increases the reserved inset beside both edge buttons from 38 px to 48 px.
- Leaves roughly 14 px of clear separation between:
  - Launcher button and the first workspace control.
  - Actions button and the right-side notification/status cluster.
- Keeps the physical edge buttons themselves at 29x29.
- Updates the launcher tooltip to `Launcher · Super+D`.
- No other bar layout or launcher behavior changes.

# v0.20.32 — edge-button UX polish

Base: v0.20.31.

- Adds themed tooltips to the two edge buttons:
  - Launcher · Super+Space
  - Ações · Super+A
- Adds an active state while the corresponding Spotlight mode is open.
- Adds a subtle 90 ms background-color transition for hover/active feedback.
- Extends ToolTipBubble with `openLeft` so the right-edge tooltip opens inward
  instead of overflowing the screen edge.
- Keeps the corrected absolute edge layout from v0.20.31.
- No changes to bar module order or launcher behavior.

# v0.20.31 — fix edge buttons and direct launcher control

Base: v0.20.30.

- Fixes the bar layout regression caused by putting launcher/actions inside
  the left/right Rows.
- Launcher and Actions are now absolutely anchored to the two physical ends
  of the panel.
- Existing left/right module groups are preserved and only reserve 33 px for
  the edge controls.
- Bar buttons no longer shell out to `hyprctl dispatch global`.
- `shell.qml` passes the live Spotlight instance into each Bar.
- Launcher button calls `toggleLauncher()` directly.
- Actions button calls `openWithPrefix(":")` directly.
- `SUPER+A` global Actions binding remains available.
- No changes to Weather, Clock, Media, Network, Bluetooth, Audio, OSD or updater.

# v0.20.30 — launcher/actions edge buttons

Base: v0.20.29.

- Adds a compact Spotlight launcher button at the far left of the bar.
- Adds a compact Actions button at the far right of the bar.
- Launcher button dispatches `quickshell:spotlight`.
- Actions button dispatches `quickshell:spotlight-actions` and opens `:` mode.
- Registers new global shortcut `quickshell:spotlight-actions`.
- Adds `SUPER+A` as the Hyprland keybind for Actions.
- Keeps `SUPER+Space` and `SUPER+D` for the normal launcher.
- No changes to the center cluster or existing bar modules.

# v0.20.29 — rofimoji/Arch emoji data detection fix

Base: v0.20.28.

- Fixes Emoji mode incorrectly reporting that rofimoji is not installed.
- Current Arch rofimoji installs its Python package as `picker`, not `rofimoji`.
- Detects bundled emoji CSV files under:
  `/usr/lib/python3.x/site-packages/picker/data/`
- Also supports XDG user data and historical/custom rofimoji data paths.
- Loads `emojis_*.csv` plus user additions under `data/additional/`.
- No Wofi dependency is reintroduced.
- No changes outside launcher emoji discovery.

# v0.20.28 — replace Wofi workflows with Spotlight

Base: v0.20.27.

- Adds `;` native emoji mode backed by installed rofimoji data.
- Adds `!` native Kill App mode backed by `hyprctl clients -j`.
- Registers `quickshell:spotlight-emoji` and `quickshell:spotlight-kill`.
- Adds emoji insertion helper using wl-copy + wtype when available.
- Adds kill helper preserving the previous kill-by-PID semantics.
- Includes a revised hyprland.lua with every Wofi reference removed.
- Super+D opens Spotlight.
- Super+Shift+E opens Spotlight in Emoji mode.
- Super+K opens Spotlight in Kill App mode.
- Existing Super+Space Spotlight binding remains unchanged.
- No changes to Weather, Clock, updater, media, notifications, Network,
  Bluetooth, Audio or OSD.

# v0.20.27 — Spotlight feature-complete pass

Base: v0.20.26.

- Adds `@` file/folder search with `fd` and fallback search.
- Adds `#` clipboard-history mode using cliphist/wl-copy.
- Adds `:` system actions: lock, suspend, logout, reboot, poweroff.
- Adds persisted app-use ranking in XDG state.
- Improves app matching with fuzzy subsequence scoring.
- Empty search now prioritizes frequently used apps.
- Calculator supports Ctrl+C copy via wl-copy.
- Keeps `> command` terminal execution from v0.20.26.
- Adds compact mode indicators and footer hints.
- No changes to Weather, Clock, updater, media, notifications, Network,
  Bluetooth, Audio or OSD.

# v0.20.26 — visible shell-command execution from Spotlight

Base: v0.20.25.

- Fixes Spotlight `> command` mode appearing to do nothing.
- Commands now open in a visible terminal instead of running detached with no TTY.
- Reuses the shell's terminal preference order:
  Ghostty -> Foot -> Kitty -> Alacritty -> WezTerm.
- Terminal remains open after the command finishes and shows its exit status.
- Adds `scripts/run-launcher-command.sh`.
- No changes to app launching, calculator, Weather, Clock, updater, media,
  notifications, Network, Bluetooth, Audio or OSD.

# v0.20.25 — force Spotlight magnifier theme blue

Base: v0.20.24.

- Forces the QML-drawn magnifier ring and handle to the theme blue `#89b4fa`.
- Removes any remaining scope/property-resolution dependency for the search icon.
- No other launcher or shell changes.

# v0.20.24 — deterministic Spotlight search icon

Base: v0.20.23.

- Replaces the Nerd Font magnifying-glass glyph with a small QML-drawn icon.
- The magnifying glass now uses `root.launcherBlue` directly for both ring and handle.
- Avoids font fallback/rendering that caused the icon to appear black.
- Command/calculator mode icons remain font-based and unchanged.
- No other launcher or shell changes.

# v0.20.23 — Spotlight search icon color fix

Base: v0.20.22.

- Fixes the magnifying-glass icon using `palette.blue` from the outer scope.
- Search icon now binds explicitly to `root.launcherBlue`.
- Command/calculator icon colors remain `launcherGreen` / `launcherPink`.
- No other launcher or shell changes.

# v0.20.22 — Spotlight text scope and contrast fix

Base: v0.20.21.

- Adds `pragma ComponentBehavior: Bound` to Spotlight.qml.
- Exposes the shell palette through explicit root-level launcher color properties.
- ListView delegate text now binds to `root.launcherForeground`,
  `root.launcherSecondary`, and `root.launcherMuted` instead of relying on an
  outer `palette` id from delegate scope.
- App titles are explicitly full-opacity foreground text.
- App subtitles are explicitly off-white at 76% opacity.
- Desktop-entry title/subtitle and placeholder text are forced to `Text.PlainText`.
- Keeps the Clock/Weather popup palette hierarchy and layout from v0.20.21.
- No behavioral changes to launcher search, commands, calculator or shortcut.
- No changes outside Spotlight.

# v0.20.21 — Spotlight palette consistency pass

Base: v0.20.20.

- Makes Spotlight use the same palette hierarchy as Clock/Weather popups.
- Main surface now uses `theme.background`.
- Border uses the same restrained `surfaceHover` alpha as other popups.
- Search text/title stays `foreground`.
- Secondary/result text uses `offWhite` with controlled opacity instead of dark grey.
- Selected row now uses the same surface-style highlight language as the shell.
- App icon tiles use the same subdued surface treatment as popup cards.
- Footer hints use readable theme grey instead of washed-out text.
- Divider opacity aligned with other popup section dividers.
- Background dim reduced so the launcher no longer looks washed out.
- No launcher behavior changes.
- No changes to Weather, Clock, updater, media, notifications, Network,
  Bluetooth, Audio or OSD.

# v0.20.20 — Spotlight visual polish

Base: v0.20.19.

- Launcher width reduced from 590px to 560px.
- Results reduced from 58px to 52px rows.
- Maximum visible results reduced from 8 to 6.
- Launcher height remains fully content-driven.
- Search header reduced slightly for a more Spotlight-like proportion.
- Outer glow is thinner and more subtle.
- Card radius reduced from 22px to 20px.
- Search icon and placeholder text are slightly smaller.
- Secondary text contrast improved.
- Footer shortcuts increased to 10px and made more readable.
- Selected result highlight softened.
- No launcher behavior changes.
- No changes to Weather, Clock, updater, media, notifications, Network,
  Bluetooth, Audio or OSD.

# v0.20.19 — Spotlight IconImage import fix

Base: v0.20.18.

- Adds `import Quickshell.Widgets` to `launcher/Spotlight.qml`.
- Fixes startup error: `IconImage is not a type`.
- No visual or behavioral changes to the launcher.
- No changes to Weather, Clock, updater, media, notifications, Network,
  Bluetooth, Audio or OSD.

# v0.20.18 — Apple-like native Spotlight launcher

Base: v0.20.17.

- Adds a native Quickshell Spotlight-style launcher.
- 590px centered floating surface with soft dim background.
- Uses DesktopEntries directly; no rofi/wofi/walker dependency.
- Weighted app search across name, generic name, keywords, categories and comment.
- Arrow navigation, Enter launch and Escape close.
- Mouse selection/activation.
- `> command` mode.
- `= arithmetic` mode.
- Registers Hyprland global shortcut `quickshell:spotlight`.
- Uses the existing Catppuccin theme, fonts and restrained rounded visual language.
- No changes to Weather, Clock, updater, player selector, notifications, Network,
  Bluetooth, Audio or OSD.

# v0.20.17 — compact Quickshell-style tooltips

Base: v0.20.16.

- Fixes tooltip line breaks by replacing `Text.RichText` with `Text.PlainText`.
- Tooltip max width reduced from 440px to 320px.
- Uses the shell surface color instead of the full popup background.
- Radius reduced to 7px with a softer 1px border.
- Typography reduced to 11px with compact line spacing.
- Existing tooltip strings are untouched, so Weather/Network/Bluetooth hints now
  naturally render their existing `\n` as separate lines.
- No updater, media, player selector, notification, Weather, Network or Bluetooth
  behavior changes.
- Script executable bits are preserved.

# v0.20.16 — fault-isolated update center

Base: v0.20.15.

- Clock updates area now opens a compact 326px update center.
- Separates official Arch repositories, AUR, Flatpak and Homebrew.
- Adds AUR update discovery with a 15s query timeout so a slow AUR endpoint cannot stall the shell.
- Right-click on the Clock update area still toggles the compact R/A/F/B breakdown.
- Each backend can be updated independently.
- “Atualizar tudo” runs repo -> AUR -> Flatpak -> Brew as isolated stages.
- An AUR failure/timeout no longer prevents Flatpak or Homebrew stages from running.
- Real package updates run in a terminal; Quickshell only presents state and launches the runner.
- Adds package-list expansion inside the update center.
- All shell scripts are explicitly executable in the release.
- No changes to Media, player selection, Weather, notifications, Network, Bluetooth, Audio, fan or OSD.

# v0.20.15 — dot separator between Workspaces and Media

Base: v0.20.14.

- Replaces the 1px vertical separator between Workspaces and Media with the
  same subtle middle-dot treatment already used in the center cluster.
- Uses theme grey at 75% opacity and 12px typography for visual consistency.
- No other bar, media, Clock, Weather, notification, fan, update, Network,
  Bluetooth, Audio or OSD changes.

# v0.20.14 — clean workspace/media separator

Base: v0.20.13.

- Replaces the Unicode `│` glyph between Workspaces and Media with a real
  1px x 13px Rectangle.
- Fixes the uneven/tall vertical line caused by font metrics and glyph rendering.
- Separator is vertically centered and uses the same subdued grey treatment
  already used elsewhere in the shell.
- No other bar, media, Clock, Weather, notification, fan, update, Network,
  Bluetooth, Audio or OSD changes.

# v0.20.13 — left-side player selector anchoring

Base: v0.20.12.

- Corrects PlayerSelector placement for the left side of the bar.
- Uses the mirrored anchor/gravity relationship of the working right-side popups:
  target bottom-left -> popup opens toward the bottom-right.
- Fixes the v0.20.12 behavior where the menu was clamped to the screen's top-left corner.
- No notification changes.
- No media state/sticky-player changes.
- No Weather, Clock layout, fan, updates, Network, Bluetooth, Audio or OSD changes.

# v0.20.12 — player selector popup placement fix

Base: v0.20.10 stable.

- Fixes PlayerSelector popup gravity.
- The selector now opens downward from its target instead of expanding upward/off-screen.
- Applies to both the Media selector in the top bar and the shared selector in the Clock popup.
- No media state/sticky-player changes.
- No notification changes; SwayNC remains untouched.
- No Weather, Clock layout, fan, updates, Network, Bluetooth, Audio or OSD changes.

# v0.20.10 — sticky media player

Base: v0.20.9.

## Media selection behavior
- The current MPRIS player is now sticky.
- Pausing Spotify no longer causes the Now Playing state to jump to Firefox.
- Manual player selection still takes precedence.
- The selected/current player remains active while it still exists in MPRIS.
- Automatic fallback happens only when the current player disappears.
- If no sticky/current player exists, a playing player is preferred, then the first available player.

Because the Clock popup shares Media.qml state, the fix applies consistently to both the bar and Clock popup.

No visual changes.

# v0.20.9 — shared Now Playing selector

Base: v0.20.8.

## Shared media state
The Clock popup now reuses the exact Media.qml instance from the bar.

- `Bar.qml` passes `mediaWidget` to Clock as `mediaController`.
- `Clock.qml` forwards that controller to CalendarPopup.
- CalendarPopup reads the same `players`, `player`, and `selectedPlayer`.
- Selecting a player in the Clock popup writes directly to
  `mediaWidget.selectedPlayer`.
- A player change made from the bar is immediately reflected in the Clock popup.
- A player change made from the Clock popup is immediately reflected in the bar.

## UI
- Adds a small player selector to the media section inside CalendarPopup.
- Uses the existing `PlayerSelector.qml`; no duplicate selector logic.
- Existing artwork/title/artist/progress/controls continue using the shared
  `mediaWidget.player`.

## Intentionally unchanged
- MediaPopup remains intact.
- MPRIS discovery/deduplication remains entirely in Media.qml.
- Bar Now Playing appearance/hover controls remain unchanged.
- Weather, Network, Bluetooth, Audio, OSD, fan and update logic are untouched.

# v0.20.8 — footer divider alignment

Base: v0.20.7.

- Rebuilds the Clock popup footer using anchored left/right halves.
- Vertical divider is now anchored exactly to the horizontal center.
- CPU/Fan and Updates regions use the divider as their shared boundary.
- No typography, fan logic, update logic, popup size, or Weather changes.

# v0.20.7 — fan reader syntax fix

Base: v0.20.6.

- Fixes QML parse failure in CalendarPopup.
- Removes embedded multiline shell/template literal from QML.
- Moves fan detection to `scripts/fan-speed.sh`.
- CalendarPopup now executes the helper directly.
- Fan behavior remains the same: ThinkPad first, generic hwmon fallback, 5s refresh.
- No visual changes.

# v0.20.6 — fan speed in Clock popup

Base: v0.20.5.

- Adds live fan RPM telemetry to CalendarPopup.
- Prefers ThinkPad hwmon (`thinkpad` / `thinkpad_hwmon`) fan inputs.
- Falls back to the first readable generic `fan*_input`.
- Fan state refreshes every 5 seconds while the popup is open.
- CPU and fan share the existing left footer area, so popup geometry stays unchanged.
- No Weather, Network, Bluetooth, Audio, OSD, or bar layout changes.

# v0.20.5 — remove bottom chin

Base: v0.20.4.

- CalendarPopup height reduced from 374 px to 358 px.
- Removes the ~16 px empty area below the CPU/updates footer.
- No typography, spacing, media, calendar, update logic, or Weather behavior changed.

# v0.20.4 — tighter popups + cleaner Weather

Base: v0.20.3.

## Weather
- removed the redundant `Gerenciar cidades` footer;
- city management remains available from the city selector and `+` button at the top;
- reduced outer margins and popup height;
- increased primary weather text slightly.

## Clock
- reduced outer margins and total popup height;
- tightened vertical spacing between calendar, media and footer;
- increased the small calendar/media/footer typography;
- kept the same floating visual style and independent PopupWindow architecture.

No backend behavior changed.

# v0.20.3 — popup typography pass

Base: v0.20.2.

## What changed
- increased font sizes across the Clock popup (calendar, music and footer);
- increased font sizes across the Weather popup (city header, current conditions, hourly strip, daily list and footer row);
- slightly enlarged both popup canvases so the bigger typography still breathes;
- preserved the same layout language and floating visual style.

No backend logic changed in this release.

# v0.20.2 — update counts + final popup polish

Base: v0.20.1.

## Update count fix
- `checkupdates`, `flatpak` and `brew` are now discovered robustly even when
  Quickshell runs from a systemd user service with a reduced PATH.
- Common absolute executable locations are used as fallback.
- CalendarPopup refreshes all three update sources whenever it opens.
- Added `scripts/debug-updates.sh` for quick backend diagnosis.

## Clock popup
- update footer simplified to `N updates` / `Atualizado`;
- click toggles compact `A x · F y · B z` breakdown;
- no more truncated `Sistema atualiz...`;
- artwork slightly larger;
- media/title grouping tightened;
- calendar slightly shorter;
- popup slightly shorter.

## Weather popup
- slightly shorter overall;
- daily forecast labels made a little easier to read.

Weather and Clock remain independent PopupWindow instances.
No unrelated modules changed.

# v0.20.1 — reference fidelity pass

Base: v0.20.0.

## WeatherPopup
- reduz altura total e remove espaço vazio inferior;
- aumenta levemente a largura;
- compacta condição atual e previsão horária;
- mantém 6 horários e 5 dias;
- aproxima proporções da referência visual.

## CalendarPopup
- reduz altura total;
- calendário mais compacto;
- mídia ocupa menos espaço morto;
- artwork e controles mais equilibrados;
- rodapé CPU/Updates mais curto;
- mantém popup independente.

Nenhuma arquitetura foi alterada.
Weather e Clock continuam sendo dois PopupWindow independentes e podem abrir separadamente.

# v0.20.0 — floating dual-popup redesign

Base: user-provided v0.19.1 package.

## Independent popups
Weather and Clock remain two real, independent `PopupWindow` instances.

- Weather opens only WeatherPopup.
- Clock opens only CalendarPopup.
- Both may remain open at the same time.
- No shared PopupHost was introduced.

## WeatherPopup
Redesigned after the supplied visual reference:

- narrower/taller floating panel;
- city selector + `+` quick-add control;
- large current condition;
- high/low temperatures;
- six upcoming hourly points;
- five-day compact forecast list;
- `Gerenciar cidades` footer;
- city management/search happens inside the same independent WeatherPopup.

The v0.19.1 multi-city backend and persistence remain intact.

## CalendarPopup
Redesigned after the supplied visual reference:

- compact monthly calendar at the top;
- media block with artwork, progress and controls;
- CPU summary at the bottom;
- compact update summary with expandable Arch / Flatpak / Brew counts.

## Bar integration
- Weather gets a subtle active state while its popup is open.
- Clock gets a subtle hover/open surface.
- Popups remain detached from the bar with a small gap.
- No physical bar/popup fusion.

## Weather backend
- forecast extended from 3 to 5 days;
- output now includes the next six hourly forecast points.

## Intentionally untouched
- Audio
- Network
- Bluetooth
- Battery
- Tray
- Notifications
- OSD
- MediaPopup
- Network secret-agent architecture

# v0.19.1 — estabilização do Weather multi-cidade

Base: v0.19.0.

## Correções
- Não mostra previsão em cache de outra cidade após trocar a seleção.
- Scroll sobre o Weather usa o `MouseArea` já existente da pill.
- Lista de cidades salvas agora é rolável.
- Seletor e busca recebem altura suficiente para não cortar a previsão.
- Nenhuma mudança na aparência normal da barra.

## Testes realizados
- compilação dos scripts Python;
- listagem do estado;
- adicionar duas cidades;
- selecionar cidade;
- alternar próxima/anterior;
- remover cidade selecionada;
- persistência do JSON de estado.

O ambiente de geração não possui o executável Quickshell, portanto a validação
final do carregamento QML continua sendo feita no sistema do usuário.

# v0.19.0 — cidades salvas no Weather

Base: v0.18.0.

## Weather
O módulo passa a suportar várias cidades persistentes.

### Barra
- continua exibindo apenas ícone + temperatura;
- scroll no módulo troca entre cidades;
- tooltip informa a cidade ativa.

### Popup
Novo seletor de cidade no topo:
- localização automática;
- cidades salvas;
- indicador `✓` na cidade ativa;
- remoção individual;
- `+ Adicionar cidade`.

### Busca
`Adicionar cidade` usa o geocoding do Open-Meteo:
- busca pelo nome;
- mostra cidade + região + país;
- clicar em um resultado salva e seleciona imediatamente a cidade.

### Persistência
Estado salvo em:

`~/.local/state/quickshell/weather.json`

Exemplo:

```json
{
  "selected": "cidade-exemplo-...",
  "cities": [
    {
      "id": "...",
      "name": "Cidade Exemplo",
      "region": "Região Exemplo",
      "country": "Brasil",
      "latitude": 0.0,
      "longitude": 0.0
    }
  ]
}
```

### Backend
- `scripts/weather-cities.py`: lista, busca, adiciona, seleciona, remove e
  alterna cidades.
- `scripts/waybar-wttr.py`: usa a cidade selecionada antes de consultar o
  Open-Meteo.
- localização por IP continua existindo como opção `Localização automática`.

Nenhum outro módulo da shell foi alterado.

# v0.18.0 — simplificação visual

Base: v0.17.2.

## Barra
- Remove a pill visível de temperatura da CPU.
- O sensor continua ativo em segundo plano para alimentar o popup central.
- Move Weather do lado direito para o centro, ao lado do relógio.
- Weather central usa apresentação `plain`, sem pill permanente forte.
- Demais módulos do lado direito continuam intactos.

## Popup central
Agora só existem dois cards internos reais:
1. calendário;
2. música.

Data/hora e CPU ficam diretamente no fundo do popup, sem cards extras.

### Cabeçalho
- hora grande;
- data completa;
- CPU pequena no canto direito;
- temperatura não compete mais visualmente com o relógio.

### Música
- artwork ligeiramente maior;
- título, artista e controles;
- remove o rodapé com nome do player.

### Updates
- remove o card/faixa de atualizações;
- vira apenas uma linha discreta;
- mostra total + Arch + Flatpak + Brew quando existem updates;
- com zero updates mostra somente `Sistema atualizado`;
- mantém clique nas origens para abrir atualização;
- mantém refresh manual.

## Filosofia visual
A barra fica mais "glanceable" e o popup central deixa de parecer um
dashboard composto por cards aninhados.

# v0.17.2 — correção de carregamento

- Corrige `CalendarPopup.qml`: adiciona `import qs.components`.
- Isso torna `CommandJson` disponível para o resumo de updates.
- Nenhuma alteração visual em relação à v0.17.1.

# v0.17.1 — updates no popup central

Base: v0.17.0.

## Barra
- Remove o módulo `Updates` da barra.
- Arch / Flatpak / Brew deixam de ocupar pills permanentes.

## Popup central
Adiciona um rodapé compacto de atualizações:

- total de updates;
- Arch + quantidade;
- Flatpak + quantidade;
- Brew + quantidade;
- botão de refresh.

Não mostra lista de pacotes.

### Interação
- clicar em `Arch` abre `pacman -Syu` no Ghostty;
- clicar em `Flatpak` abre `flatpak update`;
- clicar em `Brew` abre `brew upgrade`;
- botão de refresh atualiza as três contagens.

## Visual
O resumo usa o mesmo card discreto dos outros blocos do popup central e ocupa
apenas uma faixa curta no rodapé.

Nenhum módulo de rede, Bluetooth, áudio, weather, bateria ou notificações foi alterado.
