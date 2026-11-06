# Roadmap

This is a priority guide, not a mandate.

## Stability Roadmap

1. validation harness (completed — `scripts/validate.sh`)
2. parser fixtures/tests (completed — `tests/test_parsers.py` with real fixtures)
3. notification hardening (completed — robust empty/ghost notification filtering & dismissal across NotificationState, toasts, and popup)
4. native clipboard backend (completed — `wl-clipboard` + SQLite WAL + daemon)
5. stable helper contracts (completed — normalized JSON envelope `{"ok": bool, "error": str | null, ...}`, exception wrapping, and `tests/test_contracts.py`)
6. shared state only where useful (completed — unified Network & Bluetooth state across Bar and ControlCenterCard, eliminated redundant subprocesses, preserved local popup state)
7. subprocess/polling audit (completed — idle wakeups cut by 50%, popup-scoped polling for temp/fan/power profile, package update interval optimized)
8. lightweight visual regression checklist (completed — `docs/visual-regression-checklist.md`, `scripts/visual-check.sh`, and `validate.sh --visual`)

## Near-term

### Reprodutibilidade no Arch Linux

O pacote Arch e o processo de validação estão descritos em
`packaging/arch/README.md` e `docs/deploy-and-validation.md`.

### Spotlight inspirado no Raycast

Plano incremental em `docs/spotlight-raycast-plan.md`: contrato de ações,
barra inferior, `Ctrl+K`, compactação visual, busca com seções, ranking e
quicklinks. Os modos atuais devem ser preservados e as etapas não devem entrar
como uma única reescrita.

### 1. Weather validation/polish
v1.0.0 is the current baseline.

Only fix concrete issues found during use.

### 2. Central popup polish
Potential work:
- spacing;
- update-line aesthetics;
- balance of CPU/date/music/calendar.

Do not reintroduce excessive cards.

### 3. Bluetooth polish
Only after concrete need appears.

Focus on:
- empty-state compactness;
- scanning feedback;
- device-type icons;
- minor row polish.

Avoid a rewrite.

## Existing notification system

Native Quickshell `NotificationServer` is active. Preserve its toast, history,
and DND behavior; change it only for a concrete request or defect.

## Wallpaper-driven themes

Inspired by [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland),
which generates Material colors from a wallpaper and writes separate theme
outputs for Quickshell, Hyprland, and apps. This is implemented; operating
instructions and adapter coverage are documented in `docs/theme-management.md`.

- [x] Keep the current Catppuccin Mocha palette in `Theme.qml` as the default
  and fallback; add an explicit Mocha / Chameleon wallpaper colors switch.
- [x] Generate a palette from the selected wallpaper and store it under XDG
  state, outside the source repository.
- [x] Load and validate the generated palette in Quickshell, map it to the
  existing theme tokens, and fall back cleanly when it is missing or invalid.
- [x] Move component colors to active theme tokens; keep palette literals in
  the central theme definitions and explicit fallback paths only.
- [x] Keep text, popup, toast, and Spotlight colors bound to active theme
  tokens; visual checks are listed in `docs/visual-regression-checklist.md`.
- [x] Generate dynamic colors for Kitty, updating its open windows and startup
  palette when the wallpaper or theme changes; retain Ghostty as an optional adapter.
- [x] Synchronize Hyprland active border colors, GTK, hyprlock, Kitty, btop,
  Qt/Kvantum, labwc, and Fastfetch, accounting for their reload behavior.
- [x] Document dependencies, switching, rollback, and validation.

Implement in small stages; preserve the compact layout and existing Mocha
appearance whenever wallpaper theming is disabled or generation fails.

## Possible future features

Only on request:
- richer weather city management;
- saved-city reordering;
- notification center rewrite;
- additional shell-level integrations.

## Decision heuristic

When choosing between:
- more abstraction
- more reliability

prefer reliability.

When choosing between:
- more visible data
- cleaner bar

prefer cleaner bar, with detail in popup.
