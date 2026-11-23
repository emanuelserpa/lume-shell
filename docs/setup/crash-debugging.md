# Crash investigation — 2026-10-24

Two matching crashes are confirmed by systemd cores, not just Quickshell's
report directory (the second report directory was no longer present):

| Resume | Unlock | Crash | Core PID |
| --- | --- | --- | --- |
| 20:49:43 | 20:49:47 | 20:49:54 | 961619 |
| 22:47:19 | 22:47:24 | 22:47:27 | 1015762 |

All times are America/Fortaleza. Both cores fault in
`QObjectPrivate::ConnectionData::cleanOrphanedConnectionsImpl`, called from
`QQuickWindowPrivate::renderSceneGraph`. GDB reports `rdi=0x2`, `rbx=0x3`
at the faulting frame in both. Both preserve only the crashing render thread.
The Quickshell crash handler forks before raising the signal for the core;
the surviving single thread therefore does not establish that the live shell
had only one thread. Earlier crashes in QML Models and icon loading have
different stacks and should not be treated as proof of the same bug.

The strongest current trigger candidate is suspend/resume followed by unlock.
Two correlated occurrences do not prove root cause or isolate which stage is
necessary. Both resumes also logged a syntax error from the hypridle command
`hyprctl dispatch dpms on`; this is a separate confirmed error, with no proven
causal connection to the segmentation fault. No rendering workaround or
hypridle change was applied during this diagnostic setup.

## Active diagnostic mode

`~/.config/systemd/user/quickshell.service.d/90-crash-debug.conf` runs Quickshell
directly in its user service with `QS_DISABLE_CRASH_HANDLER=1`, timestamps and
an unlimited process core limit. The existing systemd `Restart=on-failure`
provides recovery. The graphical-session dependency and session environment
remain supplied by the existing user service/session.

Activation verified at 22:53:52: PID 1025288 belongs to `quickshell.service`,
the log confirms `Crash handling disabled.` and `Configuration Loaded`, and
the instance is available on `wayland-1`. The existing PowerProfilesDaemon
availability warning remains. No crash has yet been captured in this mode.

The next fault should produce a systemd core of the original process with all
threads, rather than the crash handler's fork. The Quickshell crash dialog and
its report directory are disabled in this mode. Systemd core storage limits
and retention still apply. Use `coredumpctl list --since today` without a
`quickshell` positional filter: old entries can be named `QSGRenderThread`.

After recurrence, record the exact time and collect:

```sh
coredumpctl info <PID>
coredumpctl debug <PID> --debugger-arguments="-batch -ex 'set debuginfod enabled off' -ex 'thread apply all bt full'"
journalctl --user --since '<two minutes before>' --until '<one minute after>'
quickshell log --no-color -vv /run/user/1000/quickshell/by-id/<old-instance>/log.qslog
```

Preserve the old instance log and core before log cleanup or package upgrades.
Current binaries must match a core; obtain matching debug symbols when needed.
Logs/cores can contain private app state and should remain local by default.

## Reproduction sequence

On the user's next suitable opportunity, compare separately: lock/unlock
without suspend; display off/on without suspend; suspend/resume/unlock.
Record successes as well as crashes. Do not automatically suspend or lock the
user's active desktop as part of collection. Keep the default render loop and
UI unchanged while collecting this baseline; only then test one mitigation
at a time. A single successful cycle is not evidence that the bug is fixed.

To leave diagnostic mode, remove only `90-crash-debug.conf`, then run
`systemctl --user daemon-reload` and `systemctl --user restart quickshell.service`.
Do not use `systemctl revert`, which may remove unrelated overrides.

Source inspected: Quickshell `src/crash/handler.cpp` (fork before raise) and
`src/launch/launch.cpp` (`QS_DISABLE_CRASH_HANDLER`), from
https://github.com/quickshell-mirror/quickshell/tree/master/src . The option
also exists in the installed binary. Runtime activation is checked in its log.
