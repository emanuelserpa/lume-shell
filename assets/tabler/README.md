# Tabler icons

`device-desktop.svg`, `thermometer.svg`, `bolt.svg`, and `search.svg` are from the Tabler
Icons outline set: https://github.com/tabler/tabler-icons/tree/main/icons/outline

Their stroke color was changed to white so Quickshell's `MultiEffect` can tint
them from the active shell theme. Tabler Icons are licensed under MIT; see
`LICENSE`.

Files prefixed `bar-` are original project drawings, not Tabler assets. They
share a 24-unit view box, 2-unit rounded strokes, and white source ink for the
existing theme tint renderer. The bar uses `Theme.barIconSize` (16 logical px)
for consistent alignment; play/pause use filled silhouettes at the same size.

The shared dashboard also uses `dashboard-*.svg` for its calendar navigation,
location, city actions, weather metrics and forecast conditions. Their stroke
and theme-tint contract matches the `bar-` drawings.

`battery.svg`, `clock.svg`, and `cpu.svg` are local outline drawings used by
the battery detail popup. They use the same 24-unit view box and theme-tint
contract.

`memory.svg` and `fan.svg` are local outline drawings for the system monitor
popup; `dashboard-thermometer.svg` supplies its temperature row.

`bar-cpu.svg` is the compact CPU indicator used in the top bar.

The network detail popup uses `network-*.svg` for speed test, QR, transfer,
password visibility, and password re-entry actions. Existing `bar-wifi-*`,
`bar-ethernet`, and `bar-lock` drawings identify connection state and security;
`network-shield.svg` identifies WireGuard.

Additional outline drawings (`bluetooth.svg`, `bluetooth-off.svg`, `microphone.svg`,
`microphone-off.svg`, `headphones.svg`, `mouse.svg`, `device-mobile.svg`, `package.svg`,
`power.svg`, `logout.svg`, `bell.svg`, `bell-off.svg`, `close.svg`) unify the remaining
detail popups, quick controls, and notification center under the same 24-unit stroke-2
vector icon contract.
