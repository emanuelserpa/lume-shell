import tempfile
import unittest
from pathlib import Path

from tests.helpers import import_script

cpu_boost = import_script("cpu_boost", "cpu-boost.py")


class CpuBoostTests(unittest.TestCase):
    def make_sysfs(self, relative, value):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        path = Path(temp.name) / relative
        path.parent.mkdir(parents=True)
        path.write_text(value, encoding="ascii")
        return Path(temp.name), path

    def test_reads_generic_boost_enabled(self):
        root, _ = self.make_sysfs("devices/system/cpu/cpufreq/boost", "1\n")
        result = cpu_boost.current_state(root)
        self.assertTrue(result["available"])
        self.assertTrue(result["enabled"])

    def test_reads_intel_no_turbo_as_inverted_boost(self):
        root, _ = self.make_sysfs("devices/system/cpu/intel_pstate/no_turbo", "1\n")
        self.assertFalse(cpu_boost.current_state(root)["enabled"])

    def test_writes_generic_boost_state(self):
        root, path = self.make_sysfs("devices/system/cpu/cpufreq/boost", "0\n")
        preference = path.parent.parent.parent / "saved-preference.json"
        ok, error = cpu_boost.set_state(True, root, preference=preference)
        self.assertTrue(ok)
        self.assertEqual(error, "")
        self.assertEqual(path.read_text(encoding="ascii"), "1")
        self.assertTrue(cpu_boost.read_preference(preference))

    def test_writes_inverted_intel_state(self):
        root, path = self.make_sysfs("devices/system/cpu/intel_pstate/no_turbo", "1\n")
        ok, _ = cpu_boost.set_state(True, root, save_preference=False)
        self.assertTrue(ok)
        self.assertEqual(path.read_text(encoding="ascii"), "0")

    def test_reports_unsupported_without_sysfs_control(self):
        with tempfile.TemporaryDirectory() as root:
            result = cpu_boost.current_state(root)
            self.assertTrue(result["ok"])
            self.assertFalse(result["available"])

    def test_saves_and_reads_preference_atomically(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "power" / "cpu-boost.json"
            cpu_boost.write_preference(False, path)
            self.assertFalse(cpu_boost.read_preference(path))
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_first_install_default_is_off(self):
        with tempfile.TemporaryDirectory() as temp:
            preference = Path(temp) / "power" / "cpu-boost.json"
            result = cpu_boost.initialize_default_preference(preference)
            self.assertTrue(result["saved"])
            self.assertFalse(result["enabled"])
            self.assertFalse(cpu_boost.read_preference(preference))

    def test_default_initialization_preserves_existing_user_choice(self):
        with tempfile.TemporaryDirectory() as temp:
            preference = Path(temp) / "cpu-boost.json"
            cpu_boost.write_preference(True, preference)
            result = cpu_boost.initialize_default_preference(preference)
            self.assertFalse(result["saved"])
            self.assertTrue(result["enabled"])
            self.assertTrue(cpu_boost.read_preference(preference))

    def test_restore_does_not_prompt_when_there_is_no_saved_preference(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "missing.json"
            result = cpu_boost.restore_preference(path=path, sys_root=temp)
            self.assertTrue(result["ok"])
            self.assertFalse(result["restored"])

    def test_restore_calls_only_the_installed_fixed_helper(self):
        root, sysfs = self.make_sysfs("devices/system/cpu/cpufreq/boost", "0\n")
        with tempfile.TemporaryDirectory() as temp:
            preference = Path(temp) / "cpu-boost.json"
            helper = Path(temp) / "quickshell-cpu-boost"
            helper.touch()
            cpu_boost.write_preference(True, preference)
            calls = []

            def runner(args, *_args, **_kwargs):
                calls.append(args)
                sysfs.write_text("1", encoding="ascii")
                return 0, "", ""

            result = cpu_boost.restore_preference(
                runner=runner,
                which=lambda name: "/usr/bin/pkexec" if name == "pkexec" else None,
                helper_path=helper,
                sys_root=root,
                path=preference,
            )

        self.assertTrue(result["ok"])
        self.assertTrue(result["restored"])
        self.assertEqual(calls, [["/usr/bin/pkexec", str(helper), "on"]])


if __name__ == "__main__":
    unittest.main()
