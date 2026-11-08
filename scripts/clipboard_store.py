#!/usr/bin/env python3
"""
Storage and SQLite manager for Quickshell native clipboard.
Path: ~/.local/share/quickshell/clipboard/
  - clipboard.db (SQLite with WAL)
  - blobs/ (image and large content store)
"""

import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
sys.dont_write_bytecode = True
import time
from pathlib import Path


BASE_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "quickshell" / "clipboard"
DB_PATH = BASE_DIR / "clipboard.db"
BLOBS_DIR = BASE_DIR / "blobs"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
CAPTURE_SETTINGS_FILE = STATE_DIR / "clipboard-capture.json"

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell"
CACHE_INDEX_FILE = CACHE_DIR / "clipboard-index.json"
CHANGE_FILE = CACHE_DIR / "clipboard-change"
THUMBS_DIR = CACHE_DIR / "clipboard-thumbs"
THUMB_MAX_SIDE = 640

MAX_UNPINNED_ITEMS = 500
MAX_TEXT_BYTES = 2 * 1024 * 1024       # 2 MiB
MAX_BLOB_BYTES = 25 * 1024 * 1024      # 25 MiB
MAX_BLOBS_TOTAL_BYTES = 256 * 1024 * 1024  # 256 MiB on disk for blobs

IMAGE_EXTENSIONS = {
    "image/png": ".png",
    "image/jpeg": ".jpg",
    "image/webp": ".webp",
    "image/gif": ".gif",
    "image/bmp": ".bmp",
    "image/svg+xml": ".svg",
}

def ensure_dirs():
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    BLOBS_DIR.mkdir(parents=True, exist_ok=True)
    try:
        BASE_DIR.chmod(0o700)
        BLOBS_DIR.chmod(0o700)
    except OSError:
        pass

def get_db():
    ensure_dirs()
    conn = sqlite3.connect(str(DB_PATH), timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    return conn

def init_db():
    conn = get_db()
    with conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at INTEGER NOT NULL,
                content_hash TEXT NOT NULL,
                primary_mime TEXT,
                mime_types TEXT NOT NULL,
                text_preview TEXT,
                full_text TEXT,
                line_count INTEGER DEFAULT 0,
                char_count INTEGER DEFAULT 0,
                item_type TEXT NOT NULL,
                blob_path TEXT,
                pinned INTEGER DEFAULT 0
            );
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_clipboard_created ON clipboard_items(created_at DESC);")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_clipboard_hash ON clipboard_items(content_hash);")
    conn.close()
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        if not CHANGE_FILE.exists():
            CHANGE_FILE.write_text("0", encoding="ascii")
    except OSError:
        pass

def notify_change():
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        CHANGE_FILE.write_text(str(time.time_ns()), encoding="ascii")
    except OSError:
        pass

def clipboard_capture_paused():
    """Return the persisted preference; unreadable state fails closed to paused."""
    try:
        settings = json.loads(CAPTURE_SETTINGS_FILE.read_text(encoding="utf-8"))
        return bool(settings.get("paused", True)) if isinstance(settings, dict) else True
    except FileNotFoundError:
        return False
    except (OSError, ValueError, TypeError):
        return True

def set_clipboard_capture_paused(paused):
    """Persist capture pause atomically with private state-file permissions."""
    tmp_file = CAPTURE_SETTINGS_FILE.with_suffix(CAPTURE_SETTINGS_FILE.suffix + ".tmp")
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
        STATE_DIR.chmod(0o700)
        tmp_file.write_text(json.dumps({"paused": bool(paused)}) + "\n", encoding="utf-8")
        tmp_file.chmod(0o600)
        tmp_file.replace(CAPTURE_SETTINGS_FILE)
        return True
    except OSError:
        try:
            tmp_file.unlink(missing_ok=True)
        except OSError:
            pass
        return False

def classify_text(clean_text):
    t = clean_text.strip()
    if t.startswith("http://") or t.startswith("https://"):
        return "󰌷"
    if (
        "{" in t
        or "function" in t
        or "import " in t
        or "def " in t
        or "<" in t
    ):
        return "󰘐"
    return "󰅇"

def save_blob(content_bytes, extension=".bin"):
    ensure_dirs()
    content_hash = hashlib.sha256(content_bytes).hexdigest()
    blob_name = f"{content_hash}{extension}"
    blob_file = BLOBS_DIR / blob_name
    if not blob_file.exists():
        tmp_file = blob_file.with_suffix(".tmp")
        tmp_file.write_bytes(content_bytes)
        tmp_file.replace(blob_file)
    return blob_name, content_hash

