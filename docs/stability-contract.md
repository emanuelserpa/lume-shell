# Stability Contract

These areas have been iterated heavily and should not be casually changed.

## Stable / preserve unless explicitly requested

### Media bar + media popup
Considered stable after multiple layout fixes.
The mounted `MediaIsland.qml` is Spotify-specific, opens by click and is
conditional on available bar space. The older `Media.qml` hover-preview path
is a separate behavior; do not confuse it with the mounted island.
The popup's alternate-player rows use a fixed delegate pool. Keep that model
stable: rebinding a JavaScript array of MPRIS QObject instances during player
teardown crashed both `QQuickRepeater` and `QQmlInstantiator` in Qt 6.11.

### Audio popup
Considered stable and liked.
Current behavior includes:
- output section;
- microphone section;
- icon mute toggles;
- sliders;
- selectors.

### Media popup
When invoked through the legacy `Media.qml` hover-preview path, the media
popup closes when the pointer leaves both the pill and popup, and stays open
when clicked to pin it. `MediaIsland.qml` invokes the popup by click. While in hover
preview, an outside click also dismisses it through the Hyprland focus-grab
protocol. The `SUPER+;` binding toggles the player selected by shared
`MediaState`.

### Weather backend choice
Open-Meteo replaced wttr.in because of TLS/reliability issues.

### Network architecture
Quickshell UI -> Python -> nmcli -> NetworkManager.

On labwc, protected Wi-Fi uses Quickshell's password dialog and `nmcli --ask`
over stdin. `nm-applet` is not started.

### Network scan behavior
Do not continuously force Wi-Fi scans.

Scanning should occur:
- when popup opens;
- on explicit refresh;
- on relevant user action while open.

### Network placement
`Network` stays after `Tray`.

### Bar ordering implementation
Explicit QML layout stays.

Do not restore `bar.json`.

### Notifications
Native Quickshell NotificationServer is active, stable, and liked.
Current behavior includes:
- Native toast overlays (`notifications/NotificationToasts.qml`);
- Bar pill with live count badge and DND indicator (`bar/NotificationControl.qml`);
- History popup panel with 4-item comfortable viewport, smooth scroll, and entity decoding (`bar/NotificationPopup.qml`);
- Notification detail popup contract (`grabFocus: true`, outside-click dismiss,
  pill toggle, Escape). This is not a rule for every shell window; see the
  surface-specific exceptions in `docs/design-guidelines.md`.
Do not revert to SwayNC or alter the unified theme tokens.

### OSD
Volume, microphone, brightness behavior should remain intact.

### Bluetooth
Functional enough.
Avoid large rewrites unless necessary.

## Historically reverted experiments

### Dynamic config-driven bar ordering
A `config/bar.json` + `Repeater/Loader` approach was attempted.
Result: visually worse spacing/alignment.
It was reverted.

### Custom network/Bluetooth popup attempts
Earlier custom implementations failed to open.
Later stable versions should not be regressed back to those patterns.

## Regression sensitivity

The user is highly sensitive to visual regressions.

If a module is described as:
- "perfeito"
- "ótimo"
- stable
- working

do not alter it during unrelated work.
