import json
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HELPER = REPO_ROOT / "scripts" / "launcher-data.py"


class EmojiRankingTests(unittest.TestCase):
    def test_empty_picker_shows_emoji_instead_of_catalog_punctuation(self):
        with tempfile.TemporaryDirectory() as state_home:
            env = os.environ.copy()
            env["XDG_STATE_HOME"] = state_home
            result = subprocess.run(
                [sys.executable, str(HELPER), "emoji", ""],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            items = json.loads(result.stdout)["items"]

            self.assertEqual(len(items), 40)
            chars = {item["char"] for item in items}
            self.assertIn("❤️", chars)
            self.assertTrue(chars.isdisjoint({"[", "]", "(", ")", ".", ","}))

    def test_search_does_not_return_punctuation_catalog_entries(self):
        with tempfile.TemporaryDirectory() as state_home:
            env = os.environ.copy()
            env["XDG_STATE_HOME"] = state_home
            result = subprocess.run(
                [sys.executable, str(HELPER), "emoji", "abertura"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            chars = {item["char"] for item in json.loads(result.stdout)["items"]}
            self.assertIn("🪟", chars)
            self.assertNotIn("[", chars)

    def test_repeated_use_moves_emoji_to_top_of_popular_results(self):
        with tempfile.TemporaryDirectory() as state_home:
            env = os.environ.copy()
            env["XDG_STATE_HOME"] = state_home

            least_popular = "🪟"

            def run(*args):
                result = subprocess.run(
                    [sys.executable, str(HELPER), *args],
                    check=True,
                    capture_output=True,
                    text=True,
                    env=env,
                )
                return json.loads(result.stdout)

            for _ in range(2):
                run("emoji-mark", least_popular)

            ranked = run("emoji", "")
            self.assertEqual(ranked["items"][0]["char"], least_popular)

    def test_popular_punctuation_is_filtered_before_ranking(self):
        spec = importlib.util.spec_from_file_location("launcher_data", HELPER)
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        with tempfile.TemporaryDirectory() as directory:
            catalog = Path(directory) / "emojis.json"
            catalog.write_text(json.dumps([
                {"char": "[", "name": "Abertura", "keywords": ["abertura"], "pop": 9999},
                {"char": "🪟", "name": "Janela", "keywords": ["abertura"], "pop": 0},
            ]), encoding="utf-8")
            with patch.object(helper, "EMOJI_DB_FILE", catalog), patch.object(helper, "load_emoji_usage", return_value={}):
                for query in ("", "abertura"):
                    with self.subTest(query=query), redirect_stdout(io.StringIO()) as output:
                        helper.emoji(query)
                        self.assertEqual([item["char"] for item in json.loads(output.getvalue())["items"]], ["🪟"])


if __name__ == "__main__":
    unittest.main()
