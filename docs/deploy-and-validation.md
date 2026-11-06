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

Run the project validator before committing or deploying:

```sh
./scripts/validate.sh
```

For Python tests only:

```sh
python3 -B -m unittest discover -s tests -p "test_*.py"
```

For visual checks, see [`visual-regression-checklist.md`](visual-regression-checklist.md).
Automated checks do not replace visual review of Wayland surfaces, popup
placement, monitor behavior, and font rendering.
