# Notification System

## Overview

The notification subsystem provides toast popups, a tracked-notification history panel, Do Not Disturb (DND) controls, and status bar integration through Quickshell's native NotificationServer.

---

## 1. Components & Architecture

The system is organized into modular QML components connected through a reactive singleton service:

- **`services/NotificationState.qml`**: Central state engine registered via `qs.services`.
  - Connects to Quickshell's native `NotificationServer`.
  - Combines live server notifications, project-owned internal notifications, and persisted snapshots in newest-first order. A separate in-memory queue of the 20 latest notifications restores dismissed toasts; that queue resets with the shell session.
  - Sends compact snapshots to `scripts/notification_store.py`, a long-lived background SQLite writer using WAL. The database retains up to 2,000 notifications under `$XDG_DATA_HOME/quickshell/notifications/`; the latest 500 load into the history view. Dismissed items remain as archived history without live D-Bus action callbacks. Clear All clears both the live list and stored history.
  - If the writer exits or fails to start, requests queue until its initial
    `loaded` response. Restarts use exponential backoff from 1 to 60 seconds,
    with a 2-second start watchdog. The in-memory queue is capped at 500: an
    incoming request evicts the oldest queued `append` before any control
    request; `clear` supersedes all queued work, and a
    control request is rejected only when the full queue contains controls
    alone. The popup reports unavailable storage and counts operations not
    applied, so users can see when persisted history may be incomplete. This
    queue is session-only; a shell restart clears its pending requests and
    warning.
  - Persistent snapshots include app identity, summary, body, urgency, icon/image references, and receive time. Quickshell-owned `image://qsimage/` handles are copied to private PNG files while their notification objects are retained, so replacing a notification cannot invalidate images in history. App actions are intentionally not stored because their owners may no longer exist.
  - Clears tracked notifications in small timed batches so a large history does not monopolize the UI event loop.
  - Manages in-memory DND state and emits toast events when DND permits them. Critical notifications still emit toast events.
  - Battery and UPower status notifications are toast-only: they do not enter
    the tracked list, counter, or persistent history. Quickshell's own low-
    battery alerts still use the toast path and retain their urgency behavior.
  - Internal notifications use the same toast, history, DND, counter and dismissal path as notifications received from applications. They may provide an `image` source for the toast image slot; download completion and failure notices use it for the media thumbnail.
  - Performs HTML entity decoding and markup sanitization (`formatText`).
  - Resolves app icon names and image paths through the shared `resolveIcon` method.
  - Computes relative timestamps (`agora`, `2m`, `1h`, `2d`).
- **`notifications/NotificationToasts.qml`**: Floating HUD toast overlay.
  - Uses shared `PopupCard` and `PopupIconButton` components, matching the
    notification popup background, glass border, `theme.radiusPopup` corners, 380px width, 12px inset and
    theme typography. It omits the app-name header, placing relative time on the
    title line so the image-and-message block stays centered without extra top
    space. The app icon sits over the lower-right
    corner of a supplied notification image; without an image, it occupies the
    leading visual slot. Hover-revealed actions remain available. Critical
    borders remain red.
  - Maintains up to four visible toasts; this is separate from notification history.
  - Uses Quickshell's foreign-toplevel state to defer normal toast cards while
    the active window is fullscreen; critical toasts remain visible. Deferred
    notifications stay in the toast queue and appear after fullscreen ends,
    while the history and count update immediately.
  - A keyed ListModel preserves existing toast delegates, images and timers
    when messages arrive. Replacements update the same card and reset its timer;
    only the oldest card is evicted when the four-card limit is reached.
  - Toasts enter with a short 24px glide from inside the column, scale and fade;
    the animation keeps their right edge within the screen. The column uses a
    velocity-based smoothed movement so a burst can retarget cards without
    restarting them at a new speed. Exit removal waits for
    `motionPopupExit` so the fade completes. Fullscreen hides normal cards and
    pauses their timers without destroying their delegates. Critical cards
    remain visible; hover pauses expiration.
  - Rendered as a transparent `PanelWindow` anchored to `Edges.Top | Edges.Right`.
  - Configured with `surfaceFormat.opaque: false` for Hyprland background blur.
  - Receives only the toast events allowed by DND, with critical notifications exempted.
  - Restored notifications are rendered as toast snapshots and do not change the tracked list or dismiss the original notification again.
- **`services/BatteryAlertState.qml`**: One global UPower listener for low-battery alerts. It preserves the 20%, 10% and 5% thresholds, sends only while discharging, escalates once per threshold, resets on charger connection, and posts the charger-connected notice through `NotificationState`.
- **`components/NotificationCardContent.qml`**: Shared toast/history content owns
  image and app-icon resolution, battery fallback, corner badge, title, relative
  time, body, hover expansion, primary action, and action buttons. History uses
  its compact sizing and optional shared `PopupIconButton` dismissal control.
  Notification images decode asynchronously at a maximum 128×128 and bypass
  Qt's shared image cache; app icons decode at 64×64. This keeps a stream of
  unique, full-resolution notification images from accumulating large decoded
  textures in the long-lived shell. Archived copies remain downsampled to
  256×256 for the history store.
  Containers retain their own surface, hover state, lifecycle, and dismissal.
