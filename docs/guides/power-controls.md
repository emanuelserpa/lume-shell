# Battery and power controls

`bar/Battery.qml` owns status and actions for the battery popup. The popup keeps
the charge limit and power profile controls, and adds a CPU boost switch below
the power profile selector. It uses the shared `SettingToggleRow` and
`PowerProfileSelector` components. Its metric cards use the shared adaptive
card surface, outline, and radius tokens from `Theme.qml`; the charge progress
bar stays capsule-shaped using its own track geometry.

The detail popup uses theme-tinted outline icons for battery state, remaining
time, and CPU boost. Its header status comes from the same state label as the
bar. The popup percentage and progress bar use red-through-15%,
yellow-through-35%, green-above-35% thresholds, including while charging.

## Night light

The night-light toggle saves whether automation is enabled. With `hyprsunset`,
the manager calculates local sunrise and sunset for the selected weather city
and generates five-minute temperature profiles. Color temperature eases
linearly from the configured day value to the night value during the first 90
minutes after sunset, stays at the night value, then eases back during the last
90 minutes before sunrise. The sunrise profile restores the identity matrix.
This approximates a continuous curve using hyprsunset's scheduled profiles and
does not need a polling daemon. Status reports the interpolated temperature at
the current local time. The `wlsunset` backend keeps its native solar ramp.

Battery charge, state, and remaining time come from Quickshell's UPower
service. Battery health uses UPower when it reports `healthSupported`, and
falls back to `scripts/battery-health.py` on hardware where it does not.
Power profiles use Quickshell's `PowerProfiles` API when
`energy-profile.py` identifies `power-profiles-daemon` as the active backend;
the helper remains responsible for reporting and changing firmware
`platform_profile` values used by other supported setups.

`scripts/cpu-boost.py` exposes a versioned JSON status contract and a `set on|off`
action. It reads Linux CPUFreq's system-wide `cpufreq/boost` attribute and
Intel `intel_pstate/no_turbo` when that driver-specific interface is present;
the helper normalizes both to an `enabled` boolean. The UI hides the switch
when neither interface is exposed. Kernel state is refreshed while the popup is
open and after a toggle. Successful user changes are saved atomically in
`~/.config/lume-shell/power/cpu-boost.json`. Existing settings under
`~/.config/lumeshell/power/cpu-boost.json` and
`~/.config/quickshell/power/cpu-boost.json` are migrated on first access.
The preference file is private to the user and contains only the requested
on/off value.

## Bar indicator

The bar follows the horizontal Material 3 Expressive battery reference shown
during the Android 16 rollout. Reference:
https://www.androidauthority.com/google-material-3-expressive-redesign-battery-icon-3554579/
and Android 16 QPR1 hands-on:
https://9to5google.com/2025/05/21/android-16-qpr1-beta-1-hands-on/

The rounded rectangular body is 31×17 logical pixels with a separate terminal.
The integrated Noto Sans Black percentage uses the 13px theme icon token and
tabular digits. One text silhouette supplies both ink colors; its layer gradient
blends across three logical pixels at the proportional fill edge. Charging does
not move or resize the percentage inside the body. A filled vector bolt occupies
a separate 12px area outside the battery. Its minimal filled silhouette has six vertices and straight edges, centered
in a 12×14px area; it stays independent of the percentage ink.

Colors come from the active theme: charging is green; otherwise charge at or
below 15% is red and normal operation uses neutral ink. The `extra-low-power`
(`Ultra Eco`) profile shows a small leaf badge in the external slot beside the
battery body when not charging, without moving or obscuring the percentage ink.
Other power profiles (`power-saver`, `balanced`, `performance`) do not alter the
bar indicator. A full battery without active charging uses the neutral color. No
warning ring surrounds the pill. Tooltip, popup controls, UPower integration and
popup progress colors remain unchanged (the popup uses red through 15%, yellow
through 35%, green above 35%).

Runtime reload and the live 77% power-saver state were inspected in
`/tmp/battery-android.png`. Charging, low-charge, 100%, light theme and fractional
scales still require visual verification; the screenshot does not cover them.