def record_item(
    item_type,
    primary_mime,
    mime_types_list,
    text_preview,
    full_text,
    line_count,
    char_count,
    blob_path,
    content_hash,
):
    init_db()
    conn = get_db()
    try:
        # Claim the write lock before checking for an existing hash. Several
        # wl-paste callbacks can start for one selection; a deferred transaction
        # lets each callback observe "missing" and insert the same image.
        conn.execute("BEGIN IMMEDIATE")
        with conn:
            cur = conn.cursor()
            cur.execute("SELECT id, content_hash FROM clipboard_items ORDER BY created_at DESC, id DESC LIMIT 1")
            top = cur.fetchone()
            if top and top["content_hash"] == content_hash:
                return top["id"], False

            cur.execute("SELECT MAX(created_at) FROM clipboard_items")
            max_row = cur.fetchone()
            max_ts = max_row[0] if max_row and max_row[0] else 0
            now_ts = max(int(time.time() * 1000), max_ts + 1)

            cur.execute("SELECT id FROM clipboard_items WHERE content_hash = ? LIMIT 1", (content_hash,))
            existing = cur.fetchone()
            if existing:
                item_id = existing["id"]
                cur.execute("UPDATE clipboard_items SET created_at = ? WHERE id = ?", (now_ts, item_id))
            else:
                cur.execute("""
                    INSERT INTO clipboard_items (
                        created_at, content_hash, primary_mime, mime_types,
                        text_preview, full_text, line_count, char_count,
                        item_type, blob_path, pinned
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                """, (
                    now_ts, content_hash, primary_mime, json.dumps(mime_types_list),
                    text_preview, full_text, line_count, char_count,
                    item_type, blob_path
                ))
                item_id = cur.lastrowid

            # Retention limit: max 500 unpinned items
            cur.execute("SELECT COUNT(*) FROM clipboard_items WHERE pinned = 0")
            unpinned_count = cur.fetchone()[0]
            if unpinned_count > MAX_UNPINNED_ITEMS:
                excess = unpinned_count - MAX_UNPINNED_ITEMS
                cur.execute("SELECT id, blob_path FROM clipboard_items WHERE pinned = 0 ORDER BY created_at ASC LIMIT ?", (excess,))
                to_del = cur.fetchall()
                _delete_rows(cur, to_del)

            # Storage cap: total blob bytes on disk
            if blob_path:
                _enforce_blobs_byte_cap(cur)
        notify_change()
        return item_id, True
    finally:
        conn.close()


def _delete_rows(cur, rows):
    """Delete item rows and unlink blobs no other row references."""
    rows = list(rows)
    if not rows:
        return
    del_ids = [r["id"] for r in rows]
    blobs_to_check = [r["blob_path"] for r in rows if r["blob_path"]]
    cur.execute(f"DELETE FROM clipboard_items WHERE id IN ({','.join('?' * len(del_ids))})", del_ids)
    for b in set(blobs_to_check):
        cur.execute("SELECT 1 FROM clipboard_items WHERE blob_path = ? LIMIT 1", (b,))
        if not cur.fetchone():
            try:
                (BLOBS_DIR / b).unlink(missing_ok=True)
            except OSError:
                pass


def _blobs_total_bytes():
    total = 0
    try:
        for p in BLOBS_DIR.iterdir():
            try:
                if p.is_file():
                    total += p.stat().st_size
            except OSError:
                pass
    except OSError:
        pass
    return total


def _enforce_blobs_byte_cap(cur):
    total = _blobs_total_bytes()
    if total <= MAX_BLOBS_TOTAL_BYTES:
        return
    # Oldest unpinned first; never delete pinned items for size.
    cur.execute("SELECT id, blob_path FROM clipboard_items WHERE pinned = 0 ORDER BY created_at ASC")
    for r in cur.fetchall():
        if _blobs_total_bytes() <= MAX_BLOBS_TOTAL_BYTES:
            break
        _delete_rows(cur, [r])


def prune_orphan_thumbs():
    """Delete cached thumbnails whose blob hash is gone from the database."""
    try:
        thumbs = [p for p in THUMBS_DIR.iterdir() if p.is_file() and p.suffix == ".jpg"]
    except OSError:
        return 0
    if not thumbs:
        return 0
    init_db()
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("SELECT DISTINCT content_hash FROM clipboard_items")
        live = {r[0] for r in cur.fetchall()}
    finally:
        conn.close()
    pruned = 0
    for p in thumbs:
        if p.stem not in live:
            try:
                p.unlink()
                pruned += 1
            except OSError:
                pass
    return pruned

