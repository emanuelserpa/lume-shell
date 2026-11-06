# AGENTS.md — Quickshell Shell Project

This repository contains a custom Quickshell-based Linux desktop shell evolved from a Waybar configuration.

## Start here

- Read `docs/design-plan.md` before choosing or implementing shell changes;
  it is the active priority plan, not optional background reading.
- `docs/current-state.md`: what's mounted and where the active implementation lives.
- `docs/architecture.md` and `docs/stability-contract.md`: boundaries and behavior to preserve.
- Read only the target domain guide (`docs/weather.md`, `docs/network.md`,
  `docs/bluetooth.md`, `docs/osd.md`, `docs/notifications.md`,
  `docs/clipboard.md`, `docs/control-center.md`, `docs/screen-recording.md`,
  or `docs/printer.md`).
- For visible UI changes, read `docs/design-guidelines.md`; before validation
  or deployment, read `docs/deploy-and-validation.md`.
- For Spotlight interaction, ranking, actions, shortcuts, or geometry, read
  `docs/spotlight-raycast-plan.md`. Read `docs/version-history.md` or
  `docs/roadmap.md` only when history or planned work matters.
- For themes, wallpaper colors, or Theme Studio, also read
  `docs/wallpaper-color-plan.md`; distinguish its planned features from the
  currently implemented automatic Chameleon extraction.

## Active plan priority

The user explicitly designated `docs/design-plan.md` as the priority for agents.
Use `docs/design-guidelines.md` for design decisions and
`docs/visual-regression-checklist.md` for acceptance evidence.

- Follow the current user request first. Within its scope, prefer the earliest
  unfinished applicable phase of the active plan: state/diagnostics, then
  legibility/keyboard, then shared components/motion, then geometry/regression.
- For open-ended shell improvement requests, select work from that plan before
  older roadmaps, optional polish, new features, or agent-proposed refactors.
- For a targeted task, identify the relevant plan item and apply its criteria.
  Do not expand the task into unrelated phases or block a requested fix merely
  because another phase remains unfinished.
- Preserve the stability contract. If a planned change conflicts with it,
  record the conflict and keep the stable behavior unless the user has already
  authorized that specific change. Do not seek approval for routine choices
  already covered by the request.
- Update plan status and evidence when delivering related work. Mark an item
  complete only when its acceptance criteria have been met; distinguish code
  implemented, checks passed, and visual verification still pending.
- If another project document contradicts the active plan or design guide,
  reconcile the relevant documentation against the code and user decisions;
  do not silently follow an obsolete instruction or claim a proposal is live.

## Worktree safety

Before editing or committing, inspect `git status` and the relevant diff. Treat
pre-existing staged, unstaged, and untracked files as user work: do not revert,
reset, format, rename, delete, or stage them unless they are part of the request.
Stage only the task's files or hunks, then inspect the staged diff before commit.
If an existing change conflicts with the requested work, preserve it and ask
before replacing it.

## Core development rule

Prefer small, reversible, targeted changes over broad rewrites.

Before committing any change, update the relevant documentation to reflect the
resulting behavior, architecture, and user-facing changes. Keep
`docs/current-state.md` as a concise map of the mounted shell; put detailed
behavior and backend contracts in the relevant domain document. Include the
documentation changes in the same commit as the implementation.

This project is already in daily use. Avoid regressions. If a subsystem is documented as stable, do not redesign or refactor it unless the task explicitly requires it.

## Non-negotiable constraints

- Do **not** reintroduce `config/bar.json`.
- Do **not** replace the explicit `Bar.qml` layout with dynamic `Loader`/`Repeater` ordering. That experiment made the bar visually worse and was reverted.
- Keep `Network` after `Tray` in the right-side bar order.
- Preserve the active native NotificationServer, toast, history, and DND behavior.
- Preserve the compact Catppuccin Mocha-inspired identity through the active
  theme tokens. Mocha is the historical/default dark palette; built-in and
  Chameleon light/dark/OLED palettes remain supported. Do not hardcode Mocha
  colors into surfaces. See `docs/design-guidelines.md`.
- Keep Noto Sans / Nerd Font usage; avoid switching to a mono-heavy visual language.
- Preserve compact spacing and low visual density.
- Avoid "card inside card inside card" UI.
- The bar should be glanceable; detail belongs in popups.
- `nm-applet` is intentionally not used anywhere (explicit user decision):
  Wi-Fi secrets flow through the shell password dialog to `nmcli --ask`
  over stdin. Do not reintroduce it as secret agent.
- Do not move Wi-Fi passwords into command-line argv.
- Do not break existing OSD behavior.
- Do not rewrite Bluetooth to raw BlueZ D-Bus solely for architectural elegance.
- Existing media popup is considered stable.
- Existing audio popup is considered stable.
- Existing Weather now supports saved cities and should remain compact in the bar.
- Do not hardcode compositor CLIs (e.g. `hyprctl`, `swaymsg`) or compositor-specific config syntax (e.g. `hl.dsp` Lua strings) in UI QML files. Dispatch actions must pass through `scripts/compositor-dispatch.sh`. `bar/Submap.qml` is the sole dedicated modal submap indicator component.


## Architectural Direction

This project is evolving from a personal Quickshell configuration into a
self-contained desktop shell built on Quickshell + Hyprland.

This is an incremental direction, NOT a request for large refactors.

Every change should preserve current behavior while, when practical, moving the
touched area toward the following architecture:

    System / Quickshell APIs
             ↓
       Services / Helpers
             ↓
        UI Surfaces
             ↓
       Shared Components

