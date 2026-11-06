# Compositor integration contract

The shell keeps presentation and compositor transport on separate sides of a
small capability boundary. Prefer a Wayland protocol when it exposes the
needed operation. Use a compositor adapter only for compositor concepts that
have no protocol contract.

## Shared Wayland protocols

Hyprland and Mango prefer their native APIs. labwc uses Quickshell's generic
protocol-backed APIs directly. Those generic APIs remain fallbacks where
appropriate:

- `WindowManager` uses `ext-workspace-v1` for workspace/tag listing and
  activation. Each bar scopes the model through `screenProjection(screen)` so
  output-specific workspaces remain attached to that output. Hyprland uses its
  native workspace model first, and Mango uses `mmsg` first; each can fall back
  to the generic protocol when its native state is unavailable. Workspace
  labels come from the compositor's workspace names and IDs.
- The Hyprland workspace strip considers both tracked toplevels and the
  compositor's `j/workspaces` window count. Hyprland's `openwindow` event may
  identify a renamed workspace by its numeric name while Quickshell tracks its
  display name, so the bar refreshes the workspace snapshot after window
  open/close/move events to keep occupied pills accurate.
- `ToplevelManager` uses `zwlr-foreign-toplevel-management-v1` for listing,
  activation, and close requests in Spotlight's `~` mode outside Hyprland.
  Hyprland uses its native client metadata first, including workspace names.
- The `!` process-kill mode uses Hyprland PID data because the foreign-toplevel
  protocol does not expose process IDs. Other compositors provide protocol
  close requests in that mode.

## Mango

Quickshell's Wayland surfaces and the foreign-toplevel protocol provide the
bar, OSD, notifications, and Spotlight's window list/activation/close behavior.
Mango tag state is not exposed through Quickshell's generic workspace model,
so `services/MangoState.qml` owns one `mmsg watch all-tags` stream and
`services/MangoWorkspace.js` converts its JSON snapshots into the shell's
normalized output/tag contract. QML surfaces do not parse Mango JSON or call
`mmsg` directly. `scripts/compositor-dispatch.sh` owns tag activation through
`viewcrossmon`, including the output associated with each bar.

The native adapter is selected from `XDG_CURRENT_DESKTOP=mango`; its IPC
connection additionally requires `MANGO_INSTANCE_SIGNATURE`. The Mango
session startup helper imports this variable into the user systemd manager
before starting `quickshell.service`. Missing IPC makes the tag strip empty
instead of drawing controls that cannot work.

Mango tags use `ext-workspace-v1` through `WindowManager` when the compositor
advertises usable windowsets. The normalized `mmsg` snapshot remains a
compatibility fallback for Mango versions or sessions without that protocol;
tag activation then stays behind `scripts/compositor-dispatch.sh`. The
Hyprland-only modal submap indicator queries its state through the same
adapter, keeping compositor commands out of QML. Spotlight's `~` window list
uses `ToplevelManager`; Mango-specific workspace/tag metadata
is not added to Spotlight results in this phase. The session action adapter
uses `mmsg dispatch quit` for logout and `hyprlock` for locking.

## Capability matrix

| Capability | Hyprland | labwc | Mango |
| --- | --- | --- | --- |
| Layer surfaces, popups, notifications | Wayland / Quickshell | Wayland / Quickshell | Wayland / Quickshell |
| Workspace/tag list and activation | Hyprland API, `ext-workspace-v1` fallback | `ext-workspace-v1`, keyboard fallback | Mango IPC, `ext-workspace-v1` fallback |
| Spotlight window list and actions | Hyprland client API, Wayland toplevel fallback | Wayland toplevels | Wayland toplevels |
| Focused-monitor OSD placement | Quickshell Hyprland API | all outputs if no focused-output API | Mango tag snapshot output state |
| Display projection (`SUPER+P`) | Hyprland Lua monitor API | unavailable | unavailable |
| Modal submap indicator | Hyprland-only | unavailable | unavailable |
| Window recording geometry | Hyprland client geometry | manual `slurp` selection | manual `slurp` selection |
| Compositor logout | Hyprland dispatcher | `labwc --exit` | Mango `mmsg` dispatcher |

The Mango support level should be verified in a live Mango session: Quickshell
parsing and mock IPC tests cannot verify the compositor's protocol behavior,
output names, or user-systemd environment. Keep these runtime checks separate
from protocol-independent unit tests.

Display projection is currently Hyprland-only. The QuickShell panel offers
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

When another compositor is added, check the required Wayland protocols first.
Add a backend only for capabilities the protocols do not provide, normalize
its data at the adapter boundary, and keep UI consumers on that normalized
shape. Do not select a backend merely because its executable is installed.
