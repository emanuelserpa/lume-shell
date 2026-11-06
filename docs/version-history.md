# Version History Summary

This is not a complete changelog. It captures architecture decisions and regressions to avoid.

## v0.10.x
Media pill alignment fixes.
User considered the result good/perfect.

## v0.11.x
- tray styling stabilized;
- update/weather/audio/battery/temp popups matured;
- early custom network/Bluetooth popup attempts failed and were reverted;
- AudioPopup stabilized.

## v0.12.x
- media popup rounded-corner masking fixed;
- media popup content-driven height fixed;
- brightness added;
- brightness parser corrected for system-specific `brightnessctl -m` format.

The user considered the Waybar -> Quickshell migration complete around v0.12.6.

## v0.13.x
NetworkManager frontend introduced:
- nmcli backend;
- Wi-Fi/VPN popup;
- secret handling moved to nm-applet agent;
- active VPN indicator.

## v0.14.x
- Wi-Fi scan behavior optimized;
- generic OSD added;
- microphone OSD added.

## v0.15.x
- contextual network errors;
- generic OSD refinements;
- config-driven `bar.json` experiment introduced and then reverted.

Important:
Do not restore the dynamic ordering experiment.

## v0.16.x
- `EndControls` split;
- dedicated Bluetooth module added;
- NotificationControl extracted;
- Bluetooth bottom spacing polished.

## v0.17.x
- central calendar/dashboard popup introduced;
- media controls on hover;
- updates moved from bar into central popup;
- load error caused by missing `import qs.components` fixed.

Lesson:
When using shared QML types such as `CommandJson`, ensure the proper module import exists.

## v0.18.0
Visual simplification:
- CPU removed from permanent bar;
- Weather moved to center;
- central popup reduced to two true cards;
- updates became plain text;
- reduced nested-container feel.

## v0.19.0
Weather multi-city introduced:
- saved cities;
- selection;
- search;
- Open-Meteo geocoding;
- persistent state;
- scroll city cycling.

## v0.19.1
Weather stabilization:
- no cross-city stale cache reuse;
- scroll handling improved;
- saved city list made scrollable;
- popup height adjusted.

## v0.20.x
- popup and visual consistency refinements;
- fault-isolated update center;
- Spotlight launcher and action workflows;
- CopyQ text and image clipboard integration;
- shared media state and numerous stability fixes.

In v0.20.36, launcher clipboard history gained CopyQ image thumbnails and
restored the selected image to the clipboard.

## v0.21.x
- Control Center introduced and polished;
- shared media selection established;
- v0.21.3 simplified the bar and disabled the Control Center while retaining
  its implementation for possible future use.

## v1.0.0
The proven v0.21.3 configuration was promoted unchanged as the first stable
release.

## v1.1.0
Spotlight gained a Raycast/Alfred-style split view.

## Unreleased
- `PopupListRow` dead-tap regression fixed: Wi-Fi rows in `NetworkPopup.qml`
  and alternate-player rows in `MediaPopup.qml` carried their `TapHandler` in
  the default content slot, which is hidden under the standard icon/title
  layout, so row clicks never fired. Both moved to `interactionHandlers`.
- Saved secure Wi-Fi networks gained password re-entry (key action per row):
  the typed password clears the stale stored secret first and
  `nmcli --ask connection up` reads the replacement over stdin.

## v1.2.0
Launcher clipboard history moved from CopyQ to a native Wayland backend using
`wl-clipboard`, a Python daemon, SQLite WAL, and blob storage. Permanent item
IDs fixed deleted items reappearing while preserving the launcher UI.

Current baseline: v1.2.0.
