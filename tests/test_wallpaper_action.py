import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "wallpaper-action.py"
SPEC = importlib.util.spec_from_file_location("wallpaper_action", SCRIPT)
wallpaper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wallpaper)


class TestWallpaperAction(unittest.TestCase):
    def test_webp_preview_is_cached_as_qt_compatible_jpeg(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            source = base / "wallpaper.webp"
            Image.new("RGB", (1600, 900), "#345678").save(source, format="WEBP")

            with patch.object(wallpaper, "PREVIEW_DIR", base / "cache"):
                preview = wallpaper.create_preview(source)
                cached_preview = wallpaper.create_preview(source)

            self.assertEqual(preview, cached_preview)
            self.assertEqual(preview.suffix, ".jpg")
            with Image.open(preview) as image:
                self.assertEqual(image.format, "JPEG")
                self.assertLessEqual(image.width, 1000)
                self.assertLessEqual(image.height, 600)

    def test_jxl_preview_uses_imagemagick_when_available(self):
        converter = shutil.which("magick")
        if not converter:
            self.skipTest("ImageMagick is not installed")
        formats = subprocess.run(
            [converter, "-list", "format"], capture_output=True, text=True, check=True
        ).stdout
        if not re.search(r"^\s*JXL\*?\s", formats, re.MULTILINE):
            self.skipTest("ImageMagick has no JPEG-XL support")

        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            png = base / "source.png"
            source = base / "wallpaper.jxl"
            Image.new("RGB", (1600, 900), "#345678").save(png)
            subprocess.run([converter, str(png), str(source)], check=True, capture_output=True)

            with patch.object(wallpaper, "PREVIEW_DIR", base / "cache"):
                preview = wallpaper.create_preview(source)

            with Image.open(preview) as image:
                self.assertEqual(image.format, "JPEG")
                self.assertLessEqual(image.width, 1000)
                self.assertLessEqual(image.height, 600)

    def test_apply_preserves_selected_gallery_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            gallery = base / "gallery"
            gallery.mkdir()
            image = base / "elsewhere" / "image.png"
            image.parent.mkdir()
            image.write_bytes(b"image")
            state = base / "state" / "wallpaper.json"
            state.parent.mkdir()
            state.write_text(json.dumps({"folder": str(gallery)}))

            with patch.object(wallpaper, "STATE_DIR", state.parent), \
                 patch.object(wallpaper, "WALLPAPER_STATE", state), \
                 patch.object(wallpaper, "CURRENT_WALLPAPER", base / "current_wallpaper"), \
                 patch.object(wallpaper.shutil, "which", return_value="/usr/bin/awww"), \
                 patch.object(wallpaper.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
                ok, error = wallpaper.apply_wallpaper(image)

            self.assertTrue(ok, error)
            self.assertEqual(json.loads(state.read_text()), {
                "wallpaper": str(image), "folder": str(gallery),
            })
            self.assertEqual((base / "current_wallpaper").read_bytes(), b"image")


if __name__ == "__main__":
    unittest.main()
