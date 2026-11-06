#!/usr/bin/env python3
"""Regression tests for scripts/ytdlp-download.py (no network, no desktop)."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.dont_write_bytecode = True

from tests.helpers import import_script

app = import_script("ytdlp_download", "ytdlp-download.py")


class UrlTests(unittest.TestCase):
    def test_valid_links(self):
        for url in ("https://www.youtube.com/watch?v=abc123_-",
                    "http://youtu.be/abc",
                    "https://example.com:8080/a?b=c#d"):
            with self.subTest(url=url):
                self.assertIsNone(app.validate_url(url))

    def test_invalid_links(self):
        for url in ("", "not a url", "ftp://x/y", "javascript:alert(1)",
                    "https://", "x" * 3000):
            with self.subTest(url=url):
                self.assertIsNotNone(app.validate_url(url))


class InfoTests(unittest.TestCase):
    FIXTURE = {
        "id": "abc123", "title": "Some Video", "duration": 125,
        "ext": "mp4", "is_live": False,
        "thumbnails": [{"url": "http://t/small"}, {"url": "http://t/big"}],
        "formats": [
            {"height": 720, "vcodec": "avc1"},
            {"height": 1080, "vcodec": "avc1"},
            {"height": None, "vcodec": "mp4a"},
            {"height": 720, "vcodec": "none"},
        ],
    }

    def test_info_parses_fixture(self):
        proc = subprocess.CompletedProcess([], 0, json.dumps(self.FIXTURE), "")
        with patch.object(app.subprocess, "run", return_value=proc):
            result = app.cmd_info("https://example.com/v")
        self.assertTrue(result["ok"])
        data = result["data"]
        self.assertEqual(data["title"], "Some Video")
        self.assertEqual(data["duration_str"], "2:05")
        self.assertEqual(data["thumbnail"], "http://t/big")
        self.assertEqual(data["heights"], [1080, 720])

    def test_info_rejects_unknown_link(self):
        proc = subprocess.CompletedProcess([], 1, "", "ERROR: Unsupported URL")
        with patch.object(app.subprocess, "run", return_value=proc):
            result = app.cmd_info("https://example.com/v")
        self.assertFalse(result["ok"])
        self.assertIn("Unsupported URL", result["error"])

    def test_info_contract_shape(self):
        proc = subprocess.CompletedProcess([], 0, json.dumps(self.FIXTURE), "")
        with patch.object(app.subprocess, "run", return_value=proc):
            result = app.cmd_info("https://example.com/v")
        self.assertEqual(set(result), {"ok", "version", "data", "error"})
        self.assertEqual(result["version"], 1)


class StartTests(unittest.TestCase):
    def test_start_builds_argv_without_shell(self):
        seen = {}

        class FakeProc:
            pid = 4242

        def fake_popen(argv, **kwargs):
            seen["argv"] = argv
            seen["kwargs"] = kwargs
            return FakeProc()

        with tempfile.TemporaryDirectory() as state, \
                tempfile.TemporaryDirectory() as dest, \
                patch.dict(os.environ, {"XDG_STATE_HOME": state}), \
                patch.object(app.subprocess, "Popen", side_effect=fake_popen):
            result = app.cmd_start("https://example.com/v?id=1&x=2",
                                   mode="video", quality="720p",
                                   fmt="mp4", dest=dest)
            self.assertTrue(result["ok"], result)
            argv = seen["argv"]
            self.assertEqual(argv[0], "yt-dlp")
            self.assertIn("https://example.com/v?id=1&x=2", argv)
            # URL travels as one argv item; nothing executed through a shell.
            self.assertEqual(argv.count("https://example.com/v?id=1&x=2"), 1)
            self.assertTrue(seen["kwargs"].get("start_new_session"))
            job_file = Path(state, "quickshell", "ytdlp", "jobs",
                            result["data"]["job_id"], "job.json")
            self.assertTrue(job_file.exists())

    def test_start_rejects_bad_inputs(self):
        self.assertFalse(app.cmd_start("notaurl")["ok"])
        self.assertFalse(app.cmd_start("https://example.com/v", mode="x")["ok"])
        self.assertFalse(app.cmd_start("https://example.com/v",
                                       quality="8k")["ok"])
        self.assertFalse(app.cmd_start("https://example.com/v", dest="rel")["ok"])


class StatusTests(unittest.TestCase):
    def _job(self, directory, pid=999999):
        job_dir = Path(directory, "quickshell", "ytdlp", "jobs", "job1")
        job_dir.mkdir(parents=True)
        job = {"job_id": "job1", "url": "https://example.com/v",
               "mode": "video", "dest": directory, "pid": pid,
               "created_at": 1.0}
        (job_dir / "job.json").write_text(json.dumps(job))
        return job_dir

    def test_done_when_final_file_exists(self):
        with tempfile.TemporaryDirectory() as state:
            job_dir = self._job(state)
            target = Path(state, "out.mp4")
            target.write_text("x")
            (job_dir / "download.log").write_text(
                f"YTDLP_FILE:{target}\n")
            with patch.dict(os.environ, {"XDG_STATE_HOME": state}):
                result = app.cmd_status("job1")
        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["status"], "done")
        self.assertEqual(result["data"]["file"], str(target))

    def test_progress_parsing(self):
        with tempfile.TemporaryDirectory() as state:
            job_dir = self._job(state, pid=os.getpid())
            (job_dir / "download.log").write_text(
                "YTDLP_PROGRESS  12.3%|00:41|1.2MiB/s\n")
            with patch.dict(os.environ, {"XDG_STATE_HOME": state}):
                result = app.cmd_status("job1")
        self.assertEqual(result["data"]["status"], "running")
        self.assertEqual(result["data"]["percent"], "12.3%")

    def test_unknown_job(self):
        with tempfile.TemporaryDirectory() as state:
            with patch.dict(os.environ, {"XDG_STATE_HOME": state}):
                self.assertFalse(app.cmd_status("nope")["ok"])

    def test_cancel_marks_job(self):
        with tempfile.TemporaryDirectory() as state:
            self._job(state)
            with patch.dict(os.environ, {"XDG_STATE_HOME": state}):
                result = app.cmd_cancel("job1")
                status = app.cmd_status("job1")
        self.assertTrue(result["ok"])
        self.assertEqual(status["data"]["status"], "cancelled")


class PrefsTests(unittest.TestCase):
    def test_prefs_roundtrip(self):
        with tempfile.TemporaryDirectory() as state:
            with patch.dict(os.environ, {"XDG_STATE_HOME": state}):
                out = app.cmd_prefs(["quality=480p", "format=mkv",
                                     "dest=/tmp/dl", "bogus=1"])
        self.assertTrue(out["ok"])
        self.assertEqual(out["data"]["prefs"]["quality"], "480p")
        self.assertEqual(out["data"]["prefs"]["format"], "mkv")
        self.assertNotIn("bogus", out["data"]["prefs"])


if __name__ == "__main__":
    unittest.main()