- **`components/NotificationActionButton.qml`**: Shared action button used by
  toast cards and the notification history popup. It translates common labels
  while invoking the original notification action. Actions use restrained text
  controls with a hover surface rather than persistent filled chips.
- **`bar/NotificationControl.qml`**: Status bar module.
  - Displays glyphs for notification and DND states (`󱅫`, `󰂠`, `󰪓`, `󰂜`).
  - Displays the notification and DND state glyphs, with the tracked count.
  - Pill clicks: Left-click toggles popup history; the popup header holds the DND toggle.
- **`bar/NotificationPopup.qml`**: Detailed history and control panel. Its
  empty history view uses `components/EmptyState.qml`; `NotificationState`
  still owns the history and visibility decision.
  - Both the quick-settings and notification section headers use
    `components/PopupHeader.qml`. Their mixer/session actions and live
    notification count use its shared action and title-accessory slots.
  - Compact header icon actions use `components/PopupIconButton.qml`;
    `PopupSettingsButton.qml` shares its interaction and visual base.
  - Anchored to the bar pill with standard right-cluster geometry.
  - Implements the Unified Popup Behavior (`grabFocus: true`, pill toggle, Escape dismissal).
  - The same popup includes compact quick settings, active media controls, and
    notification history. Wi-Fi and Bluetooth tile icons toggle their radios;
    the tile details open the existing `NetworkPopup` and `BluetoothPopup`
    after this popup's fade-out, preserving their scanning, pairing, password,
    and action-feedback flows. Requests are routed through the existing bar
    components instead of duplicating their helper processes.
  - The audio details action opens the existing `AudioPopup`; volume and
    brightness sliders remain directly available in the combined panel.
  - Clicking the output-volume or microphone icon toggles PipeWire mute;
    dragging its slider still adjusts the corresponding level. Muted devices
    use the semantic error color, and unavailable devices remain non-interactive.
  - Active media uses `bar/QuickMediaPlayer.qml`, with MPRIS player selection,
    clipped blurred album art, artwork/album metadata, seeking, elapsed/total
    time, and transport controls. Seeking and time formatting use the shared
    `components/MediaSeekBar.qml` also used by `bar/MediaPopup.qml`.
  - The slider group controls output volume, microphone input volume, and
    brightness through their existing PipeWire and brightness state.
  - Clicking a live notification's main content invokes its default/Open action when available; archived snapshots have no app actions, but clicking can reopen their application through the saved desktop-entry ID using `gtk-launch`. Successful activation closes the popup. Notifications without an action or desktop-entry remain informational. The header's Clear All removes both live and archived entries.
  - Notification history uses `components/ScrollableList.qml` in its
    model/delegate mode, preserving virtualized notification cards while
    sharing conventional wheel handling and `ScrollBar.qml`. The optional
    footer keeps the final card clear of the popup edge. The model is detached
    after the popup closes, releasing delegates and avoiding background history
    grouping and image loading; it reconnects when the popup opens.

The toast overlay follows the same main-content click behavior. Notifications
without an action remain visible and do not launch an unrelated application.

Battery alerts no longer use the separate `battery-notify.service` or
`notify-send`. The UPower monitor is owned by Quickshell and runs once for the
shell, independent of monitor count. Connecting power dismisses stale low
battery alerts while preserving the short-lived “Carregador conectado” notice.
Power source changes and charge-limit restoration are handled by the system
unit `quickshell-power-source-policy.service`.

---

## 2. Visual Theme & Consistency Contract

The notification subsystem keeps the shell's adaptive glass palette while
using compact rounded rows with image and icon support: compact rounded
cards, relative time without an app-name label, concise title/body, and 40px
Soft UI action buttons revealed on hover. When a notification supplies a primary image, its app icon
overlays the image's lower-right corner, with its badge slot (24px in toasts, 20px in history) extending 6px
beyond both edges without clipping; otherwise the app icon occupies the
leading visual slot. This is a visual adaptation; the notification service and
quick-settings panel remain native to Quickshell.

| UI Element | Design Token / Value | Notes |
| :--- | :--- | :--- |
| **Popup Surface** | `theme.notificationBackground` (same as `theme.background`) | Notification surfaces share the global surface alpha; Hyprland caps it at 75%, while labwc keeps its readability floor because it has no blur. |
| **Outer Border** | `theme.glassBorder` (`rgba(255, 255, 255, 0.12)`) | Translucent glass perimeter rim |
| **Corner Radius** | `theme.radiusLg` (`16px`) | Softer notification-card corners inside the larger popup |
| **Notification Cards** | `theme.popupBackground` / `theme.glassCardSurface` | Toast and history surfaces retain adaptive compositor-aware glass |
| **Card Borders** | `theme.glassBorder` / `theme.adaptiveCardBorder` | Subtle perimeter; critical cards keep a red border |
| **Card Hover** | `theme.glassHoverSurface` / existing card hover token | Clear pointer feedback without changing the resting surface |
| **Action Buttons** | `theme.surfaceVariantForeground`, `theme.glassHoverSurface` | Compact text actions appear on hover with a 30px hit area |
| **Compositor Blur** | `surfaceFormat.opaque: false` | Enables native Hyprland window blur |

