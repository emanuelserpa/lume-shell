# Compositor integration contract

The shared workspace path and compositor-safe Hyprland dispatch have an initial
implementation. See the [migration plan](wayland-backend-plan.md) for remaining
work and the [upstream protocol research](wayland-compositor-research.md) for
version and capability evidence.

The shell keeps presentation and compositor transport on separate sides of a
small capability boundary. Prefer a Wayland protocol when it exposes the
needed operation. Use a compositor adapter only for compositor concepts that
have no protocol contract.

`LUME_COMPOSITOR_MODE` selects providers for workspaces and windows: `auto`
uses native Hyprland metadata in Hyprland and generic protocols elsewhere;
`wayland` forces generic providers; `hyprland` requires a Hyprland session.
It does not replace session-specific logout, lock, theme, or screenshot tools.
See [generic Wayland installation](wayland-install.md).

## Shared Wayland protocols

The generic Quickshell providers are the main path for workspaces and window
lists on Sway, niri, Mango and labwc, plus any other compositor exposing the
same protocols. Hyprland retains its native workspace/client metadata where it
provides useful occupancy, PID and workspace details.

- `WindowManager` uses `ext-workspace-v1` for workspace/tag listing and
  activation. Each bar scopes the model through `screenProjection(screen)` so
  output-specific workspaces remain attached to that output. Generic windowset
  names are preserved; the UI does not invent a numbered desktop list.
- The Hyprland workspace strip considers both tracked toplevels and the
  compositor's `j/workspaces` window count. Hyprland's `openwindow` event may
  identify a renamed workspace by its numeric name while Quickshell tracks its
  display name, so the bar refreshes the workspace snapshot after window
  open/close/move events to keep occupied pills accurate.
- `ToplevelManager` uses `zwlr-foreign-toplevel-management-v1` for listing,
  activation, and close requests in Spotlight's `~` mode. Hyprland uses its
  native client metadata first, with protocol window objects as fallback.
- The `!` process-kill mode uses Hyprland PID data because the foreign-toplevel
  protocol does not expose process IDs. Other compositors provide protocol
  close requests in that mode.

## Compatibility adapters

Mango's workspace dispatcher is a compatibility fallback for sessions where
Quickshell receives no ordinary `ext-workspace-v1` windowsets. The watcher also
supplies focused-output state, which `ext-workspace-v1` does not provide, so
it remains active in Mango `auto` mode. Mango's special overview entry remains
represented by the native snapshot behavior. When ordinary protocol windowsets
are present, the bar uses the same `Windowset.activate()` operation as other
generic sessions.

labwc's `wtype` desktop shortcut remains in the dispatcher for older or
explicitly configured sessions, but current workspace UI does not synthesize
ten desktops when the protocol is absent. Sway IPC, niri IPC, and Mango IPC are
not required for common workspace and toplevel actions.

The Hyprland-only modal submap indicator queries its state through the
dispatcher. Its native client provider remains useful for PID and workspace
metadata. The session action adapter uses compositor-specific commands for
logout and lock because those actions have no shared desktop-control protocol.

## Mango adapter details

In Mango `auto` mode, `services/MangoState.qml` owns one
`mmsg watch all-monitors` stream and `services/MangoWorkspace.js` converts its
JSON snapshots into the shell's normalized output/tag contract. The stream
provides focused-output state even when the shared workspace protocol works;
the bar uses its workspace snapshot only when no generic windowsets are
available. QML surfaces do not parse Mango JSON or call `mmsg` directly. The
dispatcher owns fallback tag activation through `viewcrossmon`, including the
output associated with each bar.

The native adapter is selected from `XDG_CURRENT_DESKTOP=mango`; its IPC
connection additionally requires `MANGO_INSTANCE_SIGNATURE`. The Mango
session startup helper imports this variable into the user systemd manager
before starting `quickshell.service`. Missing IPC does not disable protocol
workspaces; it removes Mango's focused-output information and workspace
fallback, so generic OSD/bar placement uses the first screen when needed.

