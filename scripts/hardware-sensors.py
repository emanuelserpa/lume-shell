#!/usr/bin/env python3
"""Read CPU temperature and fan speed from Linux sysfs."""
import json
from pathlib import Path

VERSION = 1
THERMAL_TYPES = {"x86_pkg_temp", "cpu-thermal", "cpu_thermal", "soc_thermal"}


def read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def millis_to_celsius(raw):
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return None
    return value / 1000 if value > 1000 else value


def temperature_from_hwmon(base):
    for hwmon in sorted(Path(base).glob("hwmon*")):
        if read_text(hwmon / "name") != "k10temp":
            continue
        for label in sorted(hwmon.glob("temp*_label")):
            if read_text(label) != "Tctl":
                continue
            input_file = Path(str(label)[:-6] + "_input")
            temp = millis_to_celsius(read_text(input_file))
            if temp is not None:
                return temp, "k10temp/Tctl"
        inputs = sorted(hwmon.glob("temp*_input"))
        if inputs:
            temp = millis_to_celsius(read_text(inputs[0]))
            if temp is not None:
                return temp, "k10temp"
    return None


def temperature_from_thermal(base):
    zones = sorted(Path(base).glob("thermal_zone*"))
    for zone in zones:
        zone_type = read_text(zone / "type")
        if zone_type not in THERMAL_TYPES:
            continue
        temp = millis_to_celsius(read_text(zone / "temp"))
        if temp is not None:
            return temp, zone_type
    for zone in zones:
        raw = read_text(zone / "temp")
        if not raw:
            continue
        temp = millis_to_celsius(raw)
        if temp is not None:
            return temp, read_text(zone / "type") or "thermal"
    return None


def read_temperature(hwmon_base="/sys/class/hwmon", thermal_base="/sys/class/thermal"):
    found = temperature_from_hwmon(hwmon_base) or temperature_from_thermal(thermal_base)
    if found is None:
        return {"available": False, "temp_c": 0.0, "sensor": ""}
    temp_c, sensor = found
    return {"available": True, "temp_c": temp_c, "sensor": sensor}


def fan_from_hwmon(base):
    hwmons = sorted(Path(base).glob("hwmon*"))
    for hwmon in hwmons:
        name = read_text(hwmon / "name")
        if name not in {"thinkpad", "thinkpad_hwmon"}:
            continue
        reading = _fan_reading(hwmon, name)
        if reading:
            return reading
    for hwmon in hwmons:
        name = read_text(hwmon / "name") or "hwmon"
        reading = _fan_reading(hwmon, name)
        if reading:
            return reading
    return {
        "available": False,
        "rpm": 0,
        "sensor": "unavailable",
        "pwm_percent": None,
    }


def _fan_reading(hwmon, name):
    for input_file in sorted(hwmon.glob("fan*_input")):
        raw = read_text(input_file)
        if raw.isdigit():
            pwm_percent = None
            if name in {"thinkpad", "thinkpad_hwmon"} \
                    and read_text(hwmon / "pwm1_enable") == "1":
                pwm_raw = read_text(hwmon / "pwm1")
                if pwm_raw.isdigit():
                    pwm_percent = round(max(0, min(255, int(pwm_raw))) * 100 / 255)
            return {
                "available": True,
                "rpm": int(raw),
                "sensor": name,
                "pwm_percent": pwm_percent,
            }
    return None


def get_status(hwmon_base="/sys/class/hwmon", thermal_base="/sys/class/thermal"):
    return {
        "ok": True,
        "version": VERSION,
        "temperature": read_temperature(hwmon_base, thermal_base),
        "fan": fan_from_hwmon(hwmon_base),
        "error": None,
    }


def main():
    print(json.dumps(get_status(), ensure_ascii=False))


if __name__ == "__main__":
    main()
