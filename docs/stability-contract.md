# Stability Contract

These areas have been iterated heavily and should not be casually changed.

## Stable / preserve unless explicitly requested

### Media bar + media popup
Considered stable after multiple layout fixes.
The mounted `MediaIsland.qml` is Spotify-specific, opens by click and is
conditional on available bar space.
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
`MediaIsland.qml` opens the popup by click. An outside click dismisses it;
the `SUPER+;` binding toggles the player selected by shared `MediaState`.

### Weather backend choice
Open-Meteo replaced wttr.in because of TLS/reliability issues.

### Network architecture
Quickshell UI -> Python -> nmcli -> NetworkManager.

Protected Wi-Fi uses Quickshell's password dialog and `nmcli --ask` over stdin.

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

Keep bar composition explicit in `bar/Bar.qml`.

### Notifications
Native Quickshell NotificationServer is active, stable, and liked.
Current behavior includes:
- Native toast overlays (`notifications/NotificationToasts.qml`);
- Bar pill with live count badge and DND indicator (`bar/NotificationControl.qml`);
- History popup panel with 4-item comfortable viewport, smooth scroll, and entity decoding (`bar/NotificationPopup.qml`);
- Notification detail popup contract (`grabFocus: true`, outside-click dismiss,
  pill toggle, Escape). This is not a rule for every shell window; see the
  surface-specific exceptions in `docs/design-guidelines.md`.
Keep the native notification flow and unified theme tokens.

### OSD
Volume, microphone, brightness behavior should remain intact.

### Bluetooth
Functional enough.
Avoid large rewrites unless necessary.
