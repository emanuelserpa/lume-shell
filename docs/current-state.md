# Current shell map

`shell.qml` mounts a bar, OSD, and notification toasts per screen, plus the
Spotlight launcher and clipboard service. This page locates active components;
use the [feature guides](README.md#feature-reference) for behavior and contracts.

## Bar and popups

The bar has three main islands and conditional Submap, media, and status
surfaces. Its layout is explicit in `bar/Bar.qml`; geometry comes from `Theme.qml`.

| Area | Mounted content |
| --- | --- |
| Left | StartButton, Workspaces; conditional Hyprland Submap |
| Center | Weather and Clock; Clock opens the weather/calendar dashboard |
| Between center and right | Spotify MediaIsland and active-mode StatusIsland; status takes priority when space is tight |
| Right | Tray, Network, Bluetooth, Printer, SystemMonitor, UpdateControl, Battery, Audio, NotificationControl |

Visibility can be conditional even when a component is mounted. NotificationControl
opens combined notifications/Quick Settings and hosts recording controls. Updates
have their own popup. Brightness uses Quick Settings and OSD. The standalone
Control Center/Settings windows, old media/brightness bar widgets, and Phone
are not mounted in the current bar.

## Implementation entry points

| Area | Start in | Reference |
| --- | --- | --- |
| Search, apps, actions | `launcher/Spotlight.qml`, `SpotlightSearchController.qml`, `SpotlightQueryRouter.qml` | [Spotlight plan](spotlight-raycast-plan.md) |
| Clipboard | `services/ClipboardService.qml`, `launcher/SpotlightClipboard.qml`, `scripts/clipboard_store.py` | [Clipboard](clipboard.md) |
| Themes and wallpapers | `Theme.qml`, `services/ThemeState.qml`, `launcher/ThemePreviewPane.qml` | [Themes](theme-management.md) |
| Weather and calendar | `services/WeatherState.qml`, `bar/WeatherCard.qml`, `bar/CalendarCard.qml` | [Weather](weather.md), [holidays](calendar-holidays.md) |
| Network and Bluetooth | `bar/NetworkPopup.qml`, `bar/BluetoothPopup.qml` | [Network](network.md), [Bluetooth](bluetooth.md) |
| Printing and phone | `bar/PrinterPopup.qml`, `bar/PhonePopup.qml` (currently hidden) | [Printing](printer.md), [phone](phone.md) |
| Audio and media | `bar/AudioPopup.qml`, `bar/MediaPopup.qml`, `services/MediaState.qml` | [Stability contract](stability-contract.md), [EasyEffects](easyeffects.md) |
| Battery and power | `bar/BatteryPopup.qml`, `services/PowerProfileState.qml` | [Power](power-controls.md) |
| Notifications and Quick Settings | `services/NotificationState.qml`, `bar/NotificationPopup.qml` | [Notifications](notifications.md), [Quick Settings](control-center.md) |
| OSD and recording | `osd/Osd.qml`, `services/ScreenRecordingState.qml` | [OSD](osd.md), [recording](screen-recording.md) |
| Hardware monitoring | `bar/SystemMonitor.qml`, `bar/SystemMonitorPopup.qml` | [System monitor](system-monitor.md) |
| Updates | `bar/UpdateControl.qml`, `bar/SystemUpdatePopup.qml`, `services/UpdateState.qml`, `services/UpdateAvailability.js`, `scripts/update_status_json.py`, `scripts/update-log.py` | Arch, AUR, Flatpak, Homebrew, Gear Lever AppImages; result/log recovery |
| Games and downloads | `scripts/game-status.py`, `launcher/DownloadPanel.qml`, `services/DownloadState.qml` | [Downloads](ytdlp-downloads.md); active games appear in Quick Settings |
| Compositors | `services/CompositorState.qml`, `services/MangoState.qml`, `scripts/compositor-dispatch.sh` | [Integration](compositor-integration.md) |
| Display projection | `services/DisplayProjectionState.qml`, `scripts/display-projection.py` | [Projection](display-projection.md), currently Hyprland only |
| Shared UI and helpers | `components/`, `services/CommandResult.js`, `components/CommandActionResult.js`, `services/CommandProcessLifecycle.js` | [Architecture](architecture.md) |

Spotlight's system-information panel uses Fastfetch and closes only with Escape.
Other popup dismissal rules are surface-specific; see the
[design guide](design-guidelines.md). The [stability contract](stability-contract.md)
records behavior that must survive refactoring.

Update this map when a surface is mounted, removed, or moved. Keep implementation
history in plans or Git, and functional details in the owning feature guide.