## Persist across login

The Arch package installs a root-owned writer at
`/usr/lib/lumeshell/lumeshell-cpu-boost`, its Polkit rule, and the globally
available `lumeshell-cpu-boost-restore.service`. The helper accepts only `on`
or `off` and writes only the kernel's boost attribute. Its Polkit rule permits
active local sessions to run only that fixed helper; it grants no general
shell or sysfs access. The package enables the restore unit for user logins. On first
install, the saved preference defaults to boost off; an existing preference
is preserved. At each later login, the service reapplies that preference. If
the hardware exposes no supported interface, it leaves the kernel setting
alone.

To remove the integration, uninstall the package. For a source checkout,
remove the package-owned system unit and helpers explicitly:

```sh
sudo systemctl --global disable lumeshell-cpu-boost-restore.service
sudo systemctl disable --now lumeshell-power-source-policy.service
sudo rm -f /usr/lib/lumeshell/lumeshell-cpu-boost \
  /usr/lib/lumeshell/lumeshell-battery-charge-limit \
  /usr/lib/systemd/system/lumeshell-power-source-policy.service \
  /usr/lib/systemd/user/lumeshell-cpu-boost-restore.service \
  /usr/share/polkit-1/rules.d/50-lumeshell-cpu-boost.rules \
  /usr/share/polkit-1/rules.d/50-lumeshell-battery-charge-limit.rules
sudo systemctl daemon-reload
```

Polkit authorizes `pkexec` requests by executable path and active local session.
See the [polkit rule reference](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)
and [`pkexec` security notes](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html).

A write that requires elevated privileges uses `pkexec`; cancellation and
write errors are displayed in the popup. Once the system integration is
installed, changing or restoring this one setting does not ask for a password.

The switch controls whether the kernel may use frequency boost. An enabled
state does not mean the CPU is boosting at that instant; workload, thermal
headroom, and platform power limits still apply. The kernel can omit this
interface when the driver does not support runtime boost control. See the
[Linux CPUFreq documentation](https://docs.kernel.org/admin-guide/pm/cpufreq.html#frequency-boost-support).

`tests/test_cpu_boost.py` verifies sysfs detection, Intel's inverse setting,
state writes, preference storage, and the unsupported case without touching the
host's real sysfs.

### Power profiles and charge thresholds

Power profiles use `power-profiles-daemon` when available. The shell reports
firmware `platform_profile` values on supported systems without that service.

PPD does not manage battery charge thresholds. The Arch package installs the
root-owned `/usr/lib/lumeshell/lumeshell-battery-charge-limit` helper and its
Polkit rule. The helper accepts 80 (75/80 eco limit) or 100 (temporary
full-charge mode); 100 requires external power. It writes only the battery's
kernel-exposed start/end threshold files. Hardware without those sysfs controls
has no charge-limit action.

The system unit `lumeshell-power-source-policy.service` watches udev power
supply events. On AC it selects `balanced` and `s2idle`; on battery it selects
`power-saver` and `deep`. If the charge limit is at 100% when AC is unplugged,
it restores 75/80 automatically. It performs the same source selection at
startup, so it also recovers when the machine boots on battery. A manually
selected PPD profile stays in effect until the power source changes.

### Ultra Eco (`extra-low-power`)

`scripts/energy-profile.py` and `services/PowerProfileState.qml` add a fourth
`Ultra Eco` (`extra-low-power`) profile below `Economia`. Selecting it sets the
underlying `low-power` / `power-saver` profile, disables CPU boost, and caps
`scaling_max_freq` at `1600000` kHz (`schedutil` when available) through the
root-owned `/usr/lib/lumeshell/lumeshell-power-profile` helper and its Polkit
rule. While discharging at or below `15%`, `PowerProfileState` automatically
switches to `extra-low-power` (remembering the boost preference) and switches
to `balanced` while restoring CPU ceiling/boost when external power is
connected (aligned with `lumeshell-power-source-policy.service`, which also
uncaps `scaling_max_freq` on AC). Manual changes while `<= 15%` are respected
until external power is connected or charge rises above `18%`.