---

## 3. Interaction & Windowing Behavior

### 3.1 Modal & Dismissal Rules
- **Outside-Click Dismissal**: The popup uses `grabFocus: true`. Clicking anywhere on the screen outside the popup automatically closes it.
- **Pill Click Toggle**: Left-clicking the notification pill on the bar triggers `popup.toggle()`, opening it if closed and closing it if open.
- **Keyboard Dismissal**: Pressing `Escape` immediately dismisses the popup via `Shortcut`.
- Notification cards reveal their clear control and available actions on hover,
  keeping resting banners compact; clicking the main content still invokes the
  notification's default action.
- Swipe a card left in the history popup or toast overlay to slide it offscreen
  and dismiss it. A shorter drag returns the card to its original position.
  Dismissing from either surface also removes its stored history snapshot.
- **Header Ergonomics**: The header contains **no** redundant `✕` close button. Header space is dedicated to the semantic title, live notification counter, DND toggle pill, and Clear All button.
- The popup's history counter uses a neutral surface and secondary text so
  accumulated history does not compete with notification content.
- **Restore Shortcut**: `Ctrl+Shift+Space` restores one dismissed toast at a time, newest first; each press advances to the next older notification. New arrivals restart the sequence. The in-memory queue holds up to 20 entries for the current Quickshell session.

### 3.2 Scrollbar & Geometry Guarantees
- The history list follows the shell's conventional scroll direction. Mouse wheel
  notches use direct position steps, without momentum that can reverse direction.
- **Conventional Wheel Direction**: Standard scrolling (`angleDelta.y > 0` scrolls up towards top/newest items; `< 0` scrolls down).
- **Proportional Thumb & Track**: Stationary track clicks and direct thumb dragging allow precise navigation.
- **Default Viewport Capacity**: History grows up to 340px; further history stays scrollable.
- **Last Item Guarantee**: The list view terminates with a bottom spacer sized
  by the shared `spacingTokens.md` token and explicit parent-child
  `implicitHeight` sizing so the last card is not clipped by the popup frame.

### 3.3 Text Sanitization & Entity Decoding
- Notification summaries and bodies are sanitized via `NotificationState.formatText()`:
  - HTML entities (`&quot;`, `&amp;`, `&lt;`, `&gt;`, `&#39;`, `&#x27;`, decimal/hex codes) are decoded to proper UTF-8 characters (e.g. quotes in Telegram messages).
  - `<br>` / `<br/>` tags are converted to real newline characters (`\n`).
  - Formatting tags (`<b>`, `<i>`, `<span>`, `<a>`, etc.) are stripped cleanly.

### 3.4 Battery Alert Dismissal

When UPower reports that external power is connected, stale low-battery
notifications are removed from history and any matching active toast fades out.
This also handles a critical battery toast, which otherwise has no automatic
timeout, and applies when Quickshell starts while already charging.

### 3.5 App groups in history

History groups all notifications from one application together, including
every chat and personal conversation from messaging apps. Groups follow the
newest notification's order, retain newest-first ordering inside each group,
and start collapsed with the newest card visible. The app header shows the total,
toggles expansion by click, Tab + Enter/Space, or Left/Right, and has a separate
action to dismiss every live and archived notification in that app group. Single
notifications have no extra header. Expansion is local to the popup instance.
Group dismissal removes archived rows in one storage transaction and queues live
dismissals in small timed batches so large groups do not stall the popup.
Live notifications continue using the original objects and service; archived
entries render from stored snapshots and have no application actions. The
flattened grouped model keeps the existing virtualized scrolling list. First/last
row markers join expanded messages into one continuous app surface, with spacing
only between apps. Headers and message text share a fixed leading column; history
titles allow two lines and secondary text uses the subtitle size. Individual
messages retain their swipe dismissal and hover actions. The compact media player
uses a single-line app selector and hides seeking/time labels when duration is
unknown.

### Performance verification — 26/10/2026

The 15:57 crash occurred in Qt's render thread; these changes reduce notification
work and image allocations but do not establish or fix the native crash's root
cause. The service's 1.8GB peak includes child processes, not just QuickShell:
a subsequent host measurement found QuickShell at 187724 KiB RSS with Electron
children in the same service cgroup. Compare process RSS/PSS separately from
systemd service memory when investigating future growth.

Keyed toast rendering loaded in the live shell and was inspected with a local
test notification alongside an incoming Telegram notification. The history popup was also inspected after detaching its hidden model
(`/tmp/quickshell-notification-history-check.png`). Validation: 25 OK, 4 WARN,
0 FAIL, including 102 QML behavior tests and all Python unit tests. Warnings
concern sandbox access to NetworkManager/Bluetooth/IPC and the printer scheduler;
the final history-model change passed targeted qmllint and live reload.
Long-duration memory and frame-time measurements remain pending.
