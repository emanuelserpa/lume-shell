# Phone Module (KDE Connect)

Basic-scope client for KDE Connect. Not a GSConnect copy: GSConnect is a
GNOME Shell (GJS) protocol implementation; here `kdeconnect` is the backend
and Quickshell only provides the bar pill + popup.

## Components

- `bar/Phone.qml` — pill, polling, action runner.
- `bar/PhonePopup.qml` — shared popup header, device list, ping/ring/pair, share text/file.
- `scripts/kdeconnect-status.py` — `kdeconnect-cli -l` + `-a --id-only`,
  best-effort battery via `gdbus` (`org.kde.kdeconnect.device.battery`).
- `scripts/kdeconnect-action.py` — refresh/ping/ring/pair/unpair/share-text/share.
- Both scripts use `scripts/command_utils.py` for consistent timeouts and
  subprocess error results.
- The status helper's versioned envelope is normalized by `CommandJson.result`
  before the bar and popup read device data.

## Bar behavior

- Hidden when `kdeconnect-cli` is not installed (`visible: false`).
- Grey phone when nothing reachable; green when ≥1 reachable.
- Left click → popup; middle click → ping first reachable. The popup header
  gear opens the KDE Connect settings.

## Popup behavior

- Sections: Alcançáveis / Offline.
- Per reachable device: Ping, Tocar (ring), Arquivo (FileDialog), Parear (if unpaired).
- Offline paired devices: Esquecer (unpair).
- Footer: share text to the selected reachable device (Enter or Enviar).
- The share input uses the shared `components/SearchField.qml` TextInput base;
  Enter and the Enviar button keep the same send behavior.
- The bar uses the shared `ActionFeedback.qml` for busy state, target-specific
  errors, and timed dismissal.

## Backend

Requires same-network pairing via the Android/iOS KDE Connect app:

```bash
sudo pacman -S kdeconnect
kdeconnect-cli --refresh
kdeconnect-cli -l
```

Battery has no `kdeconnect-cli --battery` flag on current KDE; unknown
renders as no percentage (`battery: -1`).

## Scope limits (basic)

No SMS, notification mirroring, clipboard sync, remote commands, or SFTP
mount. Those need D-Bus surface work and are intentionally out of v1.

## Avoid

- Do not reimplement the KDE Connect protocol in QML.
- Do not poll faster than 5s open / 15s closed.
- Do not block actions on battery lookups.
