import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "system-update.sh"


class TestSystemUpdate(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.calls = self.root / "calls.log"
        self._command("yay", 'printf "yay %s\\n" "$*" >> "$UPDATE_TEST_CALLS"\n')
        self._command("pkexec", 'printf "pkexec %s\\n" "$*" >> "$UPDATE_TEST_CALLS"\n')
        self._command("brew", 'printf "brew %s\\n" "$*" >> "$UPDATE_TEST_CALLS"\n')
        self._command(
            "flatpak",
            'printf "flatpak %s\\n" "$*" >> "$UPDATE_TEST_CALLS"\n'
            '[ "$1" != "info" ]\n',
        )
        self.env = {
            **os.environ,
            "PATH": f"{self.bin_dir}:/usr/bin:/bin",
            "UPDATE_TEST_CALLS": str(self.calls),
            "XDG_CACHE_HOME": str(self.root / "cache"),
        }

    def tearDown(self):
        self.temp_dir.cleanup()

    def _command(self, name, body):
        path = self.bin_dir / name
        path.write_text(f"#!/bin/sh\n{body}", encoding="utf-8")
        path.chmod(0o755)

    def _run(self, mode):
        return subprocess.run(
            ["bash", str(SCRIPT), mode],
            check=True,
            capture_output=True,
            text=True,
            env=self.env,
        )

    def test_all_runs_one_combined_yay_update_without_a_separate_repo_call(self):
        result = self._run("all")
        calls = self.calls.read_text(encoding="utf-8")

        self.assertIn("yay -Syu --noconfirm", calls)
        self.assertEqual(sum(line.startswith("yay ") for line in calls.splitlines()), 1)
        self.assertFalse(any(line.startswith("pkexec ") for line in calls.splitlines()))
        self.assertIn('"step":1,"total":4,"text":"Repositórios e AUR"', result.stdout)
        self.assertIn('"type":"done","ok":true', result.stdout)

    def test_repository_only_backend_still_uses_polkit(self):
        self._run("repo")
        calls = self.calls.read_text(encoding="utf-8")

        self.assertIn("pkexec /usr/bin/pacman -Syu --noconfirm", calls)
        self.assertNotIn("yay ", calls)


if __name__ == "__main__":
    unittest.main()
