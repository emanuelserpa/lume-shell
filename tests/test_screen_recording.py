import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "screen_recording", Path(__file__).resolve().parents[1] / "scripts" / "screen-recording.py"
)
recording = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(recording)


class ScreenRecordingTests(unittest.TestCase):
    def setUp(self):
        self.runtime = tempfile.TemporaryDirectory()
        self.addCleanup(self.runtime.cleanup)
        runtime_dir_patch = patch.object(
            recording, "runtime_dir", return_value=Path(self.runtime.name)
        )
        runtime_dir_patch.start()
        self.addCleanup(runtime_dir_patch.stop)

    def test_window_choices_include_only_visible_windows(self):
        monitors = [{"activeWorkspace": {"id": 2}}]
        clients = [
            {"workspace": {"id": 2}, "at": [10, 20], "size": [800, 600]},
            {"workspace": {"id": 1}, "at": [0, 0], "size": [400, 300]},
            {"workspace": {"id": 2}, "at": [0, 0], "size": [400, 300], "hidden": True},
            {"workspace": {"id": 2}, "at": [0, 0], "size": [400, 300], "visible": False},
        ]
        self.assertEqual(recording.visible_window_boxes(clients, monitors), ["10,20 800x600"])

    def test_full_screen_uses_focused_monitor(self):
        monitors = [{"name": "HDMI-A-1", "focused": False}, {"name": "eDP-1", "focused": True}]
        with patch.object(recording, "is_hyprland", return_value=True), \
                patch.object(recording, "hypr_json", return_value=monitors):
            self.assertEqual(recording.choose_geometry("screen"), ["-o", "eDP-1"])

    def test_labwc_screen_selects_output_without_hyprctl(self):
        result = subprocess.CompletedProcess(["slurp", "-o"], 0, "0,0 1920x1080\n", "")
        with patch.object(recording, "is_hyprland", return_value=False), \
                patch.object(recording.shutil, "which", return_value="/usr/bin/slurp"), \
                patch.object(recording.subprocess, "run", return_value=result) as run:
            self.assertEqual(recording.choose_geometry("screen"), ["-g", "0,0 1920x1080"])
        self.assertEqual(run.call_args.args[0], ["slurp", "-o"])

    def test_labwc_window_selects_area_without_hyprctl(self):
        result = subprocess.CompletedProcess(["slurp"], 0, "10,20 800x600\n", "")
        with patch.object(recording, "is_hyprland", return_value=False), \
                patch.object(recording.shutil, "which", return_value="/usr/bin/slurp"), \
                patch.object(recording.subprocess, "run", return_value=result) as run:
            self.assertEqual(recording.choose_geometry("window"), ["-g", "10,20 800x600"])
        self.assertEqual(run.call_args.args[0], ["slurp"])

    def test_region_selection_closes_stdin_before_opening_slurp(self):
        result = subprocess.CompletedProcess(["slurp"], 0, "10,20 800x600\n", "")
        with patch.object(recording.shutil, "which", return_value="/usr/bin/slurp"), \
                patch.object(recording.subprocess, "run", return_value=result) as run:
            self.assertEqual(recording.choose_geometry("selection"), ["-g", "10,20 800x600"])
        self.assertEqual(run.call_args.kwargs["stdin"], subprocess.DEVNULL)

    def test_start_with_microphone_uses_explicit_source(self):
        with patch.object(recording.shutil, "which", return_value="/usr/bin/wf-recorder"), \
             patch.object(recording, "video_directory", return_value=Path("/tmp")), \
             patch.object(recording, "status", return_value={"ok": True, "active": False}), \
             patch.object(recording, "default_audio_source", return_value="mic.monitor"), \
             patch.object(recording, "write_state") as mock_write, \
             patch.object(recording.time, "sleep"), \
             patch.object(recording.subprocess, "Popen") as mock_popen:
            mock_proc = mock_popen.return_value
            mock_proc.poll.return_value = None
            mock_proc.pid = 9999
            recording.start("screen", ["-o", "eDP-1"], audio_mode="microphone")
            cmd = mock_popen.call_args[0][0]
            self.assertIn("--audio=mic.monitor", cmd)
            self.assertEqual(cmd[0], "wf-recorder")
            self.assertEqual(cmd[1], "--audio=mic.monitor")
            self.assertTrue(mock_write.call_args[0][0]["audio"])
            self.assertEqual(mock_write.call_args[0][0]["audio_mode"], "microphone")

    def test_start_with_system_audio_uses_default_sink_monitor(self):
        with patch.object(recording.shutil, "which", return_value="/usr/bin/wf-recorder"), \
             patch.object(recording, "video_directory", return_value=Path("/tmp")), \
             patch.object(recording, "status", return_value={"ok": True, "active": False}), \
             patch.object(recording, "default_system_monitor", return_value="speaker.monitor"), \
             patch.object(recording, "write_state") as mock_write, \
             patch.object(recording.time, "sleep"), \
             patch.object(recording.subprocess, "Popen") as mock_popen:
            mock_proc = mock_popen.return_value
            mock_proc.poll.return_value = None
            mock_proc.pid = 9999
            recording.start("screen", ["-o", "eDP-1"], audio_mode="system")
            self.assertIn("--audio=speaker.monitor", mock_popen.call_args[0][0])
            self.assertEqual(mock_write.call_args[0][0]["audio_mode"], "system")

    def test_start_with_both_uses_temporary_mix_and_tracks_modules(self):
        with patch.object(recording.shutil, "which", return_value="/usr/bin/wf-recorder"), \
             patch.object(recording, "video_directory", return_value=Path("/tmp")), \
             patch.object(recording, "status", return_value={"ok": True, "active": False}), \
             patch.object(recording, "create_audio_mix", return_value=("mix.monitor", ["17", "18", "19"])), \
             patch.object(recording, "write_state") as mock_write, \
             patch.object(recording.time, "sleep"), \
             patch.object(recording.subprocess, "Popen") as mock_popen:
            mock_proc = mock_popen.return_value
            mock_proc.poll.return_value = None
            mock_proc.pid = 9999
            recording.start("screen", ["-o", "eDP-1"], audio_mode="both")
            self.assertIn("--audio=mix.monitor", mock_popen.call_args[0][0])
            self.assertEqual(mock_write.call_args[0][0]["audio_modules"], ["17", "18", "19"])

    def test_start_without_audio_omits_flag(self):
        with patch.object(recording.shutil, "which", return_value="/usr/bin/wf-recorder"), \
             patch.object(recording, "video_directory", return_value=Path("/tmp")), \
             patch.object(recording, "status", return_value={"ok": True, "active": False}), \
             patch.object(recording, "write_state") as mock_write, \
             patch.object(recording.time, "sleep"), \
             patch.object(recording.subprocess, "Popen") as mock_popen:
            mock_proc = mock_popen.return_value
            mock_proc.poll.return_value = None
            mock_proc.pid = 9999
            recording.start("screen", ["-o", "eDP-1"], audio_mode="none")
            cmd = mock_popen.call_args[0][0]
            self.assertNotIn("-a", cmd)
            self.assertFalse(mock_write.call_args[0][0]["audio"])



if __name__ == "__main__":
    unittest.main()
