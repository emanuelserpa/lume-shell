#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
DISPATCH = ROOT / "scripts" / "compositor-dispatch.sh"


class TestMangoDispatch(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.temp_path = Path(self.temp_dir.name)
        self.capture = self.temp_path / "mmsg-args"
        fake_mmsg = self.temp_path / "mmsg"
        fake_mmsg.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$MMSG_CAPTURE"\n')
        fake_mmsg.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            "PATH": f"{self.temp_path}:{self.env.get('PATH', '')}",
            "XDG_CURRENT_DESKTOP": "Mango:Wayland",
            "MANGO_INSTANCE_SIGNATURE": "/tmp/mango-test.sock",
            "MMSG_CAPTURE": str(self.capture),
        })

    def test_switches_the_requested_output_tag(self):
        result = subprocess.run(
            [str(DISPATCH), "workspace", "4", "eDP-1"],
            env=self.env, capture_output=True, text=True, check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.capture.read_text().splitlines(), [
            "dispatch", "viewcrossmon,4,eDP-1",
        ])

    def test_rejects_invalid_tag_and_monitor_without_ipc(self):
        invalid_tag = subprocess.run(
            [str(DISPATCH), "workspace", "10", "eDP-1"],
            env=self.env, capture_output=True, text=True, check=False,
        )
        invalid_monitor = subprocess.run(
            [str(DISPATCH), "workspace", "2", "eDP-1,HDMI-A-1"],
            env=self.env, capture_output=True, text=True, check=False,
        )

        self.assertNotEqual(invalid_tag.returncode, 0)
        self.assertNotEqual(invalid_monitor.returncode, 0)
        self.assertFalse(self.capture.exists())


class TestHyprlandDispatch(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.temp_path = Path(self.temp_dir.name)
        self.capture = self.temp_path / "hyprctl-args"
        self.python_capture = self.temp_path / "python3-args"
        fake_hyprctl = self.temp_path / "hyprctl"
        fake_hyprctl.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$HYPRCTL_CAPTURE"\n')
        fake_hyprctl.chmod(0o755)
        fake_python = self.temp_path / "python3"
        fake_python.write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$PYTHON_CAPTURE"\n')
        fake_python.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            "PATH": f"{self.temp_path}:{self.env.get('PATH', '')}",
            "XDG_CURRENT_DESKTOP": "Hyprland:Wayland",
            "HYPRCTL_CAPTURE": str(self.capture),
            "PYTHON_CAPTURE": str(self.python_capture),
        })

    def test_reads_modal_submap_through_dispatcher(self):
        result = subprocess.run(
            [str(DISPATCH), "submap"],
            env=self.env, capture_output=True, text=True, check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.capture.read_text().splitlines(), ["submap"])

    def test_routes_display_projection_to_the_hyprland_helper(self):
        result = subprocess.run(
            [str(DISPATCH), "display-projection", "duplicate"],
            env=self.env, capture_output=True, text=True, check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.python_capture.read_text().splitlines(), [
            "-B",
            str(ROOT / "scripts" / "display-projection.py"),
            "apply",
            "duplicate",
        ])

    def test_rejects_unknown_display_projection_modes(self):
        result = subprocess.run(
            [str(DISPATCH), "display-projection", "disable-everything"],
            env=self.env, capture_output=True, text=True, check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid display projection mode", result.stderr)
        self.assertFalse(self.python_capture.exists())


if __name__ == "__main__":
    unittest.main()