def get_snapshot(limit=60):
    init_db()
    conn = get_db()
    cur = conn.cursor()
    cur.execute("""
        WITH ranked AS (
            SELECT id, content_hash, primary_mime, text_preview, full_text,
                   line_count, char_count, item_type, blob_path, created_at,
                   ROW_NUMBER() OVER (
                       PARTITION BY content_hash
                       ORDER BY created_at DESC, id DESC
                   ) AS duplicate_rank
            FROM clipboard_items
        )
        SELECT id, content_hash, primary_mime, text_preview, full_text,
               line_count, char_count, item_type, blob_path, created_at
        FROM ranked
        WHERE duplicate_rank = 1
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    """, (limit,))
    rows = cur.fetchall()
    conn.close()

    items = []
    for r in rows:
        item_id = str(r["id"])
        item_type = r["item_type"]
        preview = r["text_preview"] or ""
        raw_full = r["full_text"] or ""
        full_text = raw_full[:8000] + ("\n\n… [conteúdo truncado no preview]" if len(raw_full) > 8000 else "")
        line_count = int(r["line_count"] or 1)
        char_count = int(r["char_count"] or 0)
        primary_mime = r["primary_mime"] or ("image/png" if item_type == "image" else "text/plain")

        if item_type == "image":
            icon = "󰋩"
            sub = preview
        else:
            icon = classify_text(raw_full)
            sub = f"{line_count} linhas · {char_count} chars" if line_count > 1 else f"{char_count} chars"

        items.append({
            "id": item_id,
            "signature": r["content_hash"],
            "preview": preview,
            "fullText": full_text,
            "lineCount": line_count,
            "charCount": char_count,
            "subtitle": sub,
            "icon": icon,
            "type": item_type,
            "mime": primary_mime,
        })
    return items

