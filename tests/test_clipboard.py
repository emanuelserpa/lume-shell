#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
import sqlite3
import sys
sys.dont_write_bytecode = True
import tempfile
import unittest
from contextlib import closing
from unittest.mock import patch
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from pathlib import Path

# Add scripts directory
SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import clipboard_store

class ClipboardBackendTestCase(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp(prefix="qs_clip_test_"))
        self.orig_base = clipboard_store.BASE_DIR
        self.orig_db = clipboard_store.DB_PATH
        self.orig_blobs = clipboard_store.BLOBS_DIR
        self.orig_cache = clipboard_store.CACHE_INDEX_FILE
        self.orig_change = clipboard_store.CHANGE_FILE
        self.orig_thumbs = clipboard_store.THUMBS_DIR

        clipboard_store.BASE_DIR = self.test_dir / "clipboard"
        clipboard_store.DB_PATH = clipboard_store.BASE_DIR / "clipboard.db"
        clipboard_store.BLOBS_DIR = clipboard_store.BASE_DIR / "blobs"
        clipboard_store.CACHE_INDEX_FILE = self.test_dir / "clipboard-index.json"
        clipboard_store.CHANGE_FILE = self.test_dir / "clipboard-change"
        clipboard_store.THUMBS_DIR = self.test_dir / "thumbs"
        clipboard_store.init_db()

    def tearDown(self):
        clipboard_store.BASE_DIR = self.orig_base
        clipboard_store.DB_PATH = self.orig_db
        clipboard_store.BLOBS_DIR = self.orig_blobs
        clipboard_store.CACHE_INDEX_FILE = self.orig_cache
        clipboard_store.CHANGE_FILE = self.orig_change
        clipboard_store.THUMBS_DIR = self.orig_thumbs
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_case_a_simple_text(self):
        text = "Hello World"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        item_id, created = clipboard_store.record_item(
            item_type="text",
            primary_mime="text/plain",
            mime_types_list=["text/plain"],
            text_preview="Hello World",
            full_text=text,
            line_count=1,
            char_count=len(text),
            blob_path=None,
            content_hash=h,
        )
        self.assertTrue(created)
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(len(snap), 1)
        self.assertEqual(snap[0]["id"], str(item_id))
        self.assertEqual(snap[0]["type"], "text")
        self.assertEqual(snap[0]["icon"], "󰅇")

    def test_concurrent_captures_keep_one_item(self):
        workers = 3
        start = Barrier(workers)

        def capture(_):
            start.wait()
            return clipboard_store.record_item(
                "image", "image/png", ["image/png"], "Imagem PNG",
                "[Imagem PNG]", 1, 0, "same.png", "same-image-hash"
            )

        with ThreadPoolExecutor(max_workers=workers) as pool:
            results = list(pool.map(capture, range(workers)))

        self.assertEqual(len({item_id for item_id, _ in results}), 1)
        self.assertEqual(sum(created for _, created in results), 1)
        with closing(sqlite3.connect(clipboard_store.DB_PATH)) as conn, conn:
            count = conn.execute(
                "SELECT COUNT(*) FROM clipboard_items WHERE content_hash = ?",
                ("same-image-hash",),
            ).fetchone()[0]
        self.assertEqual(count, 1)

    def test_change_marker_updates_only_when_history_changes(self):
        initial = clipboard_store.CHANGE_FILE.read_text(encoding="ascii")
        clipboard_store.record_item(
            "text", "text/plain", ["text/plain"], "A", "A", 1, 1, None, "hash-a"
        )
        changed = clipboard_store.CHANGE_FILE.read_text(encoding="ascii")
        self.assertNotEqual(changed, initial)
        clipboard_store.record_item(
            "text", "text/plain", ["text/plain"], "A", "A", 1, 1, None, "hash-a"
        )
        self.assertEqual(clipboard_store.CHANGE_FILE.read_text(encoding="ascii"), changed)

    def test_snapshot_hides_existing_duplicate_hashes(self):
        with closing(sqlite3.connect(clipboard_store.DB_PATH)) as conn, conn:
            for created_at in (1000, 1001, 1002):
                conn.execute("""
                    INSERT INTO clipboard_items (
                        created_at, content_hash, primary_mime, mime_types,
                        text_preview, full_text, item_type
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """, (created_at, "old-race-hash", "image/png",
                      '["image/png"]', "Imagem PNG", "[Imagem PNG]", "image"))

        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(len(snap), 1)
        self.assertEqual(snap[0]["signature"], "old-race-hash")

    def test_case_b_multiline_text(self):
        text = "Line 1\nLine 2\nLine 3"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        item_id, _ = clipboard_store.record_item(
            item_type="text",
            primary_mime="text/plain;charset=utf-8",
            mime_types_list=["text/plain;charset=utf-8"],
            text_preview="Line 1 Line 2 Line 3",
            full_text=text,
            line_count=3,
            char_count=len(text),
            blob_path=None,
            content_hash=h,
        )
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["lineCount"], 3)
        self.assertIn("3 linhas", snap[0]["subtitle"])

    def test_case_c_url(self):
        url = "https://github.com/emanuelserpa/dotfiles"
        h = hashlib.sha256(url.encode("utf-8")).hexdigest()
        clipboard_store.record_item(
            item_type="text",
            primary_mime="text/plain",
            mime_types_list=["text/plain"],
            text_preview=url,
            full_text=url,
            line_count=1,
            char_count=len(url),
            blob_path=None,
            content_hash=h,
        )
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["icon"], "󰌷")

    def test_case_d_code(self):
        code = "function test() { return 42; }"
        h = hashlib.sha256(code.encode("utf-8")).hexdigest()
        clipboard_store.record_item(
            item_type="text",
            primary_mime="text/plain",
            mime_types_list=["text/plain"],
            text_preview=code,
            full_text=code,
            line_count=1,
            char_count=len(code),
            blob_path=None,
            content_hash=h,
        )
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["icon"], "󰘐")

    def test_case_e_png_image(self):
        raw = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
        blob_path, h = clipboard_store.save_blob(raw, ".png")
        item_id, _ = clipboard_store.record_item(
            item_type="image",
            primary_mime="image/png",
            mime_types_list=["image/png"],
            text_preview="Imagem PNG",
            full_text="[Imagem PNG]",
            line_count=1,
            char_count=0,
            blob_path=blob_path,
            content_hash=h,
        )
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["type"], "image")
        self.assertEqual(snap[0]["mime"], "image/png")
        self.assertEqual(snap[0]["icon"], "󰋩")
        self.assertTrue((clipboard_store.BLOBS_DIR / blob_path).exists())

    def test_case_f_jpeg_image(self):
        raw = b"\xff\xd8\xff\xe0\x00\x10JFIF"
        blob_path, h = clipboard_store.save_blob(raw, ".jpg")
        clipboard_store.record_item(
            item_type="image",
            primary_mime="image/jpeg",
            mime_types_list=["image/jpeg"],
            text_preview="Imagem JPEG",
            full_text="[Imagem JPEG]",
            line_count=1,
            char_count=0,
            blob_path=blob_path,
            content_hash=h,
        )
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["type"], "image")
        self.assertEqual(snap[0]["mime"], "image/jpeg")

    def test_open_image_uses_the_default_viewer_for_the_stored_blob(self):
        blob_path, content_hash = clipboard_store.save_blob(b"png-image", ".png")
        item_id, _ = clipboard_store.record_item(
            item_type="image",
            primary_mime="image/png",
            mime_types_list=["image/png"],
            text_preview="Imagem PNG",
            full_text="[Imagem PNG]",
            line_count=1,
            char_count=0,
            blob_path=blob_path,
            content_hash=content_hash,
        )

        with patch.object(clipboard_store.subprocess, "Popen") as popen:
            ok, error = clipboard_store.open_image(str(item_id), content_hash)

        self.assertTrue(ok)
        self.assertIsNone(error)
        self.assertEqual(popen.call_args.args[0], ["xdg-open", str(clipboard_store.BLOBS_DIR / blob_path)])

    def test_open_image_rejects_stale_or_non_image_clipboard_items(self):
        item_id, _ = clipboard_store.record_item(
            item_type="text",
            primary_mime="text/plain",
            mime_types_list=["text/plain"],
            text_preview="plain text",
            full_text="plain text",
            line_count=1,
            char_count=10,
            blob_path=None,
            content_hash="text-hash",
        )

        with patch.object(clipboard_store.subprocess, "Popen") as popen:
            ok, error = clipboard_store.open_image(str(item_id), "stale-hash")
            self.assertFalse(ok)
            self.assertEqual(error, "Item modificado")

            ok, error = clipboard_store.open_image(str(item_id), "text-hash")

        self.assertFalse(ok)
        self.assertEqual(error, "O item não contém uma imagem")
        popen.assert_not_called()

    def test_case_g_uri_list(self):
        uris = "file:///home/user/document.pdf\r\nfile:///home/user/image.png"
        h = hashlib.sha256(uris.encode("utf-8")).hexdigest()
        clipboard_store.record_item(
            item_type="text",
            primary_mime="text/uri-list",
            mime_types_list=["text/uri-list", "text/plain"],
            text_preview="file:///home/user/document.pdf ...",
            full_text=uris,
            line_count=2,
            char_count=len(uris),
            blob_path=None,
            content_hash=h,
        )
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["mime"], "text/uri-list")

    def test_case_h_duplicate_deduplication(self):
        text = "Repetitive copy"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        id1, created1 = clipboard_store.record_item(
            "text", "text/plain", ["text/plain"], text, text, 1, len(text), None, h
        )
        id2, created2 = clipboard_store.record_item(
            "text", "text/plain", ["text/plain"], text, text, 1, len(text), None, h
        )
        self.assertTrue(created1)
        self.assertFalse(created2)
        self.assertEqual(id1, id2)
        self.assertEqual(len(clipboard_store.get_snapshot(10)), 1)

    def test_case_i_promote_older_item(self):
        id1, _ = clipboard_store.record_item("text", "text/plain", ["text/plain"], "A", "A", 1, 1, None, "hashA")
        id2, _ = clipboard_store.record_item("text", "text/plain", ["text/plain"], "B", "B", 1, 1, None, "hashB")
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap[0]["id"], str(id2))

        # Re-copy A
        id_a_again, created = clipboard_store.record_item("text", "text/plain", ["text/plain"], "A", "A", 1, 1, None, "hashA")
        self.assertTrue(created)
        self.assertEqual(id_a_again, id1)
        snap2 = clipboard_store.get_snapshot(10)
        self.assertEqual(snap2[0]["id"], str(id1))
        self.assertEqual(len(snap2), 2)

    def test_case_j_remove_item(self):
        raw = b"\x89PNGtest_blob"
        blob_path, h = clipboard_store.save_blob(raw, ".png")
        item_id, _ = clipboard_store.record_item(
            "image", "image/png", ["image/png"], "Imagem PNG", "[Imagem PNG]", 1, 0, blob_path, h
        )
        self.assertTrue((clipboard_store.BLOBS_DIR / blob_path).exists())

        ok, err = clipboard_store.remove_item(str(item_id), h)
        self.assertTrue(ok)
        self.assertIsNone(err)
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(len(snap), 0)
        # Blob must be deleted because no other item references it
        self.assertFalse((clipboard_store.BLOBS_DIR / blob_path).exists())

    def test_case_k_persistence(self):
        clipboard_store.record_item("text", "text/plain", ["text/plain"], "Persist", "Persist", 1, 7, None, "hashP")
        # Reconnect
        conn = clipboard_store.get_db()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM clipboard_items")
        cnt = cur.fetchone()[0]
        conn.close()
        self.assertEqual(cnt, 1)

    def test_case_l_wal_recovery(self):
        # Insert item and verify WAL mode
        conn = clipboard_store.get_db()
        mode = conn.execute("PRAGMA journal_mode").fetchone()[0]
        self.assertEqual(mode.lower(), "wal")
        conn.close()

    def test_case_m_empty_clipboard(self):
        snap = clipboard_store.get_snapshot(10)
        self.assertEqual(snap, [])

    def test_case_p_retention_pruning(self):
        # Add 505 items
        for i in range(505):
            h = f"hash_{i}"
            clipboard_store.record_item("text", "text/plain", ["text/plain"], f"Item {i}", f"Item {i}", 1, 6, None, h)
        conn = clipboard_store.get_db()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM clipboard_items WHERE pinned = 0")
        cnt = cur.fetchone()[0]
        conn.close()
        self.assertEqual(cnt, 500)

    def test_case_n_missing_wl_clipboard(self):
        import subprocess
        # Test launcher-data.py response when wl-clipboard is mocked or missing
        orig_path = os.environ.get("PATH", "")
        try:
            os.environ["PATH"] = "/nonexistent"
            p = subprocess.run(
                [sys.executable, str(SCRIPTS_DIR / "launcher-data.py"), "clipboard-snapshot", "10"],
                capture_output=True,
                text=True,
                env=os.environ
            )
            data = json.loads(p.stdout)
            self.assertFalse(data["available"])
            self.assertEqual(data["backend"], "native")
            self.assertIn("wl-clipboard não disponível", data["error"])
        finally:
            os.environ["PATH"] = orig_path

    def test_case_o_size_limits(self):
        # Verify size limit constants
        self.assertEqual(clipboard_store.MAX_TEXT_BYTES, 2 * 1024 * 1024)
        self.assertEqual(clipboard_store.MAX_BLOB_BYTES, 25 * 1024 * 1024)

    def test_case_q_lazy_thumbnails(self):
        blob1, h1 = clipboard_store.save_blob(b"png1", ".png")
        id1, _ = clipboard_store.record_item("image", "image/png", ["image/png"], "Img 1", "[Img 1]", 1, 0, blob1, h1)
        blob2, h2 = clipboard_store.save_blob(b"png2", ".png")
        id2, _ = clipboard_store.record_item("image", "image/png", ["image/png"], "Img 2", "[Img 2]", 1, 0, blob2, h2)

        # Request thumbnail only for id2
        thumbs = clipboard_store.get_thumbnails([{"id": str(id2)}])
        self.assertEqual(len(thumbs), 1)
        self.assertEqual(thumbs[0]["id"], str(id2))
        self.assertTrue(thumbs[0]["thumbnail"].startswith("file://"))

    def test_case_r_thumb_downscales_and_caches(self):
        from PIL import Image
        big = self.test_dir / "big.png"
        Image.new("RGB", (1600, 900), color=(10, 20, 30)).save(big)
        blob, h = clipboard_store.save_blob(big.read_bytes(), ".png")
        thumb_uri = clipboard_store.thumb_for_blob(h, blob)
        self.assertTrue(thumb_uri.startswith("file://"))
        self.assertTrue(thumb_uri.endswith(".jpg"))
        thumb_path = Path(thumb_uri.replace("file://", "", 1))
        with Image.open(thumb_path) as t:
            self.assertLessEqual(max(t.size), clipboard_store.THUMB_MAX_SIDE)
        # Second call hits cache
        self.assertEqual(clipboard_store.thumb_for_blob(h, blob), thumb_uri)
        # Missing blob -> None
        self.assertIsNone(clipboard_store.thumb_for_blob("nope", "missing.png"))

    def test_case_s_blobs_byte_cap(self):
        orig_cap = clipboard_store.MAX_BLOBS_TOTAL_BYTES
        clipboard_store.MAX_BLOBS_TOTAL_BYTES = 2000
        try:
            for i in range(6):
                payload = bytes([i % 256]) * 900
                blob, h = clipboard_store.save_blob(payload, ".png")
                clipboard_store.record_item(
                    "image", "image/png", ["image/png"], f"Img {i}",
                    f"[Img {i}]", 1, 0, blob, h)
            total = clipboard_store._blobs_total_bytes()
            self.assertLessEqual(total, clipboard_store.MAX_BLOBS_TOTAL_BYTES + 900)
            remaining = clipboard_store.get_snapshot(60)
            self.assertLess(len(remaining), 6)
        finally:
            clipboard_store.MAX_BLOBS_TOTAL_BYTES = orig_cap

    def test_case_t_prune_orphan_thumbs(self):
        thumbs_dir = clipboard_store.THUMBS_DIR
        thumbs_dir.mkdir(parents=True, exist_ok=True)
        orphan = thumbs_dir / "deadbeef.jpg"
        orphan.write_bytes(b"fake")
        blob, h = clipboard_store.save_blob(b"png-live", ".png")
        clipboard_store.record_item(
            "image", "image/png", ["image/png"], "Live",
            "[Live]", 1, 0, blob, h)
        live_thumb = thumbs_dir / f"{h}.jpg"
        live_thumb.write_bytes(b"fake")
        pruned = clipboard_store.prune_orphan_thumbs()
        self.assertGreaterEqual(pruned, 1)
        self.assertFalse(orphan.exists())
        self.assertTrue(live_thumb.exists())


