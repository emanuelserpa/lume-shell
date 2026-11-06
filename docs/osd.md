# OSD

## Current supported OSD types

- speaker/output volume;
- microphone;
- brightness.

## Behavior

- appears near lower part of screen;
- focused monitor only;
- short display duration;
- ignores exclusion;
- generic renderer reused by typed helpers.

## Data sources

### Audio
PipeWire default sink/source.

### Brightness
Backlight device discovered via `scripts/brightness-status.py`, which parses
`brightnessctl -m` and returns `{ok, version, available, brightness, device,
error}`. Changes use `scripts/brightness-action.py`, which validates the
percentage, bounds the subprocess, and returns a versioned result. QML shows
helper failures in the brightness popup. The current value is still observed
through the existing brightness state path where available.

This avoids subprocess polling for every brightness update.

## Preserve

Do not replace working event-driven/observed state with high-frequency polling.

Keep animations and lifetime short.
