# Network Module

## Architecture

Quickshell UI -> helper scripts -> `nmcli` -> NetworkManager.

This architecture is intentionally pragmatic.

## Secret handling

Wi-Fi passwords are not passed via command-line argv. Manual password entry,
QR generation, and copy actions send sensitive text to helpers via stdin.
The generated QR image is stored with mode `0600` inside a mode `0700`
directory under `XDG_RUNTIME_DIR`, with a system temporary directory fallback.
It can contain the Wi-Fi password, so exclude it from shared archives.

Selecting a protected Wi-Fi network
opens Quickshell's password dialog, which sends the password to
`nmcli --ask` on stdin.

## Features

- Wi-Fi state & active connection telemetry;
- Wi-Fi list with signal strength and security indicators;
- The connected Wi-Fi row uses a subtle surface border; connection state is
  communicated by its tonal background and primary-colored icon and label.
- Connect/disconnect and a compact password dialog for protected networks;
- Row taps are handled in `interactionHandlers` (never in default content,
  which `PopupListRow` hides under the standard layout);
- Saved secure networks show a key action that re-opens the password dialog:
  typing a new password clears the stale stored secret first (empty value,
  never argv) and `nmcli --ask connection up` reads the replacement over
  stdin, so a changed Wi-Fi password can be updated without deleting the
  profile;
- Wi-Fi radio toggle;
- VPN/WireGuard state and toggle;
- a compact green lock overlays the lower-right corner of the network icon
  while one or more VPNs are active, matching the GNOME/NetworkManager
  indicator; the tooltip names active VPNs, and clicking the indicator opens
  the network popup from its stable bar anchor;
- The VPN switch sends its requested on/off state to the helper; repeating an
  already-satisfied state is treated as success so a stale status refresh does
  not show an activation error for a VPN that is already connected.
- Built-in live Speedtest (latency ping, download, upload throughput with progress);
- Wi-Fi QR Code sharing with toggleable password visibility;
- QR sharing reads the actual SSID and security key from the active connection
  UUID, escapes reserved QR payload characters, and fails with an inline error
  when NetworkManager cannot provide the required values or the security mode
  is unsupported;
- Contextual activity, inline errors, and captive portal detection.
- Busy state, contextual error target, and timed error dismissal use the shared
  `ActionFeedback.qml`; Wi-Fi input and action process handling remain local to
  the network module.
- The title, connection status, and leading icon layout use
  `components/PopupHeader.qml`; theme-tinted local vector icons identify Wi-Fi
  signal, Ethernet, security, search, transfer, QR, and speed-test actions.
  The network module owns its speedtest, QR, settings, and Wi-Fi controls.
- The popup keeps one outer `PopupCard`. Clickable network/VPN rows preserve
  their active and hover surfaces; the captive-portal notice, telemetry, speed
  test, and QR sharing keep only the grouping surfaces needed for those tasks.
- Wi-Fi and VPN rows share `components/PopupListRow.qml` for their active and
  hover surfaces; each network type retains its own content and action logic.
- The no-networks message uses the shared `components/EmptyState.qml` layout.
- Network and ping status consumers read the normalized `CommandJson.result.data`
  object; action helpers keep their local lifecycle because Wi-Fi credentials
  flow over stdin and each action has target-specific feedback.
- When four or more Wi-Fi networks are available, a debounced search filters
  the displayed list by SSID without requesting another scan.
  The field uses themed text/selection colors, vertically centered Noto Sans,
  a search icon, and a clear action. It stays visible while text is entered,
  even if a status refresh reduces the number of networks below four.

## Scanning rule

Do not continuously rescan Wi-Fi.

Normal state polling should be cheap.

Actual radio scan should happen only when useful:
- popup open;
- explicit refresh;
- relevant action while popup is open.

## Placement

Network appears after Tray in the right-side bar order.

This is a user preference and should be preserved.

`Network.qml` is mounted as an autonomous bar component immediately after `Tray` in
the right island (just like `Audio.qml`), rendering its own Tabler SVG `Pill` and
anchoring `NetworkPopup` directly to its bar indicator. Left click toggles
`NetworkPopup`, middle click toggles the Wi‑Fi radio, and right click refreshes
network state and scans. Scanning, saved-network selection, password entry, VPN
actions, and feedback remain owned by the network module.

## Error presentation

Prefer:
- per-row `Conectando…`
- `Desconectando…`
- contextual error in the network row or password dialog
- auto-clear after a short delay

Avoid raw command output in the UI.

## Architecture comparison note

A read-only comparison was made against the Quickshell 0.3.2
`Quickshell.Networking` API. It can expose NetworkManager device/network state,
Wi-Fi enabled state, signal strength, saved profiles, and connectivity status.
That is enough to prototype the basic connected-network and Wi-Fi list state.

It does not currently cover the full data contract consumed by this popup:
per-device IP and traffic counters, frequency, the existing explicit scan
behavior, VPN profile actions/state, and captive-portal workflow need additional
sources or actions. In particular, `WifiNetwork.connectWithPsk()` is not a drop-in
replacement for the established secret flow: keep Wi-Fi passwords in the shell
dialog and send them to `nmcli --ask` via stdin. Do not pass a PSK to the native
API as part of this read-only evaluation.

Conclusion: native state is a viable future source for a limited subset, but
replacing the helper now would create a split backend and would not remove the
network helper dependency. Keep the current implementation until a specific
field or reliability issue justifies a parity-tested migration. No native API
object is mounted in the active shell, and this evaluation does not enable Wi-Fi
scanning or trigger connectivity checks.
