# Printing

The bar uses `assets/tabler/bar-printer.svg` at the shared `barIconSize`:
rounded housing and paper corners, with a single filled status dot to avoid
overlapping strokes at small sizes. State colors and queue behavior are unchanged.

`bar/Printer.qml` owns the shared printer state and cancellation process.
Its compact `PrinterPopup.qml` shows reachable printers and a short queue view.
The **Abrir fila no CUPS** button closes the popup and runs
`system-config-printer --show-jobs <printer>`, choosing the default detected
printer or the first reachable printer. If that GUI is unavailable, it opens
the printer's CUPS web page. Inline cancellation remains available in the
shell popup through `printer-action.py cancel`.

The status helper uses CUPS commands (`lpstat` and, when available, `lpq`),
returns the versioned JSON contract, and is normalized by `CommandJson.result`
before the bar and popup consume its `data` fields.
It checks whether configured destinations are reachable before showing them.
Destinations with pending CUPS jobs remain visible even if the TCP probe fails,
so printing or offline queues remain accessible. The reported reachability stays
false; an idle queue with a failed probe shows an unavailable status.
Unreachable destinations without pending jobs remain hidden. It reports the full pending job count and returns up to 100
job entries for the UI. Document titles depend on `lpq`; when unavailable,
the CUPS job ID is shown. The queue refreshes every two seconds while a job
exists, and on explicit refresh or after cancellation.
If a status poll fails or a destination briefly disappears, the bar keeps the
last detected printer for up to 30 seconds and marks it temporarily unavailable;
this prevents CUPS restarts or short network drops from making the pill flicker.

Cancellation affects the selected CUPS job immediately and shows an inline
error if it fails. The shared `ActionFeedback.qml` carries cancellation busy
and error state; printer errors remain until the next action. Completed jobs,
pause/resume, and document previews are outside this queue's scope.

Document titles come from `lpq` (parsed by column position, not spacing,
since single-space gaps misalign fixed splits). Jobs ranked `active` in
`lpq` show a "● imprimindo" marker. The exact page being printed is not
exposed: the `lpd` backend never updates IPP progress counters
(`job-media-sheets-completed` stays 0 even for finished jobs).
