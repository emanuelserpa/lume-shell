# Quick Settings and system actions

The current shell uses the notification popup as its combined notification and
Quick Settings surface. The old `ControlCenterCard` has been retired; the
weather/calendar dashboard now contains weather, calendar, and holidays.
Hardware monitoring opens from the chip icon in the Quick Settings header; its popup is anchored to the bar controls button.

## Quick Settings

`bar/NotificationPopup.qml` composes the shared `controlcenter/QuickTile.qml`
and `controlcenter/SliderRow.qml` components with the existing domain state:

- output volume, microphone input volume, and brightness sliders;
- Wi-Fi and Bluetooth radio toggles;
- idle-inhibition, DND, and night-light toggles;
- a game-status row shown only while one or more games are running;
- full active media controls, including player selection and seeking through
  the shared `components/MediaSeekBar.qml` used by the full media popup;
- notification history and session actions.

The combined popup uses the shared Adaptive Soft UI tokens: its frame keeps
the compositor-aware background, control tiles use palette-derived tonal
surfaces, and its three sliders share an 11 px rounded track with a visible
circular thumb. The two-column tile grid remains compact and anchored to the
notification pill. These visual changes preserve the existing actions and the
popup's focus and dismissal behavior.

Wi-Fi and Bluetooth details remain in `NetworkPopup` and `BluetoothPopup`.
Their tiles route toggles and detail requests through the existing bar domain
components, preserving Wi-Fi password handling, scans, pairing, and feedback.
Audio details open the existing `AudioPopup`. Session actions retain the
confirmation step for logout, reboot, and poweroff. Update counts continue to
come from the shared `services/UpdateState.qml`; each backend is polled once.
The master output, microphone input, and per-application volume controls in
`AudioPopup` reuse the same `SliderRow` as Quick Settings, with the existing
150% volume range and PipeWire mute/device actions preserved. In Quick Settings,
the output and microphone icons toggle mute while their sliders continue to
adjust volume.
On ThinkPads, `scripts/micmute-led.sh` mirrors the default PipeWire source mute
state to `platform::micmute`; its user service listens for source/server changes
and avoids repeated sysfs writes when the LED already matches.
Updates have a dedicated bar pill and popup, separate from Quick Settings and
the weather/calendar dashboard. The pill is hidden when the system is up to
date and appears when updates are available or an update is running. The popup
includes AppImages managed by Gear Lever, queried through its versioned JSON
CLI. The AppImage action updates all eligible applications; Gear Lever skips
applications that are currently running. Update actions run in the background
through `services/UpdateState.qml`; the popup stays open and shows the active
backend and the final result. Successful completion uses a green circled check
to distinguish its status from the plain action checkmarks elsewhere. Arch and
AUR package elevation uses the graphical Polkit agent, while the remaining
providers run as the user. Provider output is recorded in the user's Quickshell
cache log. While an update runs, “Ver
progresso no terminal” opens Kitty following that log, including the current
stage and Flatpak item progress.
Idle inhibition is available both from its Quick Settings tile and the clock's
context action; its compact caffeine indicator appears in the bar while active.

The former `SystemUpdates` component and `ControlCenterCard` are retired. Steam
launching remains available through Spotlight; the game row in Quick Settings
is informational and appears only while a game is active.
The media section restores the detailed player selector, artwork and album
metadata, seek bar with elapsed/total time, and previous/play-pause/next actions
inside a rounded card with a clipped, blurred album-art backdrop. The old media
popup continues to offer its hover-preview behavior.

## Historical Control Center

The former standalone v0.21.0 Control Center was an upstream-Quickshell-only
top-right `PanelWindow`, later embedded as `ControlCenterCard` in the center
dashboard. `SUPER+A` continues to open Spotlight actions; it is not a
Quick Settings shortcut.

The current implementation keeps these established integrations:

- native Quickshell PipeWire for audio;
- native Quickshell UPower for battery;
- native MPRIS through `services/MediaState.qml`;
- existing NetworkManager and Bluetooth helper scripts;
- existing energy-profile, night-light, update, and session helpers;
- shared idle-inhibit state in `qs.services.IdleState`.

The shell does not create an exclusive zone or resize client windows.

The bar uses a sliders icon with a pending-notification dot to open this combined panel. A separate moon toggles DND; right-click on the sliders retains the DND shortcut. CPU and volume no longer occupy standalone bar pills.
