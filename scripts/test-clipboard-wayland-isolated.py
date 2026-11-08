#!/usr/bin/env python3
"""Exercise clipboard pause/resume against an isolated headless Labwc seat.

All XDG state and the Wayland socket live in a temporary directory. The
user's active compositor and clipboard are never queried or modified.
"""

from __future__ import annotations

import json
import os
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DAEMON = ROOT / "scripts" / "clipboard-daemon.py"
LAUNCHER = ROOT / "scripts" / "launcher-data.py"


def require_commands() -> None:
    missing = [name for name in ("labwc", "dbus-run-session", "wl-copy", "wl-paste")
               if shutil.which(name) is None]
    if missing:
        raise RuntimeError("Missing test dependencies: " + ", ".join(missing))


def run_helper(env: dict[str, str], *args: str) -> dict:
    result = subprocess.run(
        [sys.executable, "-B", str(LAUNCHER), *args],
        env=env, capture_output=True, text=True, timeout=5,
    )
    if result.returncode != 0:
        raise RuntimeError(f"helper failed ({result.returncode}): {result.stderr.strip()}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"helper returned invalid JSON: {result.stdout!r}") from error
    if not payload.get("ok"):
        raise RuntimeError(f"helper rejected request: {payload!r}")
    return payload


def snapshot(env: dict[str, str]) -> dict:
    result = subprocess.run(
        [sys.executable, "-B", str(DAEMON), "--status"],
        env=env, capture_output=True, text=True, timeout=5,
    )
    if result.returncode != 0:
        raise RuntimeError(f"clipboard status failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def copy_text(env: dict[str, str], value: str) -> None:
    subprocess.run(
        ["wl-copy", "--trim-newline"], input=value, text=True,
        env=env, check=True, timeout=5,
    )


def wait_for_text(env: dict[str, str], expected: str, timeout: float = 8.0) -> dict:
    deadline = time.monotonic() + timeout
    latest = {}
    while time.monotonic() < deadline:
        latest = snapshot(env)
        if any(expected in item.get("fullText", "") for item in latest.get("recent", [])):
            return latest
        time.sleep(0.1)
    raise RuntimeError(f"clipboard event not captured: {expected!r}; latest={latest!r}")


def stop_process(process: subprocess.Popen | None, *, group: bool = False) -> None:
    if process is None or process.poll() is not None:
        return
    try:
        if group:
            os.killpg(process.pid, signal.SIGTERM)
        else:
            process.terminate()
        process.wait(timeout=3)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        if process.poll() is None:
            if group:
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
            process.wait(timeout=3)


def main() -> int:
    require_commands()
    with tempfile.TemporaryDirectory(prefix="lume-p1-clipboard-wayland-") as root_text:
        root = Path(root_text)
        runtime = root / "runtime"
        config = root / "config" / "labwc"
        runtime.mkdir(mode=0o700)
        config.mkdir(parents=True)
        for name in ("data", "cache", "state"):
            (root / name).mkdir()

        env = os.environ.copy()
        env.update({
            "XDG_RUNTIME_DIR": str(runtime),
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_DATA_HOME": str(root / "data"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_STATE_HOME": str(root / "state"),
            "WAYLAND_DISPLAY": "wayland-lume-p1-clipboard",
            "WLR_BACKENDS": "headless",
            "WLR_RENDERER": "pixman",
            "WLR_LIBINPUT_NO_DEVICES": "1",
            "WLR_HEADLESS_OUTPUTS": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
        })

        compositor_log = (root / "labwc.log").open("w+")
        daemon_log = (root / "clipboard-daemon.log").open("w+")
        compositor = daemon = None
        try:
            compositor = subprocess.Popen(
                ["dbus-run-session", "--", "labwc", "--debug",
                 "--config-dir", str(config)],
                env=env, stdout=compositor_log, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            socket = None
            deadline = time.monotonic() + 8
            while socket is None and compositor.poll() is None and time.monotonic() < deadline:
                socket = next((path for path in runtime.glob("wayland-*")
                               if stat.S_ISSOCK(path.stat().st_mode)), None)
                time.sleep(0.1)
            if socket is None:
                compositor_log.flush()
                compositor_log.seek(0)
                raise RuntimeError(
                    "headless Labwc did not create a Wayland socket "
                    f"(exit={compositor.poll()}, runtime={list(runtime.iterdir())!r}):\n"
                    + compositor_log.read()
                )
            env["WAYLAND_DISPLAY"] = socket.name

            copy_text(env, "lume-p1-baseline-sentinel-20261108")
            daemon = subprocess.Popen(
                [sys.executable, "-B", str(DAEMON)],
                env=env, stdout=daemon_log, stderr=subprocess.STDOUT,
            )
            deadline = time.monotonic() + 5
            while not (root / "data" / "quickshell" / "clipboard" / "clipboard.db").exists():
                if daemon.poll() is not None:
                    daemon_log.flush()
                    daemon_log.seek(0)
                    raise RuntimeError("clipboard daemon exited:\n" + daemon_log.read())
                if time.monotonic() >= deadline:
                    raise RuntimeError("clipboard daemon did not initialize its isolated store")
                time.sleep(0.1)

            wait_for_text(env, "lume-p1-baseline-sentinel-20261108")
            time.sleep(0.5)
            run_helper(env, "clipboard-capture", "pause")
            pause_state = run_helper(env, "clipboard-capture-state")
            if not pause_state.get("paused"):
                raise RuntimeError(f"pause did not become visible to helper: {pause_state!r}")
            copy_text(env, "lume-p1-paused-sentinel-20261108")
            time.sleep(1.5)
            paused = snapshot(env)
            if any("lume-p1-paused-sentinel-20261108" in item.get("fullText", "")
                   for item in paused.get("recent", [])):
                raise RuntimeError(
                    "paused clipboard content was captured; "
                    f"preference={pause_state!r}, snapshot={paused!r}"
                )
            if not run_helper(env, "clipboard-capture-state").get("paused"):
                raise RuntimeError("pause preference did not persist")

            run_helper(env, "clipboard-capture", "resume")
            copy_text(env, "lume-p1-resumed-sentinel-20261108")
            resumed = wait_for_text(env, "lume-p1-resumed-sentinel-20261108")
            if any("lume-p1-paused-sentinel-20261108" in item.get("fullText", "")
                   for item in resumed.get("recent", [])):
                raise RuntimeError("paused sentinel appeared after resume")
            if run_helper(env, "clipboard-capture-state").get("paused"):
                raise RuntimeError("resume preference was not persisted")

            print("Headless Wayland clipboard passed: pause ignored selection event; "
                  "resume captured the next event; isolated state only.")
            return 0
        finally:
            if compositor is not None and compositor.poll() is None:
                subprocess.run(["wl-copy", "--clear"], env=env,
                               capture_output=True, text=True, timeout=3)
                time.sleep(0.2)
            stop_process(daemon)
            stop_process(compositor, group=True)
            daemon_log.close()
            compositor_log.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Clipboard Wayland integration failed: {error}", file=sys.stderr)
        raise SystemExit(1)
