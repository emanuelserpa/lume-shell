import importlib.util
import tempfile
import unittest
from pathlib import Path

from tests.helpers import SCRIPT_DIR

SCRIPT_PATH = Path(SCRIPT_DIR) / "hardware-sensors.py"
SPEC = importlib.util.spec_from_file_location("hardware_sensors", SCRIPT_PATH)
sensors = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sensors)


class TestSystemSensors(unittest.TestCase):
    def make_tree(self, root, files):
        base = Path(root)
        for relative, content in files.items():
            path = base / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        return base

    def test_prefers_k10temp_tctl_and_detects_fan(self):
        with tempfile.TemporaryDirectory() as tempdir:
            hwmon = self.make_tree(tempdir, {
                "hwmon0/name": "k10temp",
                "hwmon0/temp1_label": "Tctl",
                "hwmon0/temp1_input": "45000",
                "hwmon0/temp2_label": "Tccd1",
                "hwmon0/temp2_input": "43000",
                "hwmon1/name": "thinkpad",
                "hwmon1/fan1_input": "2200",
                "hwmon1/pwm1_enable": "1",
                "hwmon1/pwm1": "128",
            })
            result = sensors.get_status(hwmon, hwmon / "thermal")

        self.assertTrue(result["ok"])
        self.assertEqual(result["temperature"], {
            "available": True, "temp_c": 45.0, "sensor": "k10temp/Tctl"
        })
        self.assertEqual(result["fan"], {
            "available": True, "rpm": 2200, "sensor": "thinkpad",
            "pwm_percent": 50,
        })

    def test_uses_thermal_cpu_zone_when_hwmon_cpu_sensor_is_missing(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            hwmon = self.make_tree(root / "hwmon", {
                "hwmon0/name": "acpitz",
                "hwmon0/temp1_input": "30000",
            })
            thermal = self.make_tree(root / "thermal", {
                "thermal_zone0/type": "x86_pkg_temp",
                "thermal_zone0/temp": "60000",
            })
            result = sensors.get_status(hwmon, thermal)

        self.assertEqual(result["temperature"]["temp_c"], 60.0)
        self.assertEqual(result["temperature"]["sensor"], "x86_pkg_temp")

    def test_prefers_thinkpad_fan_over_generic_hwmon(self):
        with tempfile.TemporaryDirectory() as tempdir:
            hwmon = self.make_tree(tempdir, {
                "hwmon0/name": "other",
                "hwmon0/fan1_input": "900",
                "hwmon1/name": "thinkpad_hwmon",
                "hwmon1/fan1_input": "1800",
                "hwmon1/pwm1_enable": "1",
                "hwmon1/pwm1": "255",
            })
            result = sensors.fan_from_hwmon(hwmon)

        self.assertEqual(result, {
            "available": True, "rpm": 1800, "sensor": "thinkpad_hwmon",
            "pwm_percent": 100,
        })

    def test_uses_generic_fan_when_no_thinkpad_sensor_exists(self):
        with tempfile.TemporaryDirectory() as tempdir:
            hwmon = self.make_tree(tempdir, {
                "hwmon0/name": "acpitz",
                "hwmon0/fan1_input": "1200",
            })
            self.assertEqual(sensors.fan_from_hwmon(hwmon), {
                "available": True, "rpm": 1200, "sensor": "acpitz",
                "pwm_percent": None,
            })

    def test_reports_missing_sensors_without_failing_the_snapshot(self):
        with tempfile.TemporaryDirectory() as tempdir:
            root = Path(tempdir)
            result = sensors.get_status(root / "hwmon", root / "thermal")

        self.assertTrue(result["ok"])
        self.assertFalse(result["temperature"]["available"])
        self.assertEqual(result["fan"], {
            "available": False, "rpm": 0, "sensor": "unavailable",
            "pwm_percent": None,
        })


if __name__ == "__main__":
    unittest.main()
