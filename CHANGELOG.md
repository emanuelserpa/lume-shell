# Changelog

The numbered entries below record functional milestones; they are not the
package version. Public package releases are defined by Git tags.

## Unreleased

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