def restore_item(item_id, signature=None):
    init_db()
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, content_hash, primary_mime, full_text, item_type, blob_path
            FROM clipboard_items WHERE id = ?
        """, (item_id,))
        row = cur.fetchone()
        if not row:
            return False, "Item não encontrado"

        if signature and row["content_hash"] != signature:
            return False, "Item modificado"

        item_type = row["item_type"]
        primary_mime = row["primary_mime"]

        if item_type == "image":
            blob_path = row["blob_path"]
            if not blob_path:
                return False, "Imagem ausente"
            full_path = BLOBS_DIR / blob_path
            if not full_path.exists():
                return False, "Arquivo de imagem ausente"
            img_bytes = full_path.read_bytes()
            res = subprocess.run(["wl-copy", "--type", primary_mime or "image/png"], input=img_bytes)
            if res.returncode != 0:
                return False, "wl-copy falhou"
        else:
            text = row["full_text"] or ""
            cmd = ["wl-copy"]
            if primary_mime and primary_mime not in ("text/plain", "UTF8_STRING"):
                cmd.extend(["--type", primary_mime])
            else:
                cmd.extend(["--type", "text/plain;charset=utf-8"])
            res = subprocess.run(cmd, input=text.encode("utf-8"))
            if res.returncode != 0:
                return False, "wl-copy falhou"

        now_ts = int(time.time() * 1000)
        with conn:
            conn.execute("UPDATE clipboard_items SET created_at = ? WHERE id = ?", (now_ts, item_id))
        notify_change()
        return True, None
    finally:
        conn.close()

def open_image(item_id, signature=None):
    """Open a stored clipboard image with the desktop's default application."""
    init_db()
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT content_hash, item_type, blob_path
            FROM clipboard_items WHERE id = ?
        """, (item_id,))
        row = cur.fetchone()
        if not row:
            return False, "Item não encontrado"
        if signature and row["content_hash"] != signature:
            return False, "Item modificado"
        if row["item_type"] != "image" or not row["blob_path"]:
            return False, "O item não contém uma imagem"

        blob_root = BLOBS_DIR.resolve()
        image_path = (blob_root / row["blob_path"]).resolve()
        if not image_path.is_relative_to(blob_root):
            return False, "Caminho de imagem inválido"
        if not image_path.is_file():
            return False, "Arquivo de imagem ausente"

        try:
            subprocess.Popen(
                ["xdg-open", str(image_path)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except OSError:
            return False, "Não foi possível abrir o visualizador de imagens"
        return True, None
    finally:
        conn.close()

def remove_item(item_id, signature=None):
    init_db()
    conn = get_db()
    try:
        cur = conn.cursor()
        cur.execute("SELECT id, content_hash, blob_path FROM clipboard_items WHERE id = ?", (item_id,))
        row = cur.fetchone()
        if not row:
            _remove_item_from_cache(item_id)
            return True, None

        if signature and row["content_hash"] != signature:
            return False, "Item modificado"

        blob_path = row["blob_path"]
        content_hash = row["content_hash"]
        with conn:
            conn.execute("DELETE FROM clipboard_items WHERE id = ?", (item_id,))
            cur.execute("SELECT 1 FROM clipboard_items WHERE content_hash = ? LIMIT 1", (content_hash,))
            has_same_content = cur.fetchone() is not None
            if blob_path:
                cur.execute("SELECT 1 FROM clipboard_items WHERE blob_path = ? LIMIT 1", (blob_path,))
                if not cur.fetchone():
                    try:
                        (BLOBS_DIR / blob_path).unlink(missing_ok=True)
                    except OSError:
                        pass
        if not has_same_content:
            try:
                (THUMBS_DIR / f"{content_hash}.jpg").unlink(missing_ok=True)
            except OSError:
                pass
        _remove_item_from_cache(item_id)
        notify_change()
        return True, None
    finally:
        conn.close()


def _remove_item_from_cache(item_id):
    """Keep the legacy cached snapshot consistent with a successful removal."""
    if not CACHE_INDEX_FILE.exists():
        return
    try:
        cached = json.loads(CACHE_INDEX_FILE.read_text(encoding="utf-8"))
        if not isinstance(cached, dict) or not isinstance(cached.get("items"), list):
            return
        cached["items"] = [
            item for item in cached["items"]
            if not isinstance(item, dict) or str(item.get("id")) != str(item_id)
        ]
        tmp_file = CACHE_INDEX_FILE.with_suffix(CACHE_INDEX_FILE.suffix + ".tmp")
        tmp_file.write_text(json.dumps(cached, ensure_ascii=False), encoding="utf-8")
        tmp_file.replace(CACHE_INDEX_FILE)
    except (OSError, ValueError, TypeError):
        # The cache is disposable; the SQLite database remains authoritative.
        try:
            CACHE_INDEX_FILE.with_suffix(CACHE_INDEX_FILE.suffix + ".tmp").unlink(missing_ok=True)
        except OSError:
            pass

def thumb_for_blob(content_hash, blob_path):
    """Return a cached downscaled thumbnail URI for a blob.

    Full screenshots (multi-MB PNGs) decode far too slowly when the UI
    loads dozens at once; a pre-scaled ~640px JPEG decodes in ~10ms.
    Falls back to the original blob URI when PIL is unavailable.
    """
    src = BLOBS_DIR / (blob_path or "")
    if not blob_path or not src.is_file():
        return None
    try:
        THUMBS_DIR.mkdir(parents=True, exist_ok=True)
    except OSError:
        return src.as_uri()
    thumb = THUMBS_DIR / f"{content_hash}.jpg"
    if not thumb.is_file() or thumb.stat().st_mtime < src.stat().st_mtime:
        try:
            from PIL import Image
            with Image.open(src) as im:
                im = im.convert("RGB")
                im.thumbnail((THUMB_MAX_SIDE, THUMB_MAX_SIDE), Image.LANCZOS)
                im.save(thumb, "JPEG", quality=72)
        except Exception:
            try:
                thumb.unlink(missing_ok=True)
            except OSError:
                pass
            return src.as_uri()
    return thumb.as_uri()


def get_thumbnails(request_items):
    ids = [str(r.get("id")) for r in request_items if isinstance(r, dict) and r.get("id")]
    if not ids:
        return []
    prune_orphan_thumbs()
    init_db()
    conn = get_db()
    cur = conn.cursor()
    placeholders = ",".join("?" * len(ids))
    cur.execute(f"SELECT id, content_hash, blob_path FROM clipboard_items WHERE id IN ({placeholders}) AND item_type = 'image'", ids)
    rows = cur.fetchall()
    conn.close()

    res = []
    for r in rows:
        uri = thumb_for_blob(r["content_hash"], r["blob_path"])
        if uri:
            res.append({"id": str(r["id"]), "thumbnail": uri})
    return res
