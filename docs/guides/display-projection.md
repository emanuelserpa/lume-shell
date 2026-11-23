# Display projection

`SUPER+P` opens a Windows-style projection picker in the Hyprland session.
Choose among:

- **Somente tela do computador**: keep the built-in panel and turn off other
  connected monitors.
- **Duplicar**: mirror every other connected output to the built-in panel.
- **Estender**: restore the output modes, positions, scale, transform, and VRR
  captured from the current Hyprland session.
- **Somente segunda tela**: keep an external output and turn off the built-in
  panel.

The picker supports pointer selection, Up/Down, Enter, and Escape. `SUPER+P`
replaced the previous pseudo-tile binding; that action remains on
`SUPER+SHIFT+P`.

## Backend and state

`DisplayProjectionPopup.qml` is a view over `DisplayProjectionState.qml`.
The service talks to `scripts/display-projection.py` through the shared
`CommandJson` and `CommandAction` components. The helper reads connected and
inactive outputs from `hyprctl -j monitors all` and applies monitor rules via
Hyprland's Lua `hl.monitor()` API. It never writes the tracked monitor config.

The first status read captures the active layout under
`$XDG_STATE_HOME/quickshell/display-projection.json` (or
`~/.local/state/quickshell/display-projection.json`) with the active
`HYPRLAND_INSTANCE_SIGNATURE`. Choosing **Estender** restores that snapshot;
starting a new Hyprland instance captures a fresh baseline. A newly connected
output is added to the baseline on its first status read.

Hyprland's monitor JSON reports whether VRR is active as a boolean, while
`hl.monitor()` takes the configured VRR policy as an integer. The helper never
replays the runtime boolean; it preserves an explicit integer policy from
`hyprland.lua` and checks the text response from every `hyprctl eval` call.

Mango and labwc are not exposed as supported backends yet. Their monitor APIs
and profile behavior differ, and the picker stays unavailable in those
sessions. See `compositor-integration.md` for the capability matrix.

## Validation

`tests/test_display_projection.py` verifies mode availability, monitor
selection, layout restoration, mirror target mapping, and safe Lua string
escaping without changing live monitor state.
