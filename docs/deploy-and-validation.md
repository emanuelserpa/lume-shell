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

Tag releases only after the reusable quality workflow validates the exact tag
commit. The Arch package is built first; publication and its SHA-256 checksum
run in the `release` GitHub Environment. Configure that environment with the
repository's required reviewer(s) so approval gates publication.
