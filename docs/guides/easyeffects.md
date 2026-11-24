# EasyEffects

The audio mixer includes quick controls backed by the EasyEffects documented
local Unix socket. `services/EasyEffectsState.qml` owns status polling and UI
actions; `scripts/easyeffects-control.py` translates the socket protocol into
JSON. The socket is queried only while `AudioPopup` is open, every 15 seconds,
and once after an action. Socket access and actions have a two-second timeout.

The mixer displays the current input and output presets, cycles the available
presets in each pipeline, toggles global bypass, and opens the EasyEffects
window for full editing below the primary PipeWire output, app-stream, and
microphone sections. Preset names are discovered from the user's existing
`~/.local/share/easyeffects/{input,output}` files. Names are validated against
those files before being sent to the socket. Existing device-based autoload
rules remain owned by EasyEffects; the shell observes the resulting active
preset. If the daemon is unavailable, the mixer collapses the section to a
single compact status row (with tap-to-open) and preserves all PipeWire volume,
mute, and device controls.

The mixer uses `ScrollableList` to size itself to its content up to the
available screen height. When many application streams or devices make it taller,
the content area scrolls with a single scrollbar instead of nested fixed-height
lists or drawing over windows behind it. Backend
error details stay compact in the panel; the unavailable state is already
identified by the EasyEffects status row.

The active installation uses EasyEffects 8.3.0. Protocol reference:
[Local Server](https://wwmm.github.io/easyeffects/user_interface/local_server.html),
[Creating and Importing User Presets](https://wwmm.github.io/easyeffects/user_interface/userpresets.html).
