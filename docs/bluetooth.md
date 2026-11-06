# Bluetooth Module

## Current components

- `bar/Bluetooth.qml`
- `bar/BluetoothPopup.qml`
- `scripts/bluetooth-status.py`
- `scripts/bluetooth-action.py`

## Bar behavior

Typical states:
- off -> grey Bluetooth-off icon;
- on, no connection -> cyan Bluetooth;
- connected -> green Bluetooth + count.

Interactions:
- left click -> popup;
- middle click -> power toggle.
- the popup header gear opens Blueberry advanced settings.

## Popup behavior

Supports:
- power state;
- connected devices;
- paired devices;
- discovered devices;
- connect;
- disconnect;
- pair;
- battery where BlueZ exposes it;
- contextual state/errors;
- Blueberry fallback.

The header layout is shared through `components/PopupHeader.qml`; Bluetooth
retains ownership of its live status text, scan action, settings action, and
power switch.

The discovered-device empty message uses `components/EmptyState.qml` while
keeping the scan-dependent wording in the Bluetooth popup.

When four or more devices are present, the popup offers a debounced search by
device name or MAC address. Filtering does not alter Bluetooth discovery or
pairing state.

The bar uses the shared `ActionFeedback.qml` for action busy state and
target-specific errors. Discovery remains a separate long-running process.
Controller status is normalized by `CommandJson.result` before the bar and
dashboard consume its `data` fields; device discovery and actions retain their
own process lifecycles.

## Discovery policy

Discovery should only be active while useful.

Do not create permanent background discovery traffic.

`Bluetooth.qml` is mounted as an autonomous bar component in the right bar island
(just like `Audio.qml`), rendering its own Tabler SVG `Pill` and anchoring
`BluetoothPopup` directly to its bar indicator. Left click toggles `BluetoothPopup`,
and middle or right click toggles adapter power. Device discovery, pairing,
connection actions, and feedback remain owned by the Bluetooth module.

## UX posture

The current Bluetooth implementation is considered good enough.

Future work should be polish, not a rewrite, unless explicit need appears.

Good polish candidates:
- more compact empty state;
- better scanning indicator;
- per-device icons;
- cleaner device naming;
- refined activity spinner/state.

## Avoid

Do not rewrite to raw BlueZ D-Bus solely for architecture aesthetics.

Do not destabilize pairing/connect behavior.

## Native API evaluation

Quickshell 0.3.2 exposes a BlueZ-backed `Quickshell.Bluetooth` API with adapter
power/discovery state and device name, address, connection, pairing, trust, and
battery properties. This can support a read-only comparison of the adapter and
known-device state without replacing the current action path.

The current popup distinguishes paired and discovered devices and controls a
discovery process only while useful. A read-only API probe cannot reproduce
discovery results unless scanning is enabled, which is an active radio operation;
therefore the probe must not set `discovering` or call pairing/connection
functions. The API also does not remove the need to validate authenticated
pairing behavior against the existing `bluetoothctl` flow.

Conclusion: the native API is worth considering for passive adapter/connected
state if a concrete reliability or duplication issue appears. It does not
justify a migration by itself. The active helper and UI remain unchanged.