class ClipboardCaptureRetryTestCase(unittest.TestCase):
    """Transient owners (screenshot tools) may serve empty bytes on the
    first read after wl-paste --watch fires; capture must retry briefly."""

    def setUp(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "clipboard_daemon", SCRIPTS_DIR / "clipboard-daemon.py")
        self.daemon = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.daemon)

    def _run_with_reads(self, reads):
        import subprocess as sp
        from unittest.mock import patch

        calls = {"n": 0}

        def fake_run(cmd, **kwargs):
            calls["n"] += 1
            m = sp.CompletedProcess(cmd, 0, stdout=reads[min(calls["n"] - 1, len(reads) - 1)])
            return m

        recorded = {}

        def fake_record_item(**kw):
            recorded.update(kw)
            return (1, True)

        with patch.object(self.daemon.subprocess, "run", side_effect=fake_run), \
             patch.object(self.daemon, "record_item", side_effect=fake_record_item), \
             patch.object(self.daemon, "save_blob", return_value=("hash.png", "hash")), \
             patch.object(self.daemon.time, "sleep", return_value=None):
            self.daemon.capture_clipboard()
        return recorded, calls["n"]

    def test_case_r_image_retry_on_empty_first_read(self):
        recorded, n_calls = self._run_with_reads([
            "image/png\n",  # initial --list-types
            b"",            # first paste: transient owner not ready
            b"\x89PNGdata",  # second paste: bytes served
        ])
        self.assertEqual(recorded.get("item_type"), "image")
        self.assertEqual(recorded.get("primary_mime"), "image/png")
        self.assertEqual(n_calls, 3)

    def test_case_r_ready_owner_uses_one_type_query(self):
        recorded, n_calls = self._run_with_reads(["text/plain\n", b"hello"])
        self.assertEqual(recorded.get("full_text"), "hello")
        self.assertEqual(n_calls, 2)

    def test_case_s_gives_up_on_persistently_empty(self):
        recorded, _ = self._run_with_reads(["image/png\n", b"", b"", b"", b"", b"", b""])
        self.assertEqual(recorded, {})

if __name__ == "__main__":
    unittest.main()
