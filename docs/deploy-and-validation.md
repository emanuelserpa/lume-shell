# Deploy and Validation

## Recommended deploy script

A generic deploy script should accept only a version number.

Expected package naming:

`~/Downloads/quickshell-waybar-migration-v<version>.zip`

Example:

```bash
deploy-quickshell 1.0.0
```

## Basic deployment flow

1. stop `quickshell.service`;
2. unpack to temporary directory;
3. replace `~/.config/quickshell`;
4. validate;
5. restart service.

## Important obsolete behavior

Do not validate `config/bar.json`.

That file was intentionally removed when the dynamic bar-ordering architecture was reverted.

Any old installer that requires `config/bar.json` is obsolete.

## Useful service commands

```bash
systemctl --user stop quickshell.service
systemctl --user start quickshell.service
systemctl --user restart quickshell.service
systemctl --user status quickshell.service
```

## Direct debug run

```bash
quickshell
```

Typical startup path:

`~/.config/quickshell/shell.qml`

## Automated validation

Run the host diagnosis before troubleshooting missing features or packages:

```bash
./scripts/doctor.sh
```

It checks the active compositor's configuration, key config files, runtime
commands grouped by feature, Quickshell's current service/log state, CPU boost
restore integration, then runs the project's validator and tests. Missing
optional integrations appear as warnings; broken required files, dependencies,
or active-session configuration produce failures. It does not modify
configuration or restart services. Compositor checks target the detected active
session (Hyprland's loaded-config errors, Labwc XML syntax, or Mango config
presence); they do not fully parse inactive compositor configs or every Kitty
setting. Use `--skip-validate` for a quick host-only check.

Run the unified validation harness before committing or deploying changes:

```bash
./scripts/validate.sh
```

Run visual surface and environment check:

```bash
./scripts/validate.sh --visual
# or directly:
./scripts/visual-check.sh
```

Or run Python unit tests directly:

```bash
python3 -B -m unittest discover -s tests -p "test_*.py"
```

For the full visual design and interaction contract, consult [`docs/visual-regression-checklist.md`](visual-regression-checklist.md).

### Result Status Meanings:
- **`[OK]`**: Check passed completely (e.g. Python syntax compiled cleanly, scripts are executable, QML modules exist, JSON helpers responded with valid structure, or all unit tests passed).
- **`[WARN]`**: Non-fatal warning or optional service unavailable (e.g. CUPS daemon not running, Bluetooth controller unpowered/absent, or offline network state). Does not fail the build.
- **`[FAIL]`**: Critical structural failure, invalid syntax, missing root QML component, broken JSON output, left-behind `__pycache__` artifacts, obsolete runtime dependencies, or failing unit tests. Causes non-zero exit code (`exit 1`).

> [!IMPORTANT]
> Automated validation does **NOT** replace manual or visual verification of the desktop shell. Layout rendering, Wayland layer-shell interactions, screen margins, and font rasterization require visual confirmation.

### Minimum Manual Verification Checklist:
Before finalizing a deployment or shell update, visually verify:
- [ ] Start Quickshell (`systemctl --user restart quickshell.service`) and check logs (`systemctl --user status quickshell.service`) for absence of critical errors;
- [ ] Top bar renders with correct margins, corner radius, and font metrics;
- [ ] Open Spotlight launcher (`SUPER+D`);
- [ ] Open clipboard manager (`SUPER+C` or `#`), verify preview pane and item deletion;
- [ ] Open notifications panel (`bar/NotificationControl.qml`), check toast layout and history;
- [ ] Open network popup, check connection list and speedtest;
- [ ] Open Bluetooth popup, check device list;
- [ ] Open media popup, check artwork blur and player controls;
- [ ] Verify popups anchor to their respective widgets on the correct active monitor.

## Validation checklist

### QML
Look for:
- `Type X unavailable`
- `X is not a type`
- missing imports
- property binding errors
- invalid anchors
- runtime exceptions

### Python
Compile modified scripts:

```bash
python -m py_compile scripts/foo.py
```

### Packaging
Do not include:
- `__pycache__`
- temporary files
- editor backups

### Visual regression
Check:
- media alignment;
- center clock/weather alignment;
- right-side spacing;
- popup bottoms;
- no unexpected large dead areas;
- Network still after Tray.

## UWSM/systemd note

Quickshell is launched via a user service in the user's environment.

A portal warning about duplicate app association has been seen and is non-fatal.
