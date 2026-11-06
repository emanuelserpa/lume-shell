import tempfile
import unittest
from pathlib import Path

from tests.helpers import import_script

battery = import_script("battery_charge_limit", "battery-charge-limit.py")


class BatteryChargeLimitTests(unittest.TestCase):
    def test_scoped_helper_is_used_when_installed(self):
        with tempfile.TemporaryDirectory() as temp:
            helper = Path(temp) / "helper"
            helper.touch()
            calls = []

            def runner(args, **kwargs):
                calls.append((args, kwargs))
                return 0, "", ""

            ok, error = battery.apply_limit(
                80, runner=runner,
                which=lambda name: "/usr/bin/pkexec" if name == "pkexec" else None,
                helper_path=helper, ac_power=lambda: True,
            )

        self.assertTrue(ok)
        self.assertEqual(error, "")
        self.assertEqual(calls[0][0], ["/usr/bin/pkexec", str(helper), "80"])

    def test_rejects_changes_on_battery_without_invoking_privileged_command(self):
        calls = []
        ok, error = battery.apply_limit(100, runner=lambda *a, **k: calls.append(a), ac_power=lambda: False)
        self.assertFalse(ok)
        self.assertIn("carregador", error)
        self.assertEqual(calls, [])

    def test_legacy_tlp_fallback_remains_available(self):
        calls = []

        def runner(args, **kwargs):
            calls.append(args)
            return 0, "", ""

        ok, _ = battery.apply_limit(
            100, runner=runner,
            which=lambda name: {"tlp": "/usr/bin/tlp", "sudo": "/usr/bin/sudo"}.get(name),
            helper_path=Path("/nonexistent/helper"), ac_power=lambda: True,
        )
        self.assertTrue(ok)
        self.assertEqual(calls, [["/usr/bin/sudo", "-n", "/usr/bin/tlp", "fullcharge", "BAT0"]])


if __name__ == "__main__":
    unittest.main()
