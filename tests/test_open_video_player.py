import importlib.util
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "open-video-player.py"
SPEC = importlib.util.spec_from_file_location("open_video_player", SCRIPT)
PLAYER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PLAYER)


class OpenVideoPlayerTests(unittest.TestCase):
    def test_accepts_http_and_https_links(self):
        self.assertTrue(PLAYER.valid_url("https://youtu.be/example"))
        self.assertTrue(PLAYER.valid_url("http://example.test/watch?v=1"))

    def test_rejects_non_web_urls_and_malformed_values(self):
        for value in ("", "file:///tmp/video.mp4", "javascript:alert(1)",
                      "https://example.test/a b", "https://", "x" * 2049):
            with self.subTest(value=value[:30]):
                self.assertFalse(PLAYER.valid_url(value))

    def test_prefers_aurora_mpv_then_falls_back_to_mpv(self):
        found = {"aurora-mpv": "/usr/bin/aurora-mpv", "mpv": "/usr/bin/mpv"}
        self.assertEqual(PLAYER.find_player(found.get), "/usr/bin/aurora-mpv")
        self.assertEqual(PLAYER.find_player(lambda name: found.get("mpv") if name == "mpv" else None),
                         "/usr/bin/mpv")
        self.assertIsNone(PLAYER.find_player(lambda _name: None))


if __name__ == "__main__":
    unittest.main()
