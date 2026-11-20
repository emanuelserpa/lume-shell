# Stability Contract

These areas have been iterated heavily and should not be casually changed.

## Stable / preserve unless explicitly requested

### Media bar + media popup
Considered stable after multiple layout fixes.
The mounted `MediaIsland.qml` shows the selected active MPRIS player, opens by
click and is conditional on available bar space. When multiple players have
active playback or track metadata, the island shows a compact page indicator
for direct selection; both the island and MediaPopup accept vertical or
horizontal wheel scrolling to cycle through players, while the popup retains
its player list and shows a centered, clickable page indicator. Non-selected
players that are playing pulse subtly; the selected player stays steady.
Choosing a player changes the shared `MediaState` selection. The dot indicator
uses a fixed delegate pool. Keep that model stable: rebinding a JavaScript array of
MPRIS QObject instances during player teardown crashed both `QQuickRepeater`
and `QQmlInstantiator` in Qt 6.11. The regular bar uses its media popup and
player menu. The lockscreen renders its player dots directly inside the media
card; it must not depend on a regular `PopupWindow` opening over a
`WlSessionLockSurface`.

### Wayland session-lock surfaces
`WlSessionLock` creates dedicated `WlSessionLockSurface` windows. They are the
surfaces guaranteed to cover the session; a normal `PopupWindow` is a separate
Wayland surface and may lack a valid popup parent when opened from the lock.
Keep lockscreen controls that must always work inside the lock surface itself.
The media selector is inline in the media card, and the suspend menu is drawn
inside the island. A popup anchored to a lock item is not proof that the popup
will be mapped on every compositor. See `docs/lockscreen-prototype.md` for the
behavior and Quickshell references.

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

### System tray icons
System tray items and context menus can expose themed icons as
`image://icon/...` URLs. Resolve those URLs with `services/IconSource.js` before
passing them to `QtQuick.Image`; keep filesystem and other image URLs intact.
This bypasses the Quickshell icon pixmap provider path implicated by the
November 2026 crash report on the current Qt/KDE icon stack.

### OSD
Volume, microphone, brightness behavior should remain intact.

### Bluetooth
Functional enough.
Avoid large rewrites unless necessary.
