# Architecture

## Overview

The shell is organized around Quickshell QML components and small Python/shell helpers.
The mounted component relationships are shown in [`shell-uml.md`](shell-uml.md).

Main areas:

- `shell.qml`
- `bar/`
- `components/`
- `scripts/`
- optional config/state files

## Bar composition

`bar/Bar.qml` is intentionally explicit.

Do not dynamically instantiate the entire bar via `Repeater`/`Loader` without explicit approval.

The explicit layout protects:
- spacing;
- vertical alignment;
- center positioning;
- hover behavior;
- predictable module widths.

## Component philosophy

Spotlight keeps its providers local to `launcher/`:
`SpotlightSearchController.qml` routes app, window and command searches,
`SpotlightQueryRouter.qml` maps each query mode to its provider and normalizes
results, and `SpotlightResult.qml` gives each result a common contract.
`SpotlightRanking.qml` combines apps, windows and actions for nonempty root
queries; the empty root query still lists apps. Legacy result fields remain
available to the current activation and preview paths.
`SpotlightModeLogic.js` owns query-mode classification and action-prefix
metadata; `SpotlightActionLogic.js` provides pure grouping, navigation and
action-resolution rules. `SpotlightActionExecutor.qml` performs the resolved
operations and reports launcher-specific work such as closing, navigating,
session confirmation and usage ranking through signals, leaving input focus
and ranking process ownership with `Spotlight.qml`.

A module generally consists of:
- compact bar item;
- optional popup;
- optional helper script;
- state refresh logic.

Keep module boundaries understandable and local.

## QML Code Quality

