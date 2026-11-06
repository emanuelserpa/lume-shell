#!/usr/bin/env python3
"""Return CPU and memory usage from procfs as a compact JSON snapshot."""

import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True

VERSION = 1


def cpu_counters(proc_root):
    """Read aggregate CPU ticks as (total, idle + iowait)."""
    try:
        line = (Path(proc_root) / "stat").read_text(encoding="ascii").splitlines()[0]
        fields = line.split()
        if fields[0] != "cpu":
            return None
        ticks = [int(value) for value in fields[1:9]]
        if len(ticks) < 4:
            return None
    except (OSError, IndexError, ValueError):
        return None
    idle = ticks[3] + (ticks[4] if len(ticks) > 4 else 0)
    return sum(ticks), idle


def memory_usage(proc_root):
    """Use MemAvailable so reclaimable cache is not reported as pressure."""
    try:
        values = {}
        for line in (Path(proc_root) / "meminfo").read_text(encoding="ascii").splitlines():
            key, value = line.split(":", 1)
            if key in {"MemTotal", "MemAvailable"}:
                values[key] = int(value.strip().split()[0])
        total_kb = values["MemTotal"]
        available_kb = values["MemAvailable"]
    except (OSError, KeyError, IndexError, ValueError):
        return {"used_mb": 0, "total_mb": 0, "percent": 0}

    used_kb = max(0, total_kb - available_kb)
    return {
        "used_mb": round(used_kb / 1024, 1),
        "total_mb": round(total_kb / 1024, 1),
        "percent": round(used_kb * 100 / total_kb) if total_kb else 0,
    }


def cpu_frequency_mhz(sys_root="/sys"):
    """Return the mean live frequency of online CPUs from cpufreq sysfs."""
    cpu_root = Path(sys_root) / "devices/system/cpu"
    frequencies_khz = []

    for frequency_file in sorted(cpu_root.glob("cpu[0-9]*/cpufreq/scaling_cur_freq")):
        cpu_dir = frequency_file.parent.parent
        online_file = cpu_dir / "online"
        try:
            if online_file.exists() and online_file.read_text(encoding="ascii").strip() == "0":
                continue
            frequency_khz = int(frequency_file.read_text(encoding="ascii").strip())
        except (OSError, ValueError):
            continue
        if frequency_khz > 0:
            frequencies_khz.append(frequency_khz)

    if not frequencies_khz:
        return None
    return round(sum(frequencies_khz) / len(frequencies_khz) / 1000)


def get_status(proc_root="/proc", previous_total=0, previous_idle=0, sys_root="/sys"):
    counters = cpu_counters(proc_root)
    total_ticks, idle_ticks = counters if counters else (0, 0)
    delta_total = total_ticks - previous_total
    delta_idle = idle_ticks - previous_idle
    percent = None
    if previous_total > 0 and delta_total > 0:
        percent = round(max(0, min(100, (delta_total - delta_idle) * 100 / delta_total)))

    return {
        "ok": True,
        "version": VERSION,
        "cpu": {
            "percent": percent,
            "frequency_mhz": cpu_frequency_mhz(sys_root),
            "total_ticks": total_ticks,
            "idle_ticks": idle_ticks,
        },
        "memory": memory_usage(proc_root),
        "error": None,
    }


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    try:
        previous_total = int(argv[0]) if len(argv) > 0 else 0
        previous_idle = int(argv[1]) if len(argv) > 1 else 0
    except ValueError:
        previous_total = previous_idle = 0
    print(json.dumps(get_status(previous_total=previous_total, previous_idle=previous_idle)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
