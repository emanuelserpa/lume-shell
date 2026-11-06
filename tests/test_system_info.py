#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "system-info.py"
SPEC = importlib.util.spec_from_file_location("system_info", SCRIPT)
system_info = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(system_info)


class TestSystemInfo(unittest.TestCase):
    def test_fastfetch_modules_map_to_stable_shell_contract(self):
        modules = [
            {"type": "OS", "result": {"prettyName": "Example Linux", "id": "example"}},
            {"type": "Host", "result": {"family": "Example Laptop"}},
            {"type": "Kernel", "result": {"release": "6.12.1", "architecture": "x86_64"}},
            {"type": "Uptime", "result": {"uptime": 12345}},
            {"type": "Packages", "result": {"all": 100, "pacman": 80, "flatpakUser": 15, "brew": 5}},
            {"type": "Shell", "result": {"prettyName": "zsh", "version": "5.9"}},
            {"type": "WM", "result": {"prettyName": "Hyprland", "version": "0.5", "protocolName": "Wayland"}},
            {"type": "Terminal", "result": {"prettyName": "kitty", "version": "0.49"}},
            {"type": "CPU", "result": {"cpu": "Example CPU", "cores": {"physical": 8, "logical": 16}}},
            {"type": "GPU", "result": [{"vendor": "Example", "name": "Graphics", "type": "Integrated", "driver": "example"}]},
            {"type": "Memory", "result": {"used": 4_000_000_000, "total": 8_000_000_000}},
            {"type": "Disk", "result": [{"bytes": {"used": 20, "total": 100}, "mountpoint": "/"}]},
            {"type": "Battery", "result": [{"capacity": 75.9, "status": ["Charging"]}]},
            {"type": "Display", "result": [{"name": "eDP-1", "output": {"width": 1920, "height": 1080}}]},
            {"type": "Separator", "error": "Unsupported for JSON format"},
        ]

        data = system_info.parse_fastfetch(modules)

        self.assertEqual(data["os"], "Example Linux")
        self.assertEqual(data["host"], "Example Laptop")
        self.assertEqual(data["desktop"], "Hyprland 0.5")
        self.assertEqual(data["protocol"], "Wayland")
        self.assertEqual(data["cpuCores"], 8)
        self.assertEqual(data["gpu"][0]["name"], "Example Graphics")
        self.assertEqual(data["memory"], {"used": 4_000_000_000, "total": 8_000_000_000})
        self.assertEqual(data["battery"], {"capacity": 75, "status": "Charging"})
        self.assertEqual(data["display"], {"name": "eDP-1", "width": 1920, "height": 1080})
        self.assertEqual(data["packages"]["flatpak"], 15)

    def test_missing_fastfetch_is_a_json_error(self):
        with patch.object(system_info.shutil, "which", return_value=None):
            status = system_info.get_status()

        self.assertFalse(status["ok"])
        self.assertEqual(status["version"], system_info.VERSION)
        self.assertEqual(status["data"], {})
        self.assertEqual(status["error"], "Fastfetch não encontrado")

    def test_missing_os_module_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "sistema operacional"):
            system_info.parse_fastfetch([{"type": "Kernel", "result": {"release": "6.12"}}])


if __name__ == "__main__":
    unittest.main()
