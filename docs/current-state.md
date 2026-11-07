# Current State

This page maps the current shell. Check the referenced source before changing
behavior. For constraints, read `AGENTS.md` and `docs/stability-contract.md`;
for design and implementation, read `docs/architecture.md`,
[`shell-uml.md`](shell-uml.md), and the relevant domain guide.

## Shell composition

`shell.qml` creates one bar, OSD, and notification toast surface per screen, plus the Spotlight launcher and clipboard service. `bar/Bar.qml` defines the bar order explicitly. The bar shows glanceable state; popups contain detail and interaction.

| Area | Mounted components and behavior |
| --- | --- |
| Left | `StartButton` (`bar-search`) opens universal search; Left at the start of the search field opens its categorized app menu; `Workspaces` uses Hyprland's native model or Quickshell `ext-workspace-v1` on other compositors, with Mango IPC for focused-output state and as a workspace fallback; `Submap` uses the compositor dispatcher and appears only on Hyprland. |
| Center | Autonomous `Weather` and `Clock` modules backed by `services/WeatherState.qml`; `Clock` owns `CenterDashboardPopup`, which contains weather, calendar, and the next two national and Ceará holidays. |
| Between center and right | Conditional `MediaIsland` (Spotify) and `StatusIsland` (`bar/StatusIsland.qml`) for active session modes (DND moon, idle-inhibition coffee, active screen recording via `services/ScreenRecordingState.qml`); `StatusIsland` takes priority over `MediaIsland` when horizontal space is tight, and each indicator deactivates its active mode on click. |
| Right (inside to edge) | Pluggable, self-contained modules (`{ theme: barTheme; plain: true }`): `Tray`, `Network`, `Bluetooth`, conditional `Printer`, `SystemMonitor`, conditional `UpdateControl`, `Battery`, `Audio`, and `NotificationControl`. Each module renders its own pill and anchors its own popup directly to itself; `NotificationControl` also hosts `ScreenRecordingPopup` backed by `services/ScreenRecordingState.qml`. |

`CalendarCard` shows the next two applicable holidays in dedicated `HolidayPill` rows. Holiday dates come from `services/HolidayLogic.js`; the current saved weather city's region adds Ceará's Data Magna. Municipal holidays and facultative days are omitted because they vary by municipality and decree. The system-monitor action in Quick Settings opens CPU frequency, memory, temperature, and fan details. One helper discovers and polls temperature and fan sensors only while that popup is open. The calendar no longer polls telemetry. Popups share the Adaptive Soft UI radius, surface, border, and motion tokens in `Theme.qml`; tiles, sliders, switches, rows, and popup cards reuse existing components. See `docs/calendar-holidays.md`, `docs/system-monitor.md`, and `docs/power-controls.md`. Brightness uses the global OSD; its older bar components are not mounted. The standalone Control Center window and button are disabled. Spotlight remains available through keyboard shortcuts.

The top bar has three main tonal islands for Spotlight/workspaces,
weather/calendar/clock, and system indicators, plus separate conditional islands
for Submap and Spotify media. The media island is hidden when space is insufficient. Their surface, border, radius,
padding, and spacing use `Theme.qml` tokens; interactive controls inside the
islands use plain pill styling to avoid nested surfaces. Its 37px height and
exclusive zone remain fixed for the tiling layout.

The sliders button opens the combined notification and quick-settings popup. Its dot indicates pending notifications; the tooltip exposes the exact count. The separate moon toggles DND. Wi-Fi and Bluetooth tiles toggle the radios; the rest of each tile opens the existing detailed popup after the combined popup fades out. Compact bar indicators show active network and caffeine status; the speaker pill adjusts volume by scrolling, mutes on right click, and opens the detailed audio mixer on left click. Bluetooth remains available in Quick Settings and its detailed popup. Output/input volume and brightness sliders, full media controls (player selection, blurred album-art backdrop, metadata, seeking, and transport), idle inhibition, night light, and session actions are also in Quick Settings. Updates have a dedicated conditional bar pill and popup, separate from Quick Settings and the calendar dashboard. Idle inhibition is available from the clock's context action and its Quick Settings tile. A non-interactive game-status row appears only while games are running. The weather/calendar dashboard no longer contains the retired `ControlCenterCard`.

## Where to look

Design decisions: [design guidelines](design-guidelines.md),
[visual checklist](visual-regression-checklist.md), and
[consistency plan](design-plan.md).

