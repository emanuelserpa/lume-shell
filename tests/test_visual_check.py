import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "visual-check.sh"


class VisualCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls"
        self._command("systemctl", '''#!/bin/sh
printf 'systemctl %s\\n' "$*" >> "$VISUAL_TEST_CALLS"
case "$*" in
  *lume-shell.service) unit=lume-shell.service ;;
  *quickshell.service) unit=quickshell.service ;;
  *) exit 1 ;;
esac
case " $VISUAL_ACTIVE_UNITS " in *" $unit "*) exit 0 ;; esac
exit 3
''')
        self._command("fc-list", '''#!/bin/sh
printf '%s\\n' 'Noto Sans' 'JetBrainsMono Nerd Font'
''')
        self._command("hyprctl", '''#!/bin/sh
printf 'hyprctl %s\\n' "$*" >> "$VISUAL_TEST_CALLS"
printf '%s\\n' 'namespace: quickshell' 'xywh: 0 0 1920 37'
''')

    def _command(self, name, content):
        path = self.bin / name
        path.write_text(content, encoding="utf-8")
        path.chmod(0o755)

    def _run(self, active_units, desktop="labwc"):
        env = os.environ.copy()
        env.update({
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "VISUAL_TEST_CALLS": str(self.calls),
            "VISUAL_ACTIVE_UNITS": active_units,
            "XDG_CURRENT_DESKTOP": desktop,
        })
        return subprocess.run([str(SCRIPT)], env=env, text=True, capture_output=True)

    def test_prefers_active_package_unit(self):
        result = self._run("lume-shell.service quickshell.service")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls.read_text(encoding="utf-8")
        self.assertIn("lume-shell.service", calls)
        self.assertNotIn("quickshell.service", calls)

    def test_uses_legacy_unit_only_when_package_unit_is_inactive(self):
        result = self._run("quickshell.service")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Legacy quickshell.service", result.stdout)

    def test_fails_when_no_shell_unit_is_active(self):
        result = self._run("")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No active lume-shell.service", result.stdout)

    def test_skips_hyprland_probe_on_generic_wayland(self):
        result = self._run("lume-shell.service", "labwc")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("hyprctl", self.calls.read_text(encoding="utf-8"))
        self.assertIn("not applicable", result.stdout)

    def test_runs_layer_probe_in_hyprland(self):
        result = self._run("lume-shell.service", "Hyprland")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("hyprctl layers", self.calls.read_text(encoding="utf-8"))
        self.assertIn("layer-shell surface detected", result.stdout)


if __name__ == "__main__":
    unittest.main()
