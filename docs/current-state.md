# Current shell map

`shell.qml` mounts a bar, OSD, and notification toasts per screen, plus the
Spotlight launcher and clipboard service. This page locates active components;
use the [feature guides](README.md#refer%C3%AAncia-por-recurso-guides) for behavior and contracts.

## Bar and popups

The bar defaults to three main islands and can optionally merge their surfaces
into one continuous bar. Conditional Submap, media, and status surfaces remain
in the same explicit layout in `bar/Bar.qml`; geometry comes from `Theme.qml`.
The surface preference is edited in Spotlight's appearance studio and stored in
`$XDG_CONFIG_HOME/quickshell/bar.json` (defaults to islands).

| Area | Mounted content |
| --- | --- |
| Left | StartButton, Workspaces; conditional Hyprland Submap |
| Center | Weather and Clock; Clock opens the weather/calendar dashboard |
| Between center and right | MPRIS MediaIsland and active-mode StatusIsland; status takes priority when space is tight |
| Right | Tray, Network, Bluetooth, Printer, SystemMonitor, UpdateControl, Battery, Audio, NotificationControl |

Visibility can be conditional even when a component is mounted. NotificationControl
opens combined notifications/Quick Settings and hosts recording controls. Updates
have their own popup. Brightness uses Quick Settings and OSD. The standalone
Control Center/Settings windows, old media/brightness bar widgets, and Phone
are not mounted in the current bar.

## Implementation entry points

| Area | Start in | Reference |
| --- | --- | --- |
| Search, apps, actions | `launcher/Spotlight.qml`, `SpotlightSearchController.qml`, `SpotlightQueryRouter.qml` | [Spotlight](guides/spotlight.md), [plan](plans/spotlight-raycast-plan.md) |
| Clipboard | `services/ClipboardService.qml`, `launcher/SpotlightClipboard.qml`, `scripts/clipboard_store.py` | [Clipboard](guides/clipboard.md) |
| Themes and wallpapers | `Theme.qml`, `services/ThemeState.qml`, `launcher/ThemePreviewPane.qml` | [Themes](guides/theme-management.md) |
| Weather and calendar | `services/WeatherState.qml`, `bar/WeatherCard.qml`, `bar/CalendarCard.qml` | [Weather](guides/weather.md), [holidays](guides/calendar-holidays.md) |
| Network and Bluetooth | `bar/NetworkPopup.qml`, `bar/BluetoothPopup.qml` | [Network](guides/network.md), [Bluetooth](guides/bluetooth.md) |
| Printing and phone | `bar/PrinterPopup.qml`, `bar/PhonePopup.qml` (currently hidden) | [Printing](guides/printer.md), [phone](guides/phone.md) |
| Audio and media | `bar/AudioPopup.qml`, `bar/MediaPopup.qml`, `services/MediaState.qml` | [Stability contract](stability-contract.md), [EasyEffects](guides/easyeffects.md) |
| Battery and power | `bar/BatteryPopup.qml`, `services/PowerProfileState.qml` | [Power](guides/power-controls.md) |
| Notifications and Quick Settings | `services/NotificationState.qml`, `bar/NotificationPopup.qml` | [Notifications](guides/notifications.md), [Quick Settings](guides/control-center.md) |
| OSD and recording | `osd/Osd.qml`, `services/ScreenRecordingState.qml` | [OSD](guides/osd.md), [recording](guides/screen-recording.md) |
| Hardware monitoring | `bar/SystemMonitor.qml`, `bar/SystemMonitorPopup.qml` | [System monitor](guides/system-monitor.md) |
| Updates | `bar/UpdateControl.qml`, `bar/SystemUpdatePopup.qml`, `services/UpdateState.qml`, `services/UpdateAvailability.js`, `scripts/update_status_json.py`, `scripts/update-log.py` | Arch, AUR, Flatpak, Homebrew, Gear Lever AppImages; result/log recovery |
| Games and downloads | `scripts/game-status.py`, `launcher/DownloadPanel.qml`, `services/DownloadState.qml` | [Downloads](guides/ytdlp-downloads.md); active games appear in Quick Settings |
| Lockscreen | `lockscreen.qml`, `lockscreen/LockscreenIsland.qml` | [Lockscreen](guides/lockscreen-prototype.md) |
| Compositors | `services/CompositorState.qml`, `services/MangoState.qml`, `scripts/compositor-dispatch.sh` | [Integration](setup/compositor-integration.md) |
| Display projection | `services/DisplayProjectionState.qml`, `scripts/display-projection.py` | [Projection](guides/display-projection.md), currently Hyprland only |
| Shared UI and helpers | `components/`, `services/CommandResult.js`, `components/CommandActionResult.js`, `services/CommandProcessLifecycle.js` | [Architecture](architecture.md) |

Spotlight's system-information panel uses Fastfetch and closes only with Escape.
Other popup dismissal rules are surface-specific; see the
[design guide](design-guidelines.md). The [stability contract](stability-contract.md)
records behavior that must survive refactoring.

Update this map when a surface is mounted, removed, or moved. Keep implementation
history in plans or Git, and functional details in the owning feature guide.