| Work area | Current implementation and detail |
| --- | --- |
| Launcher, clipboard & theme studio | `launcher/Spotlight.qml`, `launcher/AppCategorySidebar.qml`, `launcher/AppCategoryLogic.js`, `launcher/SpotlightActionExecutor.qml`, `launcher/SpotlightActionLogic.js`, `launcher/SpotlightModeLogic.js`, `launcher/SpotlightQueryRouter.qml`, `launcher/SpotlightSearchController.qml`, `launcher/SpotlightRanking.qml`, `launcher/SpotlightResult.qml`, `launcher/ThemePreviewPane.qml`, `services/ClipboardService.qml`, `LAUNCHER.md`, `docs/clipboard.md`, `docs/spotlight-raycast-plan.md` |
| Weather | `bar/Weather.qml`, `bar/WeatherCard.qml`, `docs/weather.md` |
| Network | `bar/Network.qml`, `bar/NetworkPopup.qml`, `services/NetworkActionLogic.js`, `docs/network.md` |
| Bluetooth | `bar/Bluetooth.qml`, `bar/BluetoothPopup.qml`, `docs/bluetooth.md`; detailed controls remain in Quick Settings |
| Phone (KDE Connect, currently hidden) | `bar/Phone.qml`, `bar/PhonePopup.qml`, `docs/phone.md` |
| Printing | `bar/Printer.qml`, `bar/PrinterPopup.qml`, `docs/printer.md` |
| Media and audio | `bar/Audio.qml` (speaker volume pill), Spotify-only `bar/MediaIsland.qml` with artwork, metadata, animated playback indicator, progress, and inline transport controls, `services/MediaState.qml`, `bar/QuickMediaPlayer.qml`, `bar/MediaPopup.qml`, `bar/AudioPopup.qml` (EasyEffects bypass and presets: `docs/easyeffects.md`); the Quick Settings player, media popup, and `SUPER+;` share MPRIS player selection; stability rules in `docs/stability-contract.md` |
| Battery and power | `bar/Battery.qml`, `bar/BatteryPopup.qml`, `services/PowerProfileState.qml`, `scripts/energy-profile.py`, `scripts/battery-health.py` (UPower fallback), `scripts/cpu-boost.py`, system power-source policy and charge-limit helper, `docs/power-controls.md`; automatic AC/battery profiles and suspend-mode selection |
| Notifications | `services/NotificationState.qml`, `scripts/notification_store.py` (SQLite/WAL archive), `services/BatteryAlertState.qml`, `notifications/NotificationToasts.qml`, `docs/notifications.md` |
| OSD and screen recording | `osd/Osd.qml`, `bar/ScreenRecording.qml`, `docs/osd.md`, `docs/screen-recording.md` |
| Dashboard and controls | `bar/CenterDashboardPopup.qml`, `bar/CalendarCard.qml`, `components/HolidayPill.qml`, `services/HolidayLogic.js`, `docs/calendar-holidays.md`, `bar/SystemMonitor.qml`, `docs/system-monitor.md`, `bar/NotificationPopup.qml`, `services/UpdateState.qml` (Arch, AUR, Flatpak, Homebrew, Gear Lever AppImages), `docs/control-center.md` |
| Running games | `scripts/game-status.py`; Quick Settings shows active games contextually, while Spotlight launches Steam |
| Downloads (yt-dlp) | Paste a link in Spotlight for video/audio actions; `launcher/DownloadPanel.qml`, `services/DownloadState.qml`, `scripts/ytdlp-download.py`, `docs/ytdlp-downloads.md` |
| Themes & Material You | `Theme.qml`, `launcher/ThemePreviewPane.qml`, `services/ThemeState.qml`, `services/WallpaperState.qml`, `scripts/theme_catalog.py`, `scripts/theme-manager.py`, `scripts/wallpaper-action.py`, `docs/theme-management.md`, `docs/architecture.md` |
| Shared interactions | `components/WheelKinetic.qml`, `components/ScrollBar.qml`, `components/ScrollableList.qml`, `components/ActionFeedback.qml`, `components/CommandJson.qml`, `services/CommandResult.js`, `components/PopupHeader.qml`, `components/PopupListRow.qml`, `components/EmptyState.qml`, `components/SearchField.qml`, `components/SettingToggleRow.qml`, `components/PopupIconButton.qml`, `components/PopupSettingsButton.qml`, `components/MaterialSwitch.qml`, `components/MediaSeekBar.qml`, `controlcenter/QuickTile.qml`, `controlcenter/SliderRow.qml`, `launcher/GalleryNav.js` |
| Deployment and checks | `scripts/doctor.sh`, `scripts/validate.sh`, `docs/deploy-and-validation.md` |

