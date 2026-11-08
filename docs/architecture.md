# Architecture

Lume uses Quickshell/QML for surfaces and small Python/shell helpers for system
integration. See [current-state](current-state.md) for owners and
[shell-uml](shell-uml.md) for diagrams.

## Boundaries

`System APIs → services/helpers → UI surfaces → shared visual components`

UI components own presentation and user interaction. Services own shared state
and lifecycle; helpers normalize external data. Keep local state local unless
sharing, synchronization, or an API boundary makes a service useful.

`bar/Bar.qml` deliberately lists modules explicitly. Preserve ordering,
geometry, centering, focus, and popup behavior. The full constraints live in
[AGENTS.md](../AGENTS.md) and the [stability contract](stability-contract.md).

## QML conventions

- Declare inputs with `required property`, qualify bindings with the root ID,
  and communicate actions through signals. Avoid implicit parent context.
- Use `pragma ComponentBehavior: Bound` when nested components reference outer
  IDs; qualify delegate model values and outer state.
- Keep handlers readable; move repeated/multistep work to named functions.
- Reuse components for matching interaction contracts, not merely similar shapes.
  Specialized grids, workspace delegates, notifications, and Spotlight results
  may retain their own structures.
- All surfaces consume `Theme.qml` tokens. Literal QML palettes stay in
  `Theme.qml` and `services/ThemeState.qml`.
- Scope lint suppressions to documented Qt/Quickshell metadata gaps, such as
  PanelWindow, popup anchor enums, and QMargins. The validator supplies project
  qmldirs and checks all QML files, including quality warnings.

## Shared UI behavior

| Component | Responsibility |
| --- | --- |
| `PopupHeader` | Title, subtitle, accessory, and trailing actions |
| `PopupListRow` | Standard row slots and active/hover/border treatment |
| `ScrollableList` | Column or virtualized list with optional footer, search, empty state, scrollbar |
| `WheelKinetic`, `ScrollBar` | Common wheel motion, thumb dragging, track clicks; available directly for galleries/nested scrolling |
| `PopupIconButton`, `PopupSettingsButton` | Compact actions; settings-gear variant |
| `EmptyState`, `SearchField` | Empty-view layout; input/placeholder and optional debounced queries |
| `MaterialSwitch`, `SettingToggleRow` | Accessible switch and labeled switch row |
| `controlcenter/SliderRow` | Drag, wheel, normalized fill, hover, and disabled state |
| `MediaSeekBar` | Progress, time labels, animation, normalized seek requests |
| `ActionFeedback` | Busy/error presentation and optional timed dismissal |

Domains retain processes, labels, selection, mute/routing, and MPRIS conversion.
Display failures where the action lives; use global OSD only for shared feedback.

**PopupListRow caveat:** its default-content slot is hidden when standard slots
are active. Put pointer handlers in `interactionHandlers`. IDs inside a
`trailing:` Component are not visible to the row-level handler; expose needed
geometry through delegate properties. Do not bypass these boundaries by reaching
into another component's IDs.

Click-opened detail popups use `grabFocus: true`. Hover previews, Spotlight
subpanels, SystemInfo, and desktop windows have distinct dismissal rules in the
[design guide](design-guidelines.md). `MotionState` supplies shared QML motion
policy through `Theme.qml`; compositor window animations remain independent.

## Helpers, state, and processes

Use normalized `{ok, version, data, error}` responses. `CommandResult.js` accepts
versioned and legacy flat JSON, including error-only failures.
`CommandActionResult.js` also requires exit code zero before an action/query can
report success and includes stderr or the parsed helper error on failure.
`CommandAction` and `CommandJson` report a start failure if no `started` event is
observed within two seconds.
`CommandJson` owns status polling and process lifetime; its restart path waits
for the stopped process to exit and discards that run's output before launching
the latest query. Consume `result.data`; `payload` remains a compatibility view.
Use local `Process` objects when stdin, streaming, or domain-specific lifecycle
requires it.

Mango IPC and incremental speed-test streams keep protocol-specific parsers.
Other helper responses use the shared decoder. Keep normalization in one place:
notification text in `NotificationContent.js`, theme math in `theme_colors.py`,
and built-in theme data/terminal mappings in `theme_catalog.py`.

Shared helper utilities:

- `command_utils.py`: bounded subprocess execution.
- `network_utils.py`: IPv4 DNS workaround for weather/speed tests.
- `update_status_json.py`: common Arch/AUR/Flatpak/Brew update envelopes.
- `ProcessLifecycle.js`: completion versus failure to start; used by weather and
  clipboard instead of relying on unresolved QProcess exit-status metadata.
- `tests/helpers.py`: fixture access and loading hyphenated helper filenames.

Store mutable data in XDG state/cache locations, not tracked configuration.
Prefer events/file observation; avoid excessive polling and background scans
when the UI is closed. Never pass secrets in argv. Wi-Fi uses `nmcli --ask`
over stdin. Existing nmcli, bluetoothctl, CUPS, and Open-Meteo backends remain
valid choices; a shared service does not require replacing them.

Feature guides own polling details, persistence formats, and error contracts.
Tests should use temporary state and mock command boundaries, not the user's
running desktop. See [validation](deploy-and-validation.md).

## Spotlight

`SpotlightSearchController` coordinates searches; `SpotlightQueryRouter` maps
query modes to providers and normalized `SpotlightResult` objects. Ranking
combines apps/windows/actions for nonempty root queries; empty root lists apps.
Legacy result fields remain for existing activation/preview paths.

`SpotlightModeLogic.js` classifies queries; `SpotlightActionLogic.js` resolves
navigation/grouping/actions. `SpotlightActionExecutor` executes operations and
signals launcher work such as closing, navigation, confirmation, and usage
ranking. Focus and ranking-process ownership remain with `Spotlight.qml`.
See the [Spotlight plan](spotlight-raycast-plan.md) and [clipboard guide](clipboard.md).

## Compositor Boundary & Agnosticism

`CompositorState` selects `auto`, `wayland`, or `hyprland` through
`LUME_COMPOSITOR_MODE`. Generic workspaces use `WindowManager` with
`screenProjection(screen)`; window actions use `ToplevelManager`. Hyprland
retains native occupancy, PID, and workspace metadata. Protocol window data
does not provide PID-based process termination.

An empty model is `unreported`, not proof of missing protocol support. Doctor
can inspect compositor announcements separately through optional `wayland-info`.
Mango keeps one `mmsg` stream in `auto` for focused-output state and workspace
fallback. Native CLI dispatch lives in `scripts/compositor-dispatch.sh`.
See [compositor integration](compositor-integration.md) for capabilities,
version limits, focused-output fallback, and projection restrictions.

## Theme System & Multi-Theme Architecture

`ThemeState` owns the reactive palette; `Theme.qml` exposes visual tokens.
The theme CLI owns persistence, wallpaper-derived colors, and adapter sync;
`theme_catalog.py` owns catalog data. Read the catalog instead of duplicating
its theme count/list in documentation.

Theme Studio previews choices without changing the global palette, applies
explicit selections, and persists wallpaper/color preferences. Chameleon has
dark, light, and OLED variants. Shared tokens handle opacity/readability for
compositors with or without blur. Gallery navigation lives in `GalleryNav.js`.

See [theme management](theme-management.md) for commands, adapters, state paths,
thumbnail conversion, picker behavior, and wallpaper restoration. Generated
adapter files are replaced on subsequent syncs; use the documented customization
points. Visual constraints belong in the [design guide](design-guidelines.md).