Without the IPC signature, generic workspaces still work when advertised, but
focused-output placement falls back to the first screen. Mango-specific layout,
overview and multi-tag semantics still need live-session validation. The
session action adapter uses `mmsg dispatch quit` for logout and `hyprlock` for
locking.

## Capability matrix

| Capability | Hyprland | Sway | niri | Mango | labwc | dwl upstream |
| --- | --- | --- | --- | --- | --- | --- |
| Layer surfaces, popups, notifications | Wayland / Quickshell | Wayland / Quickshell | Wayland / Quickshell | Wayland / Quickshell | Wayland / Quickshell | Wayland / Quickshell |
| Workspace list and activation | Native model; protocol where available | `ext-workspace-v1` (1.12+) | `ext-workspace-v1` (25.08+) | `ext-workspace-v1` | `ext-workspace-v1` | Native build-specific integration required |
| Window list, activate and close | Native metadata + protocol fallback | `wlr-foreign-toplevel-management` | `wlr-foreign-toplevel-management` | `wlr-foreign-toplevel-management` | `wlr-foreign-toplevel-management` | `ext-foreign-toplevel-list` provides listing; control not confirmed |
| Focused-monitor OSD placement | Quickshell Hyprland API | first output | first output | Mango IPC in auto mode | first output | first output |
| Display projection (`SUPER+P`) | Hyprland Lua monitor API | Not integrated | Not integrated | Not integrated | Not integrated | Not integrated |
| Modal submap indicator | Hyprland-only | Unavailable | Unavailable | Unavailable | Unavailable | Unavailable |

Protocol availability is versioned. The table describes upstream versions
checked in `wayland-compositor-research.md`, not a guarantee for older releases
or patched builds. Mango's multi-tag/overview semantics and all compositor
sessions still require live validation before claiming full support.

Display projection is currently Hyprland-only. Quickshell 0.3.x exposes no
output-configuration object in the installed QML API; implementing generic
output management needs a separate adapter and per-compositor live validation.
Do not present `wlr-output-management` as equivalent to Hyprland's complete
duplicate/extend modes. The QuickShell panel offers
computer-only, duplicate, extend, and external-only layouts. It queries
`hyprctl -j monitors all`, captures the current output layout in XDG state for
the active Hyprland instance, then dispatches mode changes through
`scripts/compositor-dispatch.sh` to the native `hl.monitor()` Lua API using
`hyprctl eval`. “Extend” restores the captured
layout. `SUPER+SHIFT+P` retains the former pseudo-tile action. Mango and labwc
do not expose this panel until their output-management behavior has an
equivalent tested backend.

Clamshell (lid switch) is Hyprland-only and lives outside the shell, in
`~/.config/hypr/hyprland.lua` + `~/.config/hypr/scripts/clamshell.sh`.
The binds use dispatcher-direct form (`hl.dsp.exec_cmd`, no `function()`
wrapper) and must stay after all `hl.monitor` blocks, otherwise the Lua
switch bind never fires. Behavior: lid close with an external output
disables `eDP-1` and moves the external to `0x0` so layer surfaces follow;
lid close with no external runs `systemctl suspend` (systemd-logind never
handles the lid while Hyprland holds the `handle-lid-switch` lock — see
`logind.conf(5)`); lid open restores the `eDP-1` + `1920x0` layout.
Animations are paused only for the transition. External detection reads
DRM connector status, not `hyprctl`, to avoid acting on a just-unplugged
output. Opening `SUPER+P` during clamshell refreshes the projection
baseline from the live layout.

## Extending the boundary

When another compositor is added, try the shared Quickshell protocol APIs
first. Add a narrow adapter only for a capability or version gap that has been
reproduced. Select session commands from session identity, never merely because
an executable is installed.