No modo `:sistema` do Spotlight, “Informações do Sistema” abre um painel central
com dados do hardware, sistema e pacotes obtidos pelo Fastfetch. O painel fica
aberto ao clicar fora ou na barra; somente `Esc` o fecha.
|Compositor support | `services/CompositorState.qml` selects native/generic providers and reports exposed capability state; `services/WorkspaceModel.js` filters protocol windowsets while preserving their objects; `services/MangoState.qml` and `services/MangoWorkspace.js` provide focused-output/fallback state; `scripts/compositor-dispatch.sh`, `docs/compositor-integration.md`, `docs/wayland-compositor-research.md` |
| Display projection | `bar/DisplayProjectionPopup.qml`, `services/DisplayProjectionState.qml`, `scripts/display-projection.py`, `docs/compositor-integration.md` (Hyprland only) |

## Maintenance notes

`PopupHeader` supplies title, accessory, and action layout to popup headers and
Quick Settings sections. `PopupListRow` supplies the surface and interaction
state for list rows across the bar; standard
slots (leadingIcon/leadingImage/title/subtitle/trailing/topDivider) carry
icon/title/subtitle rows. Put pointer handlers for standard rows in
`interactionHandlers`; the default-content slot is hidden in that mode. The
default-content fallback remains for delegates with distinct visuals and
interaction (meters, sliders, action strips).
`ScrollableList` combines conventional wheel handling with Column-backed or
virtualized model/delegate content and optional footer, scrollbar, empty-state,
and search-field slots. `PopupSettingsButton` is the gear-specific variant of
the reusable `PopupIconButton`.
`launcher/GalleryNav.js` owns gallery index math (grid/linear/clamp/sync);
`ThemePreviewPane` routes catalog/carousel nav and wallpaper helper
responses through it and `helperResponse`.
The Theme Studio also extracts up to five distinct colors from the active
wallpaper, previews Chameleon dark/light/OLED without global side effects, and
applies a confirmed choice saved per wallpaper content. Details are in
`docs/theme-management.md`. Its Appearance section includes a persisted glass
opacity control and a live wallpaper-stage preview; compositor readability
limits remain centralized in `Theme.qml`.
`SettingToggleRow` standardizes a labeled switch row and is used by screen
recording and VPN controls. Specialized calendar cells, notification cards,
workspace delegates, and Spotlight results keep their own structures.

- Keep the explicit `Bar.qml` ordering and the existing popup behavior. `Network` remains after `Tray`.
- The custom network UI prompts for protected Wi-Fi passwords and passes them to `nmcli --ask` over stdin; See `docs/network.md`.
- `services/UpdateState.qml` polls Arch, AUR, Flatpak, Homebrew, and Gear Lever AppImage updates once per hour. A dedicated bar pill appears only when updates are available or installation is running; its popup shows provider progress and results, including Flatpak's current item and download percentage. Install actions run in the background and system package elevation uses Polkit. Gear Lever's JSON list feeds the AppImages row; its update action skips running apps. `Tray` hides when no visible tray icons remain; `Printer`, `Media`, and `Submap` also conditionally hide.
- Night Light saves its enabled preference in state and synchronizes `hyprsunset`/`wlsunset` when the shell session starts, so its persisted indicator and display effect recover together.
- Hyprland applies blur to Quickshell layers and popups; all shell base surfaces share the theme background alpha (maximum 0.68). Mango and labwc retain near-opaque popup/base fallbacks where compositor blur is unavailable.
- Update this map when a surface is mounted, removed, or moved. Put interaction details and backend contracts in the relevant domain documentation.

Recent surface polish: Spotlight and toast outer corners use `radiusPopup`. The update pill rotates while its busy state is active; low battery no longer highlights the whole battery pill. Notification images are archived to private files instead of retaining short-lived Quickshell image handles. Notification history can reopen the originating app through its desktop-entry when a live action is unavailable (requires `gtk-launch`).

Bar icon polish: mounted shell indicators use local theme-tinted SVGs at
`Theme.barIconSize`. Workspace pills display labels supplied by their
compositor. On Hyprland, the bar uses its live workspace model, names, IDs, and
monitor assignments, showing the active workspace and occupied regular
workspaces per monitor. Occupancy also uses Hyprland's workspace snapshot when
Quickshell has not tracked a window event for a renamed workspace. The shell
does not define workspace icons or names.

The date/weather dashboard uses one popup surface for both columns. Its local
calendar and forecast controls use the shared theme-tinted SVG family and
`dashboard*` typography tokens; forecast metric tiles remain grouped content
within the shared surface. See `docs/design-guidelines.md` and the dashboard
entry in `docs/design-plan.md` for the current refinement state.
