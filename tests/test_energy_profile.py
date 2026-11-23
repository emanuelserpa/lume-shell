import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tests.helpers import import_script

energy_mod = import_script("energy_profile_extra", "energy-profile.py")


def build_fake_sys(tmp_dir, *, scaling_max=4000000, cpuinfo_min=1400000,
                   cpuinfo_max=4000000, boost="1"):
    sys_root = Path(tmp_dir) / "sys"
    policy = sys_root / "devices/system/cpu/cpufreq/policy0"
    policy.mkdir(parents=True)
    (policy / "cpuinfo_min_freq").write_text(f"{cpuinfo_min}\n", encoding="ascii")
    (policy / "cpuinfo_max_freq").write_text(f"{cpuinfo_max}\n", encoding="ascii")
    (policy / "scaling_max_freq").write_text(f"{scaling_max}\n", encoding="ascii")
    (sys_root / "devices/system/cpu/cpufreq/boost").write_text(f"{boost}\n", encoding="ascii")
    return sys_root


class EnergyProfileExtraLowPowerTest(unittest.TestCase):
    def test_cpufreq_cap_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            sys_root = build_fake_sys(tmp, scaling_max=4000000)
            self.assertTrue(energy_mod.cpufreq_cap_supported(sys_root))
            self.assertFalse(energy_mod.cpufreq_is_capped(sys_root))

            capped_root = build_fake_sys(tmp + "-cap", scaling_max=1600000, boost="0")
            self.assertTrue(energy_mod.cpufreq_is_capped(capped_root))

    def test_entering_and_exiting_extra_low_power_via_platform_helper(self):
        with tempfile.TemporaryDirectory() as tmp:
            sys_root = build_fake_sys(tmp, scaling_max=4000000, boost="1")
            state_path = Path(tmp) / "power-profile.json"
            boost_pref = Path(tmp) / "cpu-boost.json"
            boost_pref.write_text(json.dumps({"version": 1, "enabled": True}), encoding="utf-8")
            helper = Path(tmp) / "lumeshell-power-profile"
            helper.write_text("#!/bin/sh\n", encoding="utf-8")

            backend = {
                "available": True,
                "backend": "platform-profile",
                "backend_label": "Platform profile",
                "active": "balanced",
                "profiles": [
                    {"id": "power-saver", "label": "Economia"},
                    {"id": "balanced", "label": "Equilibrado"},
                    {"id": "performance", "label": "Desempenho"},
                ],
                "requires_auth": True,
            }
            calls = []

            def fake_run(args, timeout=3.0):
                calls.append(args)
                return 0, "", ""

            with patch.object(energy_mod, "ppd_state", return_value=None), \
                 patch.object(energy_mod, "platform_state", return_value=dict(backend)), \
                 patch.object(energy_mod, "platform_target", return_value="low-power"):
                ok, err = energy_mod.apply_profile(
                    "extra-low-power",
                    auto=True,
                    sys_root=sys_root,
                    state_path=state_path,
                    boost_pref_path=boost_pref,
                    runner=fake_run,
                    which=lambda name: "/usr/bin/pkexec" if name == "pkexec" else None,
                    helper_path=helper,
                )

            self.assertTrue(ok)
            self.assertEqual(err, "")
            self.assertEqual(
                calls[0],
                ["/usr/bin/pkexec", str(helper), "apply", "low-power", "cap-1600000", "boost-off"],
            )
            saved = energy_mod.read_saved_state(state_path)
            self.assertTrue(saved["extra_low_power"])
            self.assertTrue(saved["auto"])
            self.assertEqual(saved["previous_profile"], "balanced")

            # Simulate hardware capped & low-power active, then restore balanced.
            (sys_root / "devices/system/cpu/cpufreq/policy0/scaling_max_freq").write_text("1600000\n", encoding="ascii")
            backend_after = dict(backend, active="power-saver")
            with patch.object(energy_mod, "ppd_state", return_value=None), \
                 patch.object(energy_mod, "platform_state", return_value=backend_after):
                cur = energy_mod.current_state(sys_root=sys_root, state_path=state_path)
            self.assertEqual(cur["active"], "extra-low-power")
            self.assertTrue(cur["extra_low_power"])
            self.assertTrue(cur["auto_activated"])
            self.assertEqual(cur["profiles"][0]["id"], "extra-low-power")

            calls.clear()
            with patch.object(energy_mod, "ppd_state", return_value=None), \
                 patch.object(energy_mod, "platform_state", return_value=dict(backend_after)), \
                 patch.object(energy_mod, "platform_target", return_value="balanced"):
                ok2, err2 = energy_mod.apply_profile(
                    "balanced",
                    sys_root=sys_root,
                    state_path=state_path,
                    boost_pref_path=boost_pref,
                    runner=fake_run,
                    which=lambda name: "/usr/bin/pkexec" if name == "pkexec" else None,
                    helper_path=helper,
                )
            self.assertTrue(ok2, err2)
            self.assertEqual(err2, "")
            self.assertEqual(
                calls[0],
                ["/usr/bin/pkexec", str(helper), "apply", "balanced", "max", "boost-on"],
            )
            self.assertFalse(energy_mod.read_saved_state(state_path)["extra_low_power"])

    def test_stale_extra_low_power_flag_clears_when_hardware_uncapped(self):
        with tempfile.TemporaryDirectory() as tmp:
            sys_root = build_fake_sys(tmp, scaling_max=4000000, boost="1")
            state_path = Path(tmp) / "power-profile.json"
            energy_mod.write_saved_state(
                {"extra_low_power": True, "auto": True, "previous_profile": "balanced"},
                state_path,
            )
            backend = {
                "available": True,
                "backend": "platform-profile",
                "backend_label": "Platform profile",
                "active": "power-saver",
                "profiles": [{"id": "power-saver", "label": "Economia"}],
                "requires_auth": True,
            }
            with patch.object(energy_mod, "ppd_state", return_value=None), \
                 patch.object(energy_mod, "platform_state", return_value=backend):
                cur = energy_mod.current_state(sys_root=sys_root, state_path=state_path)
            self.assertEqual(cur["active"], "power-saver")
            self.assertFalse(cur["extra_low_power"])
            self.assertFalse(energy_mod.read_saved_state(state_path)["extra_low_power"])


if __name__ == "__main__":
    unittest.main()
