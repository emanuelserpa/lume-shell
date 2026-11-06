# System monitor pill

`bar/SystemMonitor.qml` adds a compact CPU-only pill to the right side of the
top bar. Clicking it opens `bar/SystemMonitorPopup.qml`, which shows average
live CPU frequency in MHz, memory in used/total GiB, CPU temperature with a
range bar, and fan speed with a rotating icon when the fan is running.
Frequency is averaged across online CPUs that expose `scaling_cur_freq`; it is
unavailable when cpufreq data is not exposed. The popup uses the shared
`PopupHeader` and `PopupListRow` components and the active theme's spacing,
typography, icon, radius, and surface tokens. The outer popup is the single
card surface; metric rows use quiet separators rather than nested cards. Local
theme-tinted vector icons identify CPU, memory, temperature, and fan. Its four
metric rows share the same geometry and hierarchy; the small usage bars and
running-fan animation remain domain-specific. The CPU pill is mounted in the
bar and its popup remains reachable from Quick Settings.
The pill polls `scripts/system-usage.py` every five seconds while the bar is
mounted. CPU load becomes available after the second sample because it is
calculated from counter deltas. The bar indicator remains icon-only: neutral at
normal load, yellow from 70%, and red from 90%; its tooltip gives the exact
percentage and label, while the popup shows the other metrics.

The calendar dashboard keeps its holiday pills and does not start telemetry
polling. `scripts/hardware-sensors.py` discovers temperature and fan sensors in
one pass and polls only while the details popup is open. FileView reads a known
file path, while these sensor paths require runtime discovery across hwmon and
thermal-zone directories, so that discovery stays in the testable helper. On
ThinkPad hardware, the fan row also reads the requested PWM percentage so it
can distinguish a stopped fan from a fan commanded to run when the tachometer
still reports zero RPM.

`tests/test_system_usage.py` covers the procfs calculations. QML and runtime
integration are checked by `scripts/validate.sh` and the standard Quickshell
service restart.
