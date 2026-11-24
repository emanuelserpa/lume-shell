# Build and validation

## Arch package

Build the package from the current checkout:

```sh
cd packaging/arch
makepkg --cleanbuild
```

The local build does not install or restart the running shell. See
[`packaging/arch/README.md`](../packaging/arch/README.md) for package contents
and release builds.

## Automated checks

Run the offline project validator before committing or deploying. It does not
query live hardware/network helpers or send commands to the running shell:

```sh
./scripts/validate.sh --offline
```

Use `--live` only when you want to query actual hardware and network helpers.
The Spotlight latency probe is separate and opt-in with
`--spotlight-latency`; it toggles the live launcher. `--visual` runs the
compositor/environment checks.

For Python tests only:

```sh
python3 -B -m unittest discover -s tests -p "test_*.py"
```

For visual checks, see [`visual-regression-checklist.md`](visual-regression-checklist.md).
Automated checks do not replace visual review of Wayland surfaces, popup
placement, monitor behavior, and font rendering.

## Release gate

Run the local validator on the intended commit before tagging. The current
release workflow first runs a `validate` job (`./scripts/validate.sh --offline --skip-qmllint`,
covering unit tests, QML behavior tests, syntax/module checks, and Markdown links)
and builds/publishes the Arch package and SHA-256 checksum only when validation
passes. Publication approval still depends on the repository's `release`
Environment settings on GitHub.
