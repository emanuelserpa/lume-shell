#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True
import unittest
from unittest.mock import patch

from tests.helpers import import_script, read_fixture

status_mod = import_script("brightness_status", "brightness-status.py")
action_mod = import_script("brightness_action", "brightness-action.py")


class TestBrightnessContracts(unittest.TestCase):
    def test_status_fixture_normalizes_csv(self):
        result = status_mod.parse_status(read_fixture("brightnessctl_m.txt"))
        self.assertEqual(result, {
            "ok": True,
            "version": 1,
            "available": True,
            "brightness": 67,
            "device": "amdgpu_bl1",
            "error": None,
        })

    def test_status_failure_has_stable_shape(self):
        result = status_mod.parse_status("", returncode=1, error="missing device")
        self.assertFalse(result["ok"])
        self.assertFalse(result["available"])
        self.assertEqual(result["error"], "missing device")
        self.assertEqual(result["version"], 1)

    def test_status_rejects_missing_percentage(self):
        result = status_mod.parse_status("backlight,device,unknown,4,10")
        self.assertFalse(result["ok"])
        self.assertFalse(result["available"])
        self.assertEqual(result["error"], "Saída inválida do brightnessctl.")

    def test_action_validates_range_before_running_command(self):
        with patch.object(action_mod, "run_command") as run:
            result, code = action_mod.set_brightness("0")
        self.assertEqual(code, 2)
        self.assertFalse(result["ok"])
        run.assert_not_called()

    def test_action_returns_command_failure(self):
        with patch.object(action_mod, "run_command", return_value=(1, "", "permission denied")):
            result, code = action_mod.set_brightness("67")
        self.assertEqual(code, 1)
        self.assertFalse(result["ok"])
        self.assertEqual(result["version"], 1)
        self.assertEqual(result["error"], "permission denied")

    def test_action_success_uses_argument_list(self):
        with patch.object(action_mod, "run_command", return_value=(0, "", "")) as run:
            result, code = action_mod.set_brightness("67")
        self.assertEqual(code, 0)
        self.assertTrue(result["ok"])
        self.assertEqual(result["brightness"], 67)
        run.assert_called_once_with(["brightnessctl", "set", "67%"], timeout=12, timeout_code=None)


if __name__ == "__main__":
    unittest.main()
