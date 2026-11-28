# Changelog

The numbered entries below record functional milestones; they are not the
package version. Public package releases are defined by Git tags.

## 0.2.4

- Prevent `QSGRenderThread` segfaults (`QQuickItemGrabResult` /
  `QObjectPrivate::ConnectionData::cleanOrphanedConnectionsImpl`) during
  notification image archiving by replacing `grabToImage()` on transient
  `MultiEffect` cards with a serialized, persistent `Canvas` archiver
  (`components/NotificationImageArchiver.qml` mounted in `bar/Bar.qml`),
  queuing `image://qsimage/` captures directly in `NotificationState.qml`
  and guaranteeing notification retention release on both success and failure
  (#27).

## 0.2.3

- Cap notification history and active `NotificationServer` tracking at 20 items
  per app group (`MAX_PER_APP = 20` in `scripts/notification_store.py`,
  `NotificationContent.capByGroup()`, and `NotificationState.qml`) so noisy chat
  apps cannot evict other apps' alerts or bloat long-running sessions (#26).
- Fix UI-thread freezes during rapid notification bursts by adding a
  no-HTML/entity fast-path to `NotificationContent.formatText()`, unifying
  per-notification filtering/battery/fingerprint computation into a
  bounded Map-cached `trackedMetadata()` pass in `services/NotificationContent.js`
  and `services/NotificationState.qml`, and coercing action-row visibility to a
  strict boolean in `components/NotificationCardContent.qml` (#25).

## 0.2.2

- Standardize all Lume-owned XDG config, state, data, cache, and private runtime
  paths on `lume-shell` (replacing legacy `quickshell` and `lumeshell`
  directories), centralized in `services/ShellPaths.qml` and
  `scripts/lume_paths.py` (#24).
- Add automatic, idempotent startup migration (`scripts/migrate-paths.py` and
  `lume_paths.migrate_all()`) that preserves Quickshell's own runtime caches,
  updates archived notification image paths in SQLite, upgrades legacy Kitty
  theme blocks in place, and maintains a compatibility symlink at
  `~/.local/state/quickshell/current_palette.json` for downstream design-system
  consumers.

## 0.2.1

- Simplify `docs/architecture.md` in Portuguese with a Mermaid overview diagram
  and replace the 5 separate PlantUML files under `docs/uml/` that duplicated
  component inventories.
- Harden compositor dispatching, geolocation, and weather state handling (#21):
  - Validate Hyprland workspace selectors and window addresses in
    `scripts/compositor-dispatch.sh` before building Lua/fallback `hyprctl` calls.
  - Migrate IP geolocation in `scripts/weather-fetch.py` and
    `scripts/nightlight-manager.py` to HTTPS with coordinate validation and
    opt-out support (`auto_location: false` / `LUME_WEATHER_DISABLE_AUTO_GEO=1`).
  - Escape external values in weather HTML tooltips with `html.escape()`,
    validate `cities`/`selected`/IDs/coordinates across weather state and CLI
    helpers, add regression tests, and gate `.github/workflows/release-arch-package.yml`
    on automated validation.
- Remove the redundant embedded `QuickMediaPlayer` from `bar/NotificationPopup.qml`.

## 0.2.0

- Isolate Spotlight desktop app launches in their own `systemd-run --user --scope --slice=app.slice`
  cgroup via `gtk-launch`.
- Redesign `bar/AudioPopup.qml` so the primary output volume sits at the top,
  unify output/microphone endpoint cards with light-theme-safe `surfaceForeground`
  contrast and a clickable reset-to-100% boost pill, replace fixed 76 px nested
  device scrollboxes with dynamic selectors inside a single `ScrollableList`, and
  collapse unavailable EasyEffects controls to a compact action row at the bottom.

## 0.1.5

- Mark the 100% limit and 100–150% boost zone on the volume/microphone OSD, and
  add a 4-tick scroll detent at 100% across the Quick Settings sliders, bar audio
  pill, and lockscreen island before entering volume amplification.
- Add an `Ultra Eco` (`extra-low-power`) battery profile below `Economia` that
  combines `low-power` / `power-saver`, boost off, and a 1.6 GHz `schedutil`
  CPU frequency cap via a passwordless Polkit helper, automatically activates
  while discharging at `<= 15%` (switching cleanly to `balanced` on AC), and
  displays a leaf badge next to the bar battery indicator when active.
- Fix a Quickshell `KIconLoader` crash when opening the notification history by
  keeping `image://icon/` notification icon loads on the GUI thread, checking
  icon availability via `Quickshell.iconPath(name, true)`, and hiding the
  fallback `PopupListRow` glyph once `leadingImage` is ready.
- Mark 100% and shade the 100–150% boost region on audio sliders (`SliderRow`),
  keeping pointer drag aligned 1:1 within 0–100% while wheel/touchpad scroll
  pauses at 100% and unlocks boost up to 150% with aligned Quick Settings
  readouts.
- Poll network connectivity reliably while `NetworkPopup` is open, fall back from
  ICMP ping to NetworkManager connectivity and TCP latency probes when ICMP is
  blocked, and surface captive portals explicitly instead of mislabeling networks
  as offline.
- Use crisp monochrome Tabler SVG icons across Spotlight (`:`), actions (`Ctrl+K`),
  result rows, and clipboard thumbnails, bind `Spotlight` emoji cells to the color
  emoji font (filtering standalone skin-tone modifiers), and prevent stale extra
  list-model rows or circular fallback glyphs when filtering app categories.
- Replace internal notifications with matching `replaceKey` in place (avoiding
  stacked duplicate low/critical battery toasts), include active internal
  critical alerts in `NotificationControl`, switch `NotificationControl` to
  `bell`/`bell-off` icons, and highlight critical battery levels (`<= 15%`).
- Move the Spotlight clipboard capture pause/resume control to the mode header
  with an explicit paused banner, keep the preview header scoped to item
  metadata and removal, and add `"Copiado ✓"` feedback for stay-open copies.
- Fix Spotlight `Ctrl+Enter` (including keypad Enter and inside `Ctrl+K`
  actions), action-panel shortcut delivery when preview text had focus,
  subroute `Esc`/`Backspace` back-navigation in `:`, scrollable action panels,
  and agnostic terminal (`open-terminal.sh`), shell restart
  (`restart-shell.sh`), and live stop-recording actions.
- Stabilize Spotlight clipboard list selection across asynchronous refreshes,
  thumbnail loading, and item deletion, and remove the repeated “updating”
  label from cached rows.
- Fix redundant `chmod` metadata writes on `clipboard-change` so Quickshell's
  `FileView` does not loop refreshes and cancel clipboard thumbnail loading.
- Reduce idle screen-recording status checks from every 5 seconds to every 15;
  checks remain every 2 seconds while recording.
- Launch apps reopened from archived notifications in their own systemd app
  scope so they do not inflate Lume's service resource accounting.
- Slow background CPU and printer status probes while their popups are closed
  or the printer queue is idle; opening either popup refreshes its data.
- Add player selection by dots and wheel to the media island and popup, with a
  subtle playback pulse for non-selected players that are playing.
- Resolve themed tray and context-menu icons to file paths before rendering,
  avoiding the Quickshell icon-pixmap provider path involved in the crash.

## 0.1.3

- Bound notification image storage and in-memory image references, keeping
  notification text when old images are evicted.
- Make clipboard-derived cache files private and atomically replaced, and keep
  the installed shell from watching package files during upgrades.
- Give JSON query helpers a process-group timeout and a 64 KiB output cap.

## 0.1.2

- Add an optional ReGreet integration that follows the active wallpaper and
  Chameleon palette without changing the login manager configuration on install.
- Refresh the lock screen clock after system resume and recover its fingerprint
  reader when logind reports that the system has resumed.
- Improve AUR update checks with encoded, batched RPC requests and clear network
  error reporting.
- Remove the unreliable `hyprshutdown` path from session power actions.

## Pre-0.1.2 baseline

- Workspace labels now come from the compositor; Hyprland users can set them
  with workspace rules. The bar shows the active workspace and occupied ones,
  while the former icon map remains only as an example.
- Restored the NetworkManager connection editor action and hide its standalone
  applet icon when the shell tray already provides network controls.
- Native Wayland clipboard history using `wl-clipboard`, SQLite, and local
  image storage.
- Spotlight clipboard search, preview, restore, and stable item deletion.
- Multi-city weather, dynamic themes, native notifications, and quick settings.
