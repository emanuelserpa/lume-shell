# Screen recording

The **Gravar tela** `QuickTile` in Quick Settings (`bar/NotificationPopup.qml`)
opens `ScreenRecordingPopup` to choose one of the three recording modes. During
an active recording, the indicator appears in `StatusIsland` (`bar/StatusIsland.qml`)
as a red capsule with its live tabular elapsed counter (switching to the audio
icon variant when sound is being captured), where clicking it or the active
`QuickTile` stops the capture immediately:

- **Window:** click a visible window through `slurp`'s predefined rectangles on Hyprland; select its area manually on labwc or Mango.
- **Full screen:** record the focused Hyprland monitor, or select an output on labwc or Mango.
- **Selection:** drag a region with `slurp`.

`scripts/screen-recording.py` starts `wf-recorder` and returns JSON to QML.
Its status and action output are normalized through `CommandJson.result` and
`CommandResult.js`; status-helper failures expose the popup and remain visible
in the bar until the user opens the error message.
The active process and output path are stored in a private runtime state file,
so the pill can recover its recording indicator after a Quickshell reload.
Stopping sends SIGINT to that specific recorder process to finalize the MP4.

Videos are saved under the XDG Videos directory in `Gravações de tela`.
Click the pill, then **Parar gravação** to finish. A window recording
captures the window's chosen screen rectangle; it does not follow the window if
moved or resized.

Audio recording can be toggled on/off directly inside the popup before starting
a recording. When enabled, `scripts/screen-recording.py` passes `-a` to `wf-recorder`,
capturing audio through the default PipeWire/PulseAudio sink or source.

Dependencies: `wf-recorder`, `slurp` (`hyprctl` only on Hyprland). Errors and the saved path are
shown in the popup. The status stays beside the recording controls so an
operation result remains in context. Canceling a selection starts no recording.