Use these practices when adding or refactoring QML. They follow Qt's
[QML coding conventions](https://doc.qt.io/qt-6/qml-codingconventions.html)
and the stability rules in `AGENTS.md`:

- Give components explicit inputs with `required property` declarations and
  communicate user actions through signals. Do not reach into another QML
  component's `id` or depend on an implicit parent context.
- Qualify access to the current component through its root `id` so bindings
  show where state comes from.
- Extract a shared component when multiple surfaces implement the same visual
  and interaction contract. Pass variations such as size and theme through
  properties; keep one-off layout local.
- Popup headers use `components/PopupHeader.qml`; list surface, hover, and
  selected-state treatment use `components/PopupListRow.qml`. Their slots keep
  domain content and actions in the owning popup. Use `ScrollableList` for
  vertical lists that need the shared conventional wheel handler. It supports
  both Column-backed content and virtualized `model`/`delegate` rows; its
  footer, scrollbar, empty state, and search field are optional. Use
  `SettingToggleRow` when a labeled setting is controlled by a switch. Keep
  specialized grids, notification cards, and protocol delegates local.
- Keep presentation in UI components and system interaction, parsing, and
  shared lifecycle state in existing services or helpers. Add a service only
  when it meets the criteria in `AGENTS.md`.
- Keep functions focused and signal handlers readable. Move repeated or
  multi-step logic into named functions instead of compressing it into
  bindings or one-line handlers.
- Isolate tests from the live desktop and filesystem. Use temporary
  directories and mock process boundaries so tests work without writing to
  `/run`, invoking a compositor, or depending on user services.
- Preserve the documented UI and behavior contracts. Prefer focused changes
  with regression checks over broad cleanup of stable surfaces.
- `scripts/validate.sh` runs `qmllint` on every QML file and supplies each
  project `qmldir`, so local module imports are checked with the project
  structure available. QML files with nested components use
  `pragma ComponentBehavior: Bound` where outer IDs are referenced. In
  addition to syntax and type errors, validation requires zero lint warnings
  and treats 13 quality checks (such as deprecated APIs, duplicate imports,
  stale reads, `eval`, and unreachable code) as errors. Delegate model values
  and references to outer component state are explicitly qualified.
  Suppressions are limited to known gaps in the installed Qt/Quickshell
  metadata, including `PanelWindow`, popup anchor enums, `QMargins`, and a few
  plugin types; each suppression is scoped to the affected declaration.
- Put notification content normalization and filtering in
  `services/NotificationContent.js`; its QML tests exercise that same module
  through `qmltestrunner` rather than maintaining a Python copy of the rules.
- Keep color conversion and semantic palette math in `scripts/theme_colors.py`;
  theme adapters and persistence remain in the CLI manager.
- Keep built-in theme data and terminal theme-name mappings in
  `scripts/theme_catalog.py`. `scripts/theme-manager.py` owns runtime state,
  wallpaper-derived palettes, persistence, and adapter synchronization.
- Keep literal QML palette values in `Theme.qml` and `services/ThemeState.qml`;
  reusable components must receive theme tokens. `scripts/validate.sh` enforces
  this boundary.

## Shared UI behavior

- `components/WheelKinetic.qml` owns the common direction and motion for wheel
  input on scrollable `Flickable` and `ListView` surfaces.
- `components/ScrollBar.qml` provides the shared vertical thumb, track click,
  drag, and wheel forwarding for long lists.
- `components/ScrollableList.qml` supports vertical Column-backed content and
  virtualized model/delegate lists. It composes either view with `WheelKinetic`
  and optional scrollbar, empty state, footer, and search-field slots.
  Horizontal galleries and nested scrolling keep the lower-level primitives
  directly because their interaction contracts differ.
- `components/ActionFeedback.qml` shares busy/error state and optional timed
  dismissal while each domain keeps ownership of its action process and text.
- Popup feedback remains contextual rather than adding a duplicate global
  banner: Network and Bluetooth show per-target state, Phone shows per-device
  state, Printer uses `ActionFeedback`, Screen Recording shows its operation
  result, and update backends expose their own busy/error results. Direct
  control tiles report state through their active state or OSD. When adding an
  action, preserve that domain signal and render helper failures visibly.
- `components/PopupIconButton.qml` shares compact popup icon actions;
  `PopupSettingsButton.qml` specializes it as the settings gear. Dimensions
  and color tokens remain configurable for the printer, audio, and Quick
  Settings variants.
- `components/PopupHeader.qml` shares the icon, title, subtitle, and trailing
  action layout for standard and compact headers in Audio, Brightness,
  Bluetooth, Network, Phone, Printer, and System Update popups.
  Each popup keeps its own status text, icon color, and action controls. Quick
  Settings uses the same header for its section labels, live notification
  count, and action groups. Hero rows (Battery), media controls, and toggles
  remain local content because they are not popup title headers.
- `components/PopupListRow.qml` shares the active, hover, border, and clipping
  treatment of Wi-Fi and VPN rows in `NetworkPopup.qml`, Bluetooth device rows,
  and printer/print-job rows. Domain contents and actions stay in each delegate
  because connected, discovery, printing, and network actions differ. Its
  default content slot is hidden when the standard icon/title layout is active;
  pointer handlers for those rows must use the named `interactionHandlers`
  slot so the handler remains attached to a visible item. This applies to
  `TapHandler` and `MouseArea` children alike.
  Gotcha: ids defined inside the `trailing:` Component are invisible outside
  it, so a row-level `interactionHandlers` tap cannot hit-test against a
  trailing item id. Expose geometry through delegate properties (e.g. a key
  action size/flag on the row) instead of referencing the trailing id.
  Toast cards, Spotlight results/actions, application menu entries, and wallpaper
  previews retain their own surfaces because they carry different lifecycle,
  selection, animation, or content behavior.
- `components/EmptyState.qml` shares the icon, title, optional subtitle, and
  alignment for empty views in notifications, network, Bluetooth, updates,
  printing, and Spotlight. Each surface supplies its original copy and tokens.
- `components/SearchField.qml` shares the TextInput base and placeholder
  treatment across Spotlight, phone sharing, weather lookup, and Wi-Fi
  password entry. Network and Bluetooth list filters use its optional
  debounced query signal; each caller retains its own focus and action logic.
- `components/MaterialSwitch.qml` provides the shared accessible switch for
  Bluetooth, Wi-Fi, and VPN controls; `Theme.qml` supplies its interaction
  state layers and palette roles.
- `components/SettingToggleRow.qml` standardizes the labeled switch row and
  is used by screen recording and VPN controls; dashboard toggles remain
  `QuickTile` actions with a different layout and interaction contract.
- `qs.controlcenter.SliderRow` shares pointer dragging, normalized track fill,
  hover thumb, wheel stepping, and disabled-state behavior in Quick Settings,
  AudioPopup (including application streams), and the brightness popup.
  Per-stream mute and routing remain in the audio domain delegates.
- `components/MediaSeekBar.qml` shares progress rendering, seeking, elapsed and
  total-time formatting, and playback-progress animation between the compact
  Quick Settings player and the full media popup. Callers retain their own
  layout density and translate the normalized seek request to MPRIS position.
- `components/CommandJson.qml` owns polling, process lifetime, and JSON decoding
  for simple status helpers. Use a local `Process` where stdin, output parsing,
  or action lifecycle needs domain-specific handling.
- `services/CommandResult.js` normalizes versioned helper envelopes and legacy
  flat helper JSON into `{ok, version, data, error}`. Error-only legacy payloads
  also normalize as failures. `CommandJson.result` exposes that stable form;
  `payload` remains a compatibility view of `data` while consumers migrate by
  domain.
- The battery popup consumes normalized `result.data` from its charge limit,
  power-profile, and CPU boost helpers. Its local action processes use the
  shared result decoder while retaining their own busy and refresh lifecycle.
- Network, Bluetooth, KDE Connect, and printer actions use the same result
  decoder for success and error feedback without moving action lifecycle into a
  generic component.
- Spotlight launcher-data processes use the shared decoder for app usage,
  file/emoji/window queries, and clipboard snapshots/actions. Ranking, query
  routing, selection, and keyboard behavior remain owned by their current
  components; compositor IPC streams keep their protocol-specific parsers.
- Direct JSON parsing in QML is limited to Mango's line-based compositor IPC
  and the incremental speed-test event stream. Other
  helper responses use `CommandResult.js` or `CommandJson`.
- Brightness status and write helpers return the versioned JSON contract; QML
  owns only optimistic display state and presents helper failures in the open
  brightness popup. The OSD discovers the backlight device through the status
  helper, then follows the device's sysfs files for live updates.
- The shared update counts and backend detail objects are read from each
  helper's normalized `CommandJson.result.data`.
- The dashboard's game detector exposes its status through
  `CommandJson.result.data`; helper failure leaves its status unavailable.
- Theme-manager processes use `CommandResult.js`; failures are logged and
  surfaced in the Settings header instead of being discarded by local JSON
  parse catches.
- `services/HolidayLogic.js` calculates recurring national holidays and Easter-
  dependent Good Friday locally. `CalendarCard.qml` passes the active weather
  region to add applicable state holidays without a runtime network request.
- `bar/SystemMonitor.qml` consumes the normalized procfs snapshot from
  `scripts/system-usage.py` every five seconds. CPU usage is calculated from
  successive counter samples; memory usage is available from each sample.
- `services/ProcessLifecycle.js` distinguishes a completed process from one
  that failed before starting. Weather refresh and clipboard supervision use
  this shared transition helper with `Process.runningChanged`, avoiding the
  unresolved `QProcess::ExitStatus` metadata in `onExited`.
- `services/MotionState.qml` exposes the shared motion policy through
  `Theme.qml`. Quickshell handles visual transitions on every compositor;
  Hyprland continues to animate its own windows and workspaces independently.

## Python helpers

Python is used when shell commands become awkward or when structured JSON is useful.

Common pattern:
- QML starts a process;
- helper returns JSON;
- QML displays structured state.

Prefer small single-purpose helpers over one huge daemon.

Standalone scripts share `scripts/command_utils.py` for bounded subprocess
execution while preserving per-domain output and error contracts, and
`scripts/network_utils.py` for the IPv4 DNS workaround used by weather and
speed-test requests. The Arch, AUR, Flatpak, and Brew update checks serialize
their common result envelope through `scripts/update_status_json.py`. Test
suites share `tests/helpers.py` for loading hyphenated script filenames and
reading fixtures.

## State

Mutable runtime state should go under XDG state/cache locations.

Examples:
- weather city selection:
  `~/.local/state/quickshell/weather.json`
- weather cache:
  XDG cache path

Do not store frequently changing state in tracked config files unless there is a strong reason.

## Process strategy

Subprocesses are acceptable, but:
- avoid excessive polling;
- avoid background scans unless UI is open or explicitly refreshed;
- avoid secrets in argv;
- prefer event/file observation when possible.

## Popup philosophy

Popups should:
- be cohesive;
- avoid dead space;
- avoid redundant cards;
- use visual grouping only where it improves comprehension;
- preserve the shell's compact tonal hierarchy through the active theme;
  Catppuccin Mocha is the historical baseline, not a fixed palette requirement.

See [design guidelines](design-guidelines.md) for the visual contract and
[design plan](design-plan.md) for the current consistency backlog.

## Error strategy

Prefer contextual inline errors:
- per-row connection state for network;
- lightweight activity text;
- generic OSD only for cross-cutting feedback.

Avoid large technical error dumps in normal UI.

## Compositor Boundary & Agnosticism

The shell UI is decoupled from compositor-specific CLI commands and syntax:
- General UI components use Quickshell APIs or project helpers for compositor actions. `bar/Submap.qml` obtains the Hyprland-only modal submap through the compositor dispatcher.
- All compositor dispatch actions (such as switching workspaces or focusing windows) are routed through `scripts/compositor-dispatch.sh`.
- The dispatcher encapsulates multi-format support (e.g. Hyprland Lua dispatch vs classic hyprlang dispatch) without leaking syntax into QML.
- Workspace display and activation prefer the native Hyprland workspace API on Hyprland and Mango's `mmsg` adapter on Mango. labwc uses Quickshell's generic `WindowManager` `ext-workspace-v1` API; native backends fall back to it when available. The bar scopes generic windowsets through `screenProjection(screen)`.
- Mango's `mmsg` watcher supplies tag state and focused-output data; activation stays behind `scripts/compositor-dispatch.sh`. The Mango IPC signature is imported into the systemd user manager by the session startup helper.
- Spotlight uses Hyprland client metadata on Hyprland and Quickshell's `ToplevelManager` foreign-toplevel protocol elsewhere for the `~` window list and actions. The `!` process-kill mode uses Hyprland PID data because the protocol does not expose PIDs.
- Click-opened detail popups use Quickshell `PopupWindow` focus grabbing
  (`grabFocus: true`). Check outside-click dismissal on each supported compositor;
  hover previews, Spotlight subpanels, SystemInfo and desktop windows have distinct
  focus/dismissal contracts described in the design guide.
- Compositor agnosticism is continuously guarded by automated checks in `scripts/validate.sh`.

## Theme System & Multi-Theme Architecture

The shell supports dynamic, live-reloading themes across all surfaces without restarting Quickshell:
- **Design Tokens**: `Theme.qml` remains the central design token contract for colors, radiuses, and typography. Its color properties are dynamically bound to `ThemeState.currentPalette`.
- **Reactive State Singleton**: `services/ThemeState.qml` manages the active palette and provides reactive methods (`setTheme(id)` and `nextTheme()`).
- **Persistence**: Theme selection persists across reboots in `~/.local/state/quickshell/theme.json`.
- **Catalog**: Includes 7 popular community color palettes:
  - `catppuccin-mocha` (default dark)
  - `tokyo-night` (dark neon)
  - `nord` (arctic cold dark)
  - `gruvbox` (warm retro dark)
  - `dracula` (high-contrast gothic dark)
  - `rose-pine` (pine & lilac dark)
  - `catppuccin-latte` (clean light mode)
- **Control Points**:
  - **CLI**: `scripts/theme-manager.py [list|get|set <id>|next]`
  - **Chameleon**: `chameleon`, `chameleon-light`, and `chameleon-oled` share a wallpaper source color and use the vendored Python port of Material Color Utilities for Tonal Spot roles (version 3.0.2, 2021 specification; MIT license in `scripts/vendor/MATERIALYOUCOLOR-LICENSE`). Normal and OLED use dark roles; OLED has a black base. Light uses the full light scheme.
  - **Spotlight Launcher**: Quick switcher via `:tema` or `:theme` filter and `: Alternar Tema` system action.
  - **Wallpaper gallery**: `ThemePreviewPane.qml` presents the active wallpaper in the center of a five-card Cover Flow, with neighboring choices around it and animated scale, tilt, opacity and position. Arrow keys or the wheel change selection; a click selects and Enter or a double click applies it. Images load only for the five visible thumbnails even when the folder contains many images. WebP and AVIF previews use Pillow; JPEG-XL uses ImageMagick. These formats are converted to cached JPEGs because the installed Qt image plugins do not decode them. The folder and selected image persist in `~/.local/state/quickshell/wallpaper.json`. Applying a thumbnail uses awww/swww, refreshes `~/.cache/current_wallpaper` and the Chameleon palette. `folder` selects a new directory with zenity; Spotlight unmaps its layer window while the native picker is open and remaps in theme mode afterward so the picker stays visible. `restore` reapplies the saved image at session startup. The selected image and folder are restored from the shell state file.
  - **Adapters**: every `set` / wallpaper-driven `update-wallpaper` also syncs
    Kitty, optional Ghostty, Hyprland, hyprlock, GTK, btop, Qt/Kvantum and labwc
    (`~/.config/labwc/themerc-override`, live-reloaded via
    `labwc --reconfigure` inside a labwc session). Manual edits to generated
    adapter files are replaced on the next sync.
  - **No-blur fallback**: labwc has no blur, so `Theme.qml` floors
    `backgroundAlpha` at 0.92 in labwc sessions (`labwcSession`); Hyprland
    caps it at 0.68 and applies compositor blur to Quickshell layers/popups.

See [`compositor-integration.md`](compositor-integration.md) for the capability
matrix and rules for adding another compositor without coupling UI files to its
transport.
