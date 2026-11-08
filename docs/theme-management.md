# Theme management

Theme Studio supports choosing a principal color extracted from the active
wallpaper. It offers Automatic and up to five perceptually distinct candidates,
previews Dark/Light/OLED locally, and applies only after confirmation. The
preference is stored by wallpaper content hash in
`$XDG_STATE_HOME/quickshell/wallpaper-color-preferences.json`; choosing Automatic
removes the manual override. Preview generation does not write active palette
files or synchronize adapters. See [Cores do wallpaper](wallpaper-color-plan.md)
for the interaction and acceptance details.

Theme Studio uses compact horizontal tabs for Themes, Wallpaper and Appearance,
with tonal selection matching the shell. The right-hand preview shows the active
wallpaper and locally generated palette; it hides on narrow layouts. Height
follows the content within the available screen area, without depending on the
card's own height. Wallpaper offers source colors; Appearance offers the
Dark/Light/OLED selector and Cancel/Apply. Keyboard zones reveal their section.
The theme catalog lists Chameleon once as a wallpaper-derived theme; its
Dark/Light/OLED variants are selected only in Appearance. Single-variant
entries use their short names (Everforest, Ghostty, Gruvbox and Solarized).
Catppuccin, Dracula and Rosé Pine each appear once as separate families; choosing
one selects that family's base theme. Appearance labels the active family above
its registered variants. Themes with a single palette remain individual entries
and do not get a family selector.
Appearance then shows the active family's variants: Latte/Frappé/Macchiato/Mocha,
Classic/Pro/Blade/Van Helsing, or Main/Moon/Dawn. Selecting a static variant applies it directly.
Chameleon retains the wallpaper-color preview and explicit Apply/Cancel flow.

The Appearance section also exposes a glass opacity slider. It updates the
wallpaper stage and the shared glass surfaces immediately and persists the
requested alpha in
`$XDG_STATE_HOME/quickshell/glass.json` (or
`~/.local/state/quickshell/glass.json`). The preference applies across themes.
`Theme.qml` clamps it to the supported compositor range: Hyprland surfaces keep
their blur cap, while labwc retains an opaque floor and disables the slider
because it has no background blur. Mango popup cards keep their near-opaque
fallback. Text and icons remain opaque. The slider works with mouse, wheel and
the Spotlight arrow keys; Enter restores its default value.

For clean-install portability work on Fedora Silverblue/Ublue with Hyprland,
see [Portabilidade de temas — Hyprland Atomic](theme-portability.md).
That guide describes proposed improvements, not completed setup automation.

Zen Browser uses its native theme editor independently of the shell.
The experimental adapter was removed; see [the investigation and cleanup
notes](zen-theme.md).

## Dependencies

- Python 3.
- Pillow (`python-pillow` on Arch) for wallpaper color extraction.
- The Material You color implementation is vendored under
  `scripts/vendor/materialyoucolor`; it is included in this repository.
- The generated GTK fallback stylesheet lives in
  `scripts/templates/gtk-chameleon.css`; `theme-manager.py` fills its semantic
  color tokens from the active palette.
- Wallpaper changes require a configured `awww` or `swww` backend. Theme
  adapters such as Kitty, Ghostty, Hyprland, GTK, Kvantum, and labwc are optional;
  an unavailable adapter does not prevent Quickshell from applying its palette.

The clean-install package list in `docs/hyprland-install.md` includes Pillow.

## Selecting and reverting themes

The theme choice is persisted under
`$XDG_STATE_HOME/quickshell/theme.json` (or
`~/.local/state/quickshell/theme.json` when `XDG_STATE_HOME` is unset).
Use the Settings theme section or run:

```bash
python3 ~/.config/quickshell/scripts/theme-manager.py list
python3 ~/.config/quickshell/scripts/theme-manager.py set catppuccin-mocha
```

`set` writes the active palette and synchronizes available adapters. Kitty
loads a generated color file for new windows and updates open windows with
`kitten @ set-colors` through a user-owned Unix socket. The config uses
`allow_remote_control socket-only` and places the socket in the private
`XDG_RUNTIME_DIR`. If an existing Kitty process has not created that socket,
the manager asks it to reload its config with `SIGUSR1`. Ghostty remains optional.

Rapid selections update the shell palette immediately and debounce adapter
application by 150 ms. `ThemeState` retains only the latest pending selection
while a helper is running, then applies it after that helper finishes; it never
changes the command of a running process. Older helper responses cannot replace
the newer selection or its adapter status. Wallpaper refreshes wait for pending
theme selections. CLI operations hold an exclusive `theme-manager.lock` in the
state directory for their full duration, preventing concurrent shell, CLI, and
wallpaper operations from interleaving adapter writes. An application already in
progress finishes before the latest selection is synchronized.

To revert from a wallpaper-derived Chameleon palette, select any static theme, such as
`catppuccin-mocha`. The palette cache lives beside the theme state and is
regenerated when the wallpaper path or modification time changes.

Chameleon palettes expose Material tonal surface containers and paired
`secondaryContainer`/`onSecondaryContainer` and
`errorContainer`/`onErrorContainer` roles. `Theme.qml` provides compatibility
fallbacks for built-in palettes that do not yet define those roles.

## Wallpaper flow

The wallpaper gallery and `wallpaper-action.py` apply a wallpaper with the
configured backend, update the current-wallpaper cache, and refresh Chameleon
colors. Wallpaper selection is persisted separately in
`$XDG_STATE_HOME/quickshell/wallpaper.json`. On session startup, `restore`
reapplies the saved wallpaper when available.

The gallery loads only its five visible thumbnails. WebP/AVIF previews use
Pillow and JPEG-XL uses ImageMagick to generate cached JPEGs for Qt. Arrow keys
or the wheel select an image; Enter or double-click applies it through
awww/swww. Folder selection uses zenity; Spotlight temporarily unmaps so the
native picker remains accessible, then returns to theme mode.

```bash
python3 ~/.config/quickshell/scripts/wallpaper-action.py get
python3 ~/.config/quickshell/scripts/wallpaper-action.py restore
```

The CLI returns a JSON envelope with `ok`, `error`, and `version` fields.
Theme manager actions are `get`, `list`, `set <id>`, `next`, and
`update-wallpaper [path]`, `wallpaper-colors [path]`,
`preview-wallpaper-color <path> <hex|auto> <variant>`, and
`set-wallpaper-color <path> <hex|auto> <variant>`.
`ThemeState.qml` decodes these responses through the shared
`CommandResult.js` normalizer; helper failures remain visible in the Settings
window header and in the Quickshell log. Wallpaper listing, preview, apply, and
random-selection failures are shown in the gallery status row and logged.

## Validation

After changing theme logic, run `./scripts/validate.sh` and follow the theme,
contrast, popup, transparency, and wallpaper items in
`docs/visual-regression-checklist.md`. The automated checks do not replace
checking the rendered shell under the active compositor.

Theme unit tests verify WCAG AA contrast (4.5:1) for normal foreground text on
card surfaces and for generated Material foreground/container role pairs.
Small metadata and disabled text remain separate semantic roles and require
visual review in `docs/visual-regression-checklist.md`.
