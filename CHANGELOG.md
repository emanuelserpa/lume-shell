# Changelog

The numbered entries below record functional milestones; they are not the
package version. Public package releases are defined by Git tags.

## Unreleased

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

- Workspace labels now come from the compositor; Hyprland users can set them
  with workspace rules. The bar shows the active workspace and occupied ones,
  while the former icon map remains only as an example.
- Restored the NetworkManager connection editor action and hide its standalone
  applet icon when the shell tray already provides network controls.

## 1.2.0

- Native Wayland clipboard history using `wl-clipboard`, SQLite, and local
  image storage.
- Spotlight clipboard search, preview, restore, and stable item deletion.
- Multi-city weather, dynamic themes, native notifications, and quick settings.