The UI should progressively depend on project-owned APIs/state rather than
directly knowing system implementation details.

Examples:

    BAD:
    NetworkPopup.qml -> directly parses nmcli output everywhere

    BETTER:
    NetworkPopup.qml -> Network service/helper -> nmcli

    BAD:
    multiple widgets independently query MPRIS

    BETTER:
    widgets consume MediaState

    BAD:
    clipboard UI knows daemon storage/index details

    BETTER:
    clipboard UI consumes stable clipboard IDs/API

## Architectural Ratchet

Leave the affected area at least as well structured as before. Make only small
improvements related to the task. Prefer one source of truth per domain, stable
helper interfaces, shared state only when needed, centralized visual tokens,
testable pure logic, and explicit failure behavior.

## Service Extraction Rule

Create or extend a service only when at least one of these is true:

- the same system state is consumed by multiple surfaces;
- multiple surfaces independently execute the same system command;
- system/backend details are leaking heavily into UI code;
- state needs lifecycle, caching, deduplication or synchronization;
- a stable API would materially reduce regression risk.

Do NOT create services merely for symmetry.

A component used by only one popup may remain local if that is simpler.

## Preferred Boundaries

Long-term project-owned domains include, where justified:

- Media
- Notifications
- Clipboard
- Audio
- Network
- Bluetooth
- Power
- Brightness
- Hyprland/session state

Existing stable backends should not be replaced without a concrete reason.

Examples:

- NetworkManager/nmcli is acceptable.
- bluetoothctl is acceptable.
- CUPS is acceptable.
- Open-Meteo is acceptable.
- Python helpers are acceptable.
- subprocesses are acceptable.

The goal is not to eliminate subprocesses.
The goal is to prevent UI code from depending unnecessarily on their raw
output and implementation details.

## UI Surface Rule

Visible UI files should primarily be responsible for:

- presentation;
- layout;
- user interaction;
- binding to state;
- invoking domain actions.

Avoid adding new low-level parsing, filesystem logic, process management or
backend-specific state directly inside large UI surfaces when a suitable
service/helper already exists.

Do not rewrite existing working UI just to satisfy this ideal.

## Shared State Rule

Use singleton/shared services only for genuinely shared state.

Good candidates:
- MediaState
- NotificationState

Do NOT turn every module into a singleton.

Prefer local state when:
- only one surface consumes it;
- lifecycle is local to a popup;
- sharing provides no concrete benefit.

## Backend Contract Rule

When adding or modifying helpers, prefer stable project-owned contracts.

Prefer:

    helper/system backend
          ↓
    normalized JSON/state
          ↓
          QML

over QML parsing human-readable command output directly.

New JSON contracts should be predictable and, where useful, versioned.

Example:

{
    "ok": true,
    "version": 1,
    "data": { ... },
    "error": null
}

Do not rewrite all existing helpers only to adopt this format.
Apply it incrementally when touching them.

## Testing Ratchet

When fixing a bug or modifying parsing/business logic:

- add a regression test when the logic can be tested without the live desktop;
- add a fixture when parsing external command output;
- preserve or extend scripts/validate.sh;
- do not introduce large testing frameworks unnecessarily.
- For behavior crossing UI-to-helper boundaries, test the request produced by
  the UI adapter and the command/result mapping in the helper; a helper-only
  test does not cover a broken signal or argument mapping.

A bug that can reasonably be reproduced as a pure test should preferably not
be left without one.

## Visual Stability Rule

Visual behavior is a stability contract.

Every new or changed UI surface must use the active `Theme.qml` tokens for its
colors, typography, borders, and background. Do not give a window a separate
hardcoded palette. When previewing a surface in a temporary Quickshell config,
load the same persisted theme before judging or approving its appearance.

Unless the task explicitly requests visual changes, preserve:

- geometry;
- spacing;
- typography;
- colors;
- animations;
- popup placement;
- monitor behavior;
- focus behavior;
- dismissal behavior.

Architectural improvements must not be used as an excuse to redesign UI.

## Decision Priority

When several solutions work, prefer in this order:

1. preserve existing behavior;
2. reduce duplicated system interaction;
3. strengthen an existing project-owned service/API;
4. keep UI unaware of backend details;
5. improve testability;
6. reduce dependencies;
7. reduce code size.

Do not sacrifice reliability merely to achieve a cleaner abstraction.

## Required validation for every change

At minimum:

- inspect QML syntax carefully;
- run Python syntax compilation for modified Python scripts;
- preserve executable bits on scripts;
- ensure no obsolete `bar.json` assumptions remain;
- avoid importing QML component types without importing their module;
- package without `__pycache__`;
- describe the change, validation, and any material limitations.

If Quickshell is available on the host, run it against the config and check for:
- `Failed to load configuration`
- unavailable QML types
- missing imports
- runtime QML errors
- subprocess failures

For runtime diagnosis, inspect the active Quickshell instance log under
`/run/user/$UID/quickshell/by-id/<instance-id>/log.log`. Do not restart the
shell just to inspect or collect logs; use the current instance log. Restart
only when a changed configuration must be loaded or when recovering a confirmed
stuck process, then inspect the new instance log for `Configuration Loaded`
and runtime errors. `scripts/validate.sh` does not require opening the Spotlight
UI or restarting Quickshell unless a specific validation step says so.

## Versioning guidance

Use semantic-ish project versions:
- patch version for fixes/polish only;
- minor version for meaningful feature additions or layout changes.

Current baseline: **v1.2.0**.
