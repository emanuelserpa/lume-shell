#!/usr/bin/env python3
import tempfile
import unittest
from pathlib import Path

from tests.helpers import import_script

system_usage = import_script("system_usage", "system-usage.py")


class TestSystemUsage(unittest.TestCase):
    def _proc(self, root, stat, meminfo):
        proc = Path(root)
        (proc / "stat").write_text(stat, encoding="ascii")
        (proc / "meminfo").write_text(meminfo, encoding="ascii")
        return proc

    def test_cpu_percentage_uses_previous_snapshot_and_excludes_guest_ticks(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = self._proc(
                tmp,
                "cpu 100 20 50 700 30 0 0 0 15 0\n",
                "MemTotal: 8192000 kB\nMemAvailable: 2048000 kB\n",
            )

            state = system_usage.get_status(
                proc, previous_total=800, previous_idle=700, sys_root=tmp
            )

        self.assertEqual(state["cpu"]["percent"], 70)
        self.assertEqual(state["cpu"]["total_ticks"], 900)
        self.assertEqual(state["memory"], {"used_mb": 6000.0, "total_mb": 8000.0, "percent": 75})

    def test_first_cpu_sample_has_no_percentage(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = self._proc(
                tmp,
                "cpu 100 20 50 700 30 0 0 0\n",
                "MemTotal: 4096000 kB\nMemAvailable: 1024000 kB\n",
            )

            state = system_usage.get_status(proc, sys_root=tmp)

        self.assertIsNone(state["cpu"]["percent"])
        self.assertEqual(state["memory"]["percent"], 75)

    def test_missing_proc_files_returns_safe_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = system_usage.get_status(tmp, sys_root=tmp)

        self.assertTrue(state["ok"])
        self.assertIsNone(state["cpu"]["percent"])
        self.assertIsNone(state["cpu"]["frequency_mhz"])
        self.assertEqual(state["memory"]["percent"], 0)

    def test_cpu_frequency_averages_online_cores(self):
        with tempfile.TemporaryDirectory() as tmp:
            sys_root = Path(tmp)
            cpu_root = sys_root / "devices/system/cpu"
            for cpu, frequency, online in ((0, 1800000, None), (1, 2200000, "1"), (2, 4000000, "0")):
                cpufreq = cpu_root / f"cpu{cpu}/cpufreq"
                cpufreq.mkdir(parents=True)
                (cpufreq / "scaling_cur_freq").write_text(str(frequency), encoding="ascii")
                if online is not None:
                    (cpufreq.parent / "online").write_text(online, encoding="ascii")

            frequency = system_usage.cpu_frequency_mhz(sys_root)

        self.assertEqual(frequency, 2000)


if __name__ == "__main__":
    unittest.main()
