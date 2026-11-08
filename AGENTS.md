# Working on Lume

Lume is a Quickshell desktop shell in daily use. Prefer small, reversible
changes within the user's request.

## Start here

1. Read [current-state](docs/current-state.md) for mounted surfaces and owners.
2. Read the [active design plan](docs/design-plan.md) and
   [stability contract](docs/stability-contract.md).
3. Consult [architecture](docs/architecture.md) and only the relevant feature
   guide from the [documentation index](docs/README.md).
4. For UI changes, use [design guidelines](docs/design-guidelines.md) and the
   [visual checklist](docs/visual-regression-checklist.md).

Use [project status](docs/status.md) for the recommended next task. Keep that
summary current when priorities change; put detailed progress and evidence in
the relevant plan or feature guide.

Spotlight work also uses [its plan](docs/spotlight-raycast-plan.md); themes and
wallpapers use the [wallpaper color plan](docs/wallpaper-color-plan.md).
Older roadmaps are background, not additional mandatory reading.

## Active plan priority

The user designated `docs/design-plan.md` as the active priority. Explicit user
requests define scope. Within that scope, prefer the earliest unfinished
applicable phase: state/diagnostics, legibility/keyboard, components/motion,
then geometry/regression. Do not expand a targeted task into unrelated phases.

Record implementation, checks, and visual evidence separately. Mark a phase
complete only when its acceptance criteria are met. Reconcile obsolete
instructions against the code and user decisions. Preserve stable behavior
unless the user authorized changing it; routine implementation choices do not
require additional approval.

## Worktree and documentation

- Inspect `git status` and relevant diffs before editing or committing.
- Preserve pre-existing work. Do not revert, rename, delete, format, or stage
  unrelated changes. Stage only the task's files/hunks and review the staged diff.
- Update the relevant documentation with behavior changes in the same commit.
  Keep `current-state.md` a map; put details in the feature guide. Avoid copying
  the same rules, token values, or implementation descriptions across documents.
- Use patch versions for fixes/polish and minor versions for meaningful features
  or layout changes. The documented project baseline is v1.2.0.

## Constraints

- Keep the explicit layout in `bar/Bar.qml`; no dynamic Loader/Repeater ordering.
  The previous experiment was reverted. `Network` stays after `Tray`.
- Preserve native notifications, history, DND, and volume/mic/brightness OSD.
- Preserve stable audio and media popup behavior, including the fixed media
  player delegate pool described in the stability contract.
- Keep compact spacing, Noto Sans/Nerd Fonts, and the active theme's tokens.
  Mocha is the default dark palette, not a fixed palette for all surfaces.
  Avoid nested cards; detail belongs in popups rather than the bar.
- Preserve geometry, typography, colors, motion, focus, placement, dismissal,
  and monitor behavior unless the task calls for changing them.
- Pass protected Wi-Fi secrets to `nmcli --ask` through stdin, never argv.
  Do not force continuous scans. Keep Open-Meteo and saved weather cities.
- Do not replace working Bluetooth/nmcli/CUPS/Python backends for architectural
  elegance alone. Stable surfaces are not cleanup targets without a concrete need.
- Compositor CLIs and syntax belong in `scripts/compositor-dispatch.sh`, not UI
  QML. `Submap.qml` is the dedicated Hyprland modal indicator.
- Prefer shared Wayland APIs for workspaces and toplevels. Retain native adapters
  for confirmed gaps; an empty object list does not prove protocol absence.

## Implementation boundaries

Follow `system APIs → services/helpers → UI → shared components` incrementally.
UI owns presentation, interaction, bindings, and domain actions. Helpers own
parsing and system operations; shared state belongs in existing services.

Create a service only for shared consumers, duplicated system queries, backend
leakage, lifecycle/caching/synchronization, or a useful stable API. One-popup
state may stay local. Do not create singletons merely for symmetry.

Prefer normalized `{ok, version, data, error}` helper responses, using the
existing decoder. Do not rewrite old helpers just to change their envelope.
Use subprocesses where appropriate, with bounded execution, restrained polling,
XDG state/cache paths, and contextual error feedback. QML component and helper
contracts are documented in [architecture](docs/architecture.md).

When choosing between solutions, prioritize preserved behavior, fewer duplicated
system interactions, existing APIs, clear UI boundaries, testability, fewer
dependencies, then less code.

## Validation and delivery

Follow [build and validation](docs/deploy-and-validation.md). For code changes:

- Check QML syntax, imports, and component boundaries; compile changed Python
  sources. Preserve script executable bits and exclude `__pycache__` from packages.
- Add meaningful regression coverage for testable bugs/business logic, fixtures
  for external parsers, and checks across changed UI/helper request boundaries.
  Keep tests isolated from the live desktop and real user state.
- Run the project validator before committing or deploying code. For changed
  runtime configuration, confirm loading and inspect Quickshell errors.
- Inspect existing instance logs under
  `/run/user/$UID/quickshell/by-id/<instance-id>/log.log`; do not restart merely
  to collect logs. Restart only to load changes or recover a confirmed stuck process.
- For visual verification, load the user's persisted theme and check the affected
  scenarios. Report unverified palettes, monitors, or compositor sessions honestly.

Documentation-only changes need link/content checks, not a shell restart.
Describe the result, validation, and material limitations in the delivery.
