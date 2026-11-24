from contextlib import closing
import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tests.helpers import import_script

lume_paths = import_script("lume_paths", "lume_paths.py")
tm = import_script("theme_manager_paths", "theme-manager.py")


class LumePathsTests(unittest.TestCase):
    def test_canonical_xdg_directories_use_lume_shell(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            env = {
                "HOME": str(root / "home"),
                "XDG_CONFIG_HOME": str(root / "cfg"),
                "XDG_STATE_HOME": str(root / "st"),
                "XDG_DATA_HOME": str(root / "dt"),
                "XDG_CACHE_HOME": str(root / "ca"),
                "XDG_RUNTIME_DIR": str(root / "run"),
            }
            self.assertEqual(lume_paths.config_dir(env), root / "cfg" / "lume-shell")
            self.assertEqual(lume_paths.state_dir(env), root / "st" / "lume-shell")
            self.assertEqual(lume_paths.data_dir(env), root / "dt" / "lume-shell")
            self.assertEqual(lume_paths.cache_dir(env), root / "ca" / "lume-shell")
            self.assertEqual(
                lume_paths.private_runtime_dir(env),
                root / "run" / f"lume-shell-{os.getuid()}",
            )

    def test_legacy_siblings_ignores_non_lume_paths(self):
        self.assertEqual(lume_paths.legacy_siblings(Path("/tmp/custom/state/theme.json")), [])
        siblings = lume_paths.legacy_siblings(Path("/tmp/st/lume-shell/theme.json"))
        self.assertEqual(
            siblings,
            [
                Path("/tmp/st/quickshell/theme.json"),
                Path("/tmp/st/lumeshell/theme.json"),
            ],
        )

    def test_migrate_file_moves_legacy_without_clobbering_and_links_compat(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            legacy_palette = root / "st" / "quickshell" / "current_palette.json"
            new_palette = root / "st" / "lume-shell" / "current_palette.json"
            legacy_palette.parent.mkdir(parents=True)
            legacy_palette.write_text('{"id":"dracula"}\n', encoding="utf-8")

            lume_paths.migrate_file(new_palette, compat_symlink=True)

            self.assertTrue(new_palette.is_file())
            self.assertEqual(json.loads(new_palette.read_text(encoding="utf-8")), {"id": "dracula"})
            self.assertTrue(legacy_palette.is_symlink())
            self.assertEqual(legacy_palette.resolve(), new_palette.resolve())

            # Existing target files are never overwritten by a later legacy file.
            other_legacy = root / "st" / "lumeshell" / "current_palette.json"
            other_legacy.parent.mkdir(parents=True)
            other_legacy.write_text('{"id":"stale"}\n', encoding="utf-8")
            lume_paths.migrate_file(new_palette, compat_symlink=True)
            self.assertEqual(json.loads(new_palette.read_text(encoding="utf-8")), {"id": "dracula"})

    def test_migrate_all_moves_lume_state_preserves_quickshell_internals_and_rewrites_db(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            env = {
                "HOME": str(root / "home"),
                "XDG_CONFIG_HOME": str(root / "cfg"),
                "XDG_STATE_HOME": str(root / "st"),
                "XDG_DATA_HOME": str(root / "dt"),
                "XDG_CACHE_HOME": str(root / "ca"),
            }

            (root / "cfg" / "quickshell").mkdir(parents=True)
            (root / "cfg" / "quickshell" / "bar.json").write_text('{"surface":"continuous"}', encoding="utf-8")
            (root / "cfg" / "lumeshell" / "power").mkdir(parents=True)
            (root / "cfg" / "lumeshell" / "power" / "cpu-boost.json").write_text(
                '{"version":1,"enabled":true}', encoding="utf-8"
            )

            (root / "st" / "quickshell" / "by-shell").mkdir(parents=True)
            (root / "st" / "quickshell" / "by-shell" / "keep").write_text("runtime", encoding="utf-8")
            (root / "st" / "quickshell" / "current_palette.json").write_text('{"id":"nord"}', encoding="utf-8")
            (root / "st" / "quickshell" / "weather.json").write_text('{"selected":"auto"}', encoding="utf-8")
            (root / "st" / "quickshell" / "ytdlp" / "jobs" / "j1").mkdir(parents=True)
            (root / "st" / "quickshell" / "ytdlp" / "jobs" / "j1" / "job.json").write_text("{}", encoding="utf-8")

            notif_dir = root / "dt" / "quickshell" / "notifications"
            (notif_dir / "images").mkdir(parents=True)
            (notif_dir / "images" / "notification-1-1.png").write_bytes(b"png")
            old_img = str(notif_dir / "images" / "notification-1-1.png")
            with closing(sqlite3.connect(notif_dir / "notifications.db")) as conn:
                conn.execute("CREATE TABLE notifications (id INTEGER PRIMARY KEY, image TEXT)")
                conn.execute("INSERT INTO notifications (image) VALUES (?)", (old_img,))
                conn.commit()
            (root / "dt" / "quickshell" / "by-shell").mkdir(parents=True)
            (root / "dt" / "quickshell" / "by-shell" / "keep").write_text("runtime", encoding="utf-8")

            (root / "ca" / "quickshell" / "qmlcache").mkdir(parents=True)
            (root / "ca" / "quickshell" / "qmlcache" / "keep").write_text("runtime", encoding="utf-8")
            (root / "ca" / "quickshell" / "update.log").write_text("ok\n", encoding="utf-8")

            first = lume_paths.migrate_all(env)
            second = lume_paths.migrate_all(env)

            self.assertTrue(first["migrated"])
            self.assertEqual(second["migrated"], [])

            self.assertTrue((root / "cfg" / "lume-shell" / "bar.json").is_file())
            self.assertTrue((root / "cfg" / "lume-shell" / "power" / "cpu-boost.json").is_file())
            self.assertFalse((root / "cfg" / "lumeshell").exists())

            new_palette = root / "st" / "lume-shell" / "current_palette.json"
            self.assertTrue(new_palette.is_file())
            self.assertTrue((root / "st" / "quickshell" / "current_palette.json").is_symlink())
            self.assertTrue((root / "st" / "lume-shell" / "weather.json").is_file())
            self.assertTrue((root / "st" / "lume-shell" / "ytdlp" / "jobs" / "j1" / "job.json").is_file())

            new_db = root / "dt" / "lume-shell" / "notifications" / "notifications.db"
            self.assertTrue(new_db.is_file())
            with closing(sqlite3.connect(new_db)) as conn:
                stored_img = conn.execute("SELECT image FROM notifications").fetchone()[0]
            self.assertEqual(
                stored_img,
                str((root / "dt" / "lume-shell" / "notifications" / "images" / "notification-1-1.png").resolve()),
            )

            self.assertTrue((root / "ca" / "lume-shell" / "update.log").is_file())
            self.assertEqual((root / "st" / "quickshell" / "by-shell" / "keep").read_text(encoding="utf-8"), "runtime")
            self.assertEqual((root / "dt" / "quickshell" / "by-shell" / "keep").read_text(encoding="utf-8"), "runtime")
            self.assertEqual((root / "ca" / "quickshell" / "qmlcache" / "keep").read_text(encoding="utf-8"), "runtime")

    def test_theme_manager_canonical_palette_symlink_and_kitty_legacy_block_upgrade(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            state = root / "st" / "lume-shell"
            palette_file = state / "current_palette.json"
            theme_file = state / "kitty-theme.conf"
            kitty_conf = root / "kitty.conf"
            kitty_conf.write_text(
                "font_size 11\n\n"
                "# BEGIN Quickshell theme integration\n"
                "allow_remote_control socket-only\n"
                "listen_on unix:${XDG_RUNTIME_DIR}/quickshell-kitty-{kitty_pid}\n"
                "include ${HOME}/.local/state/quickshell/kitty-theme.conf\n"
                "# END Quickshell theme integration\n",
                encoding="utf-8",
            )

            upgraded = tm._kitty_managed_config(kitty_conf, theme_file)
            self.assertNotIn("BEGIN Quickshell theme integration", upgraded)
            self.assertEqual(upgraded.count("# BEGIN Lume Shell theme integration"), 1)
            self.assertIn("lume-shell-kitty-{kitty_pid}", upgraded)

            with patch.object(tm, "STATE_DIR", state), \
                 patch.object(tm, "CANONICAL_PALETTE_FILE", palette_file), \
                 patch.object(tm, "detect_current_wallpaper", return_value=""):
                out = tm.export_canonical_palette(tm.THEMES["catppuccin-mocha"])

            self.assertEqual(out, palette_file)
            self.assertTrue(palette_file.is_file())
            compat = root / "st" / "quickshell" / "current_palette.json"
            self.assertTrue(compat.is_symlink())
            self.assertEqual(compat.resolve(), palette_file.resolve())


if __name__ == "__main__":
    unittest.main()
