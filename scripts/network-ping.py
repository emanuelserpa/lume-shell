#!/usr/bin/env python3
"""Measure latency via ICMP with TCP and NetworkManager connectivity fallbacks."""
import json
import os
import re
import socket
import subprocess
import time

from command_utils import run_command

VERSION = 1
PING_HOST = "1.1.1.1"
TCP_PROBE_HOST = "1.1.1.1"
TCP_PROBE_PORT = 443
TIME_RE = re.compile(r"(?:time|tempo)[=<]\s*([0-9]+(?:\.[0-9]+)?)", re.IGNORECASE)


def c_locale_env():
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    env["LANG"] = "C"
    return env


def parse_ping_ms(stdout):
    match = TIME_RE.search(stdout or "")
    if not match:
        return None
    return max(0, int(round(float(match.group(1)))))


def run_c(args, timeout=2.0):
    try:
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            env=c_locale_env(),
        )
        return proc.returncode, (proc.stdout or "").strip(), (proc.stderr or "").strip()
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except Exception as exc:  # noqa: BLE001
        return 1, "", str(exc)


def probe_icmp(host=PING_HOST, timeout=2.0):
    rc, stdout, _ = run_c(["ping", "-c", "1", "-W", "1", host], timeout=timeout)
    if rc != 0:
        return None
    return parse_ping_ms(stdout)


def probe_tcp(host=TCP_PROBE_HOST, port=TCP_PROBE_PORT, timeout=1.0):
    start = time.monotonic()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            elapsed_ms = (time.monotonic() - start) * 1000.0
            return max(0, int(round(elapsed_ms)))
    except OSError:
        return None


def nmcli_connectivity():
    for args in (
        ["nmcli", "networking", "connectivity", "check"],
        ["nmcli", "-g", "CONNECTIVITY", "general", "status"],
    ):
        rc, stdout, _ = run_c(args, timeout=1.5)
        if rc == 0 and stdout:
            value = stdout.splitlines()[0].strip().lower()
            if value and value != "unknown":
                return value
    return "unknown"


def has_default_route():
    for args in (
        ["ip", "-4", "route", "show", "default"],
        ["ip", "-6", "route", "show", "default"],
    ):
        rc, stdout, _ = run_command(args, timeout=1.0)
        if rc == 0 and stdout:
            return True
    return False


def check_connectivity():
    icmp_ms = probe_icmp()
    if icmp_ms is not None:
        return {
            "ok": True,
            "version": VERSION,
            "ping": icmp_ms,
            "status": "online",
            "method": "icmp",
            "error": None,
        }

    nm_state = nmcli_connectivity()
    if nm_state == "portal":
        return {
            "ok": True,
            "version": VERSION,
            "ping": -1,
            "status": "portal",
            "method": "nmcli",
            "error": None,
        }
    if nm_state == "none":
        return {
            "ok": True,
            "version": VERSION,
            "ping": -1,
            "status": "offline",
            "method": "nmcli",
            "error": None,
        }

    tcp_ms = probe_tcp()
    if tcp_ms is not None:
        return {
            "ok": True,
            "version": VERSION,
            "ping": tcp_ms,
            "status": "online",
            "method": "tcp",
            "error": None,
        }

    if nm_state == "full":
        status = "online"
        method = "nmcli"
    elif nm_state == "limited":
        status = "limited"
        method = "nmcli"
    elif not has_default_route():
        status = "offline"
        method = "route"
    else:
        status = "unknown"
        method = "none"

    return {
        "ok": True,
        "version": VERSION,
        "ping": -1,
        "status": status,
        "method": method,
        "error": None,
    }


def main():
    print(json.dumps(check_connectivity(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
