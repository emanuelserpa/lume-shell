import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "bar-settings.py"
SPEC = importlib.util.spec_from_file_location("bar_settings", SCRIPT_PATH)
bar_settings = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bar_settings)


class TestBarSettings(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.directory = Path(self.tempdir.name)
        self.file = self.directory / "bar.json"
        self.dir_patch = patch.object(bar_settings, "CONFIG_DIR", self.directory)
        self.file_patch = patch.object(bar_settings, "CONFIG_FILE", self.file)
        self.dir_patch.start()
        self.file_patch.start()

    def tearDown(self):
        self.file_patch.stop()
        self.dir_patch.stop()
        self.tempdir.cleanup()

    def test_default_islands_and_invalid_values_fall_back(self):
        self.assertEqual(bar_settings.read_mode(), "islands")
        self.file.write_text('{"version": 1, "surface": "unknown"}', encoding="utf-8")
        self.assertEqual(bar_settings.read_mode(), "islands")

    def test_continuous_mode_round_trips(self):
        bar_settings.write_mode("continuous")
        self.assertEqual(bar_settings.read_mode(), "continuous")
        self.assertEqual(__import__("json").loads(self.file.read_text()),
                         {"version": 1, "surface": "continuous"})

    def test_rejects_unknown_mode(self):
        with self.assertRaises(ValueError):
            bar_settings.write_mode("free-layout")


if __name__ == "__main__":
    unittest.main()
