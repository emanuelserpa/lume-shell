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
`~/.config/quickshell/power/cpu-boost.json`. The preference file is private to
the user and contains only the requested on/off value.

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
below 15% is red and normal operation uses neutral ink. The power profile does
not affect the bar indicator: power-saver remains available in the popup, without
a yellow color or plus badge on the pill. A full battery without active charging
uses the neutral color. No warning ring surrounds the pill. Tooltip,
popup controls, UPower integration and popup progress colors remain unchanged
(the popup uses red through 15%, yellow through 35%, green above 35%).

Runtime reload and the live 77% power-saver state were inspected in
`/tmp/battery-android.png`. Charging, low-charge, 100%, light theme and fractional
scales still require visual verification; the screenshot does not cover them.

## Persist across login

Run `sudo scripts/install-cpu-boost-system.sh` once (or launch the installer
through `pkexec` when no terminal is available). It installs a root-owned
writer at `/usr/local/libexec/quickshell-cpu-boost`, a user-scoped polkit rule,
and `cpu-boost-restore.service`. The rule only authorizes the configured user
in an active local session to run that fixed helper; the helper accepts only
`on` or `off` and writes only the kernel's boost attribute. It does not grant
general shell or sysfs access. The installer enables the user service in the
current session when its systemd user bus is available. On first install, the
saved preference defaults to boost off; an existing preference is preserved.
At each later login, the service reads the saved preference and reapplies it.
If the hardware exposes no supported interface, it leaves the kernel setting
alone.

To remove the system integration, disable the user unit and remove the exact
installed files:

```sh
systemctl --user disable --now cpu-boost-restore.service
sudo rm /usr/local/libexec/quickshell-cpu-boost \
  /etc/polkit-1/rules.d/50-quickshell-cpu-boost.rules
rm ~/.config/systemd/user/cpu-boost-restore.service
systemctl --user daemon-reload
```

Polkit authorizes `pkexec` requests by executable path, and the rule checks the
requesting user plus active local session. See the [polkit rule reference](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)
and [`pkexec` security notes](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html).

A write that requires elevated privileges uses `pkexec`; cancellation and
write errors are displayed in the popup. Once the scoped system integration is
installed, changing or restoring this one setting does not ask for a password.

### TLP integration

If TLP manages CPU boost through `CPU_BOOST_ON_AC`, `CPU_BOOST_ON_BAT`, or
`CPU_BOOST_ON_SAV`, its profile switch will override the Quickshell preference
when AC power changes. Leave those settings commented out in `/etc/tlp.conf`
and any `/etc/tlp.d/*.conf` drop-ins so the Quickshell switch remains the owner
of this setting. After changing TLP configuration, apply it with `sudo tlp
start`; the saved Quickshell preference is then restored independently at
login.

The switch controls whether the kernel may use frequency boost. An enabled
state does not mean the CPU is boosting at that instant; workload, thermal
headroom, and platform power limits still apply. The kernel can omit this
interface when the driver does not support runtime boost control. See the
[Linux CPUFreq documentation](https://docs.kernel.org/admin-guide/pm/cpufreq.html#frequency-boost-support).

`tests/test_cpu_boost.py` verifies sysfs detection, Intel's inverse setting,
state writes, preference storage, and the unsupported case without touching the
host's real sysfs.

### Power profiles and charge thresholds

The reproducible Arch profiles use `power-profiles-daemon` as the sole owner
of platform power profiles. Do not run TLP alongside it: both can write the
same firmware profile, and TLP's event handlers can reapply settings after
PPD changes them. PPD covers the firmware platform profiles, not all of TLP's
extra runtime-PM, Wi-Fi, or USB autosuspend policies. After migration, those
devices follow kernel/driver defaults except for explicit host udev rules.

PPD does not manage battery charge thresholds. On supported ThinkPads, install
`sudo scripts/install-battery-charge-limit-system.sh` once to add a fixed
root-owned helper and a user-scoped Polkit rule. The helper accepts 80
(75/80 eco limit) or 100 (temporary full-charge mode); 100 requires external
power. It writes only the battery's kernel-exposed start/end threshold files. The
existing popup can then keep using the feature without TLP. Hardware without
those sysfs controls has no charge-limit action. The older TLP command fallback
remains for unconverted installations.

The system unit `quickshell-power-source-policy.service` watches udev power
supply events. On AC it selects `balanced` and `s2idle`; on battery it selects
`power-saver` and `deep`. If the charge limit is at 100% when AC is unplugged,
it restores 75/80 automatically. It performs the same source selection at
startup, so it also recovers when the machine boots on battery. A manually
selected PPD profile stays in effect until the power source changes.

On this host, migrate with `sudo scripts/migrate-tlp-to-ppd.sh`. It backs up
`/etc/tlp.conf` and `/etc/tlp.d` under
`~/.local/share/quickshell/migrations/`, installs the system policy unit and
scoped charge helper, disables the old user TLP monitor, removes TLP (and its
optional `tlp-rdw` companion), and installs/enables the replacement system
unit. To reinstall its helper and unit, run
`sudo scripts/install-battery-charge-limit-system.sh`. TLP's other device-level policies such as USB autosuspend,
runtime PM deny lists, Wi-Fi power save, sound power save, and AMD panel
brightness are not yet reproduced by this service; their effective values
come from kernel and driver defaults. The archived TLP configuration remains
available for reference or rollback.
