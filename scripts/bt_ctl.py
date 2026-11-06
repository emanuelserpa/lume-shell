#!/usr/bin/env python3
"""Shared bluetoothctl runner for the quickshell Bluetooth helpers.

Why this exists: bluetoothctl 5.87 aborts with SIGABRT inside
``dbus_connection_get_object_path_data`` on simple read-only commands
(upstream bluez/bluez#2434, still open). The abort is rare per call, but
the shell spawns bluetoothctl every few seconds, and overlapping
instances racing on D-Bus are the suspected trigger.

This runner therefore:
  1. serializes concurrent bluetoothctl invocations through a lockfile
     (waits briefly, never longer than the caller's timeout);
  2. retries once when the process dies from a signal (e.g. SIGABRT);
  3. keeps the ``(returncode, stdout, stderr)`` contract of the previous
     per-script ``run()`` helpers, so callers are unchanged.
"""
import fcntl
import subprocess
import tempfile
import time
from pathlib import Path

LOCK_PATH = Path(tempfile.gettempdir()) / "quickshell-bluetoothctl.lock"
ACQUIRE_STEP = 0.05


def _acquire(deadline_s):
    """Best-effort non-blocking lock with a bounded wait. Returns the
    open file handle when held (caller must release), else None."""
    try:
        fh = open(LOCK_PATH, "w")
    except OSError:
        return None
    waited = 0.0
    while True:
        try:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return fh
        except OSError:
            if waited >= deadline_s:
                try:
                    fh.close()
                except OSError:
                    pass
                return None
            time.sleep(ACQUIRE_STEP)
            waited += ACQUIRE_STEP


def _release(fh):
    if fh is None:
        return
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    except OSError:
        pass
    try:
        fh.close()
    except OSError:
        pass


def _invoke(args, timeout):
    try:
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except subprocess.TimeoutExpired:
        return 124, "", "tempo esgotado"
    except Exception as exc:
        return 1, "", str(exc)


def run_bt(args, timeout=6):
    """Run a bluetoothctl command serialized + retried once on crash."""
    args = list(args)
    wait_budget = max(0.0, min(2.0, timeout - 1.0))
    lock = _acquire(wait_budget)
    try:
        rc, out, err = _invoke(args, timeout)
        # Negative rc (killed by signal) or 134 (SIGABRT): transient
        # client-side abort, retry once before giving up.
        if rc < 0 or rc == 134:
            time.sleep(0.3)
            rc, out, err = _invoke(args, timeout)
        return rc, out, err
    finally:
        _release(lock)
