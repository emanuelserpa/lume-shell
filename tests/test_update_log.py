import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "update-log.py"
SPEC = importlib.util.spec_from_file_location("update_log", SCRIPT)
update_log = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(update_log)


class UpdateLogTests(unittest.TestCase):
    def test_prepare_uses_cache_and_clears_old_result(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"XDG_CACHE_HOME": tmp}
            path = update_log.prepare_log(env, Path(tmp) / "fallback.log")
            path.write_text("old run", encoding="utf-8")
            status = path.with_suffix(".status.json")
            status.write_text('{"succeeded":true,"text":"old"}', encoding="utf-8")

            prepared = update_log.prepare_log(env, Path(tmp) / "fallback.log")

            self.assertEqual(prepared, path)
            self.assertEqual(path.read_text(encoding="utf-8"), "")
            self.assertFalse(status.exists())

    def test_prepare_falls_back_if_cache_parent_is_not_a_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            cache_file = root / "cache"
            cache_file.write_text("block", encoding="utf-8")
            fallback = root / "fallback" / "update.log"

            self.assertEqual(update_log.prepare_log({"XDG_CACHE_HOME": str(cache_file)}, fallback), fallback)
            self.assertTrue(fallback.is_file())

    def test_status_round_trip_and_no_previous_result(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"XDG_CACHE_HOME": tmp}
            fallback = Path(tmp) / "fallback.log"
            self.assertFalse(update_log.read_status(env, fallback)["data"]["has_status"])
            log = update_log.prepare_log(env, fallback)
            update_log.record_status(False, "Concluída com erro: rede", env, fallback)

            result = update_log.read_status(env, fallback)

            self.assertTrue(result["data"]["has_status"])
            self.assertFalse(result["data"]["succeeded"])
            self.assertEqual(result["data"]["text"], "Concluída com erro: rede")
            self.assertEqual(json.loads(log.with_suffix(".status.json").read_text()),
                             {"succeeded": False, "text": "Concluída com erro: rede"})

    def test_open_log_reports_missing_kitty_and_missing_file(self):
        with mock.patch.object(update_log.shutil, "which", return_value=None):
            result = update_log.open_log({}, Path("/tmp/not-a-real-update-log"))
        self.assertFalse(result["ok"])
        self.assertIn("Kitty", result["error"])

        with tempfile.TemporaryDirectory() as tmp:
            result = update_log.open_log({"XDG_CACHE_HOME": tmp}, Path(tmp) / "missing", kitty="/usr/bin/kitty")
        self.assertFalse(result["ok"])
        self.assertIn("log de atualização", result["error"])

    def test_open_log_passes_path_as_an_argument(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = {"XDG_CACHE_HOME": tmp}
            fallback = Path(tmp) / "fallback.log"
            log = update_log.prepare_log(env, fallback)
            log.write_text("update output", encoding="utf-8")
            with mock.patch.object(update_log.subprocess, "Popen") as popen:
                result = update_log.open_log(env, fallback, kitty="/usr/bin/kitty")
            self.assertTrue(result["ok"])
            command = popen.call_args.args[0]
            self.assertEqual(command[-1], str(log))
            self.assertIn("--", command)


if __name__ == "__main__":
    unittest.main()
