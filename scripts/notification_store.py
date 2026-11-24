#!/usr/bin/env python3
"""Persistent snapshots of Lume Shell notification history (SQLite/WAL)."""

import hashlib
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from lume_paths import _rewrite_notification_image_prefixes, data_dir, migrate_dir

BASE_DIR = data_dir() / "notifications"
DB_PATH = BASE_DIR / "notifications.db"
IMAGE_DIR = BASE_DIR / "images"
MAX_HISTORY = 2000
LOAD_LIMIT = 500
MAX_TEXT_LENGTH = 32768
EXCLUDED_HISTORY_APPS = ("battery", "bateria", "upower")
MAX_IMAGE_CACHE_BYTES = 256 * 1024 * 1024
MAX_CACHED_NOTIFICATION_IMAGES = 2000
ORPHAN_IMAGE_MAX_AGE = 15 * 60
IMAGE_CLEANUP_INTERVAL = 10 * 60
IMAGE_CLEANUP_BATCH = 100
_last_image_cleanup = 0.0
_image_cleanup_calls = 0


def is_excluded_from_history(app_name):
    return str(app_name or "").strip().lower() in EXCLUDED_HISTORY_APPS


def get_db():
    migrate_dir(BASE_DIR)
    _rewrite_notification_image_prefixes(BASE_DIR)
    BASE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    IMAGE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        BASE_DIR.chmod(0o700)
        IMAGE_DIR.chmod(0o700)
    except OSError:
        pass
    conn = sqlite3.connect(str(DB_PATH), timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA synchronous=NORMAL")
    return conn


def init_db(conn=None):
    owns_connection = conn is None
    if owns_connection:
        conn = get_db()
    try:
        with conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    received_at INTEGER NOT NULL,
                    fingerprint TEXT NOT NULL,
                    app_name TEXT NOT NULL DEFAULT '',
                    desktop_entry TEXT NOT NULL DEFAULT '',
                    app_icon TEXT NOT NULL DEFAULT '',
                    image TEXT NOT NULL DEFAULT '',
                    summary TEXT NOT NULL DEFAULT '',
                    body TEXT NOT NULL DEFAULT '',
                    urgency INTEGER NOT NULL DEFAULT 1,
                    hints_json TEXT NOT NULL DEFAULT '{}'
                )
            """)
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_notifications_received "
                "ON notifications(received_at DESC, id DESC)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_notifications_fingerprint "
                "ON notifications(fingerprint, received_at DESC)"
            )
            rows = conn.execute("""
                SELECT id, fingerprint, app_name, summary, body, image
                FROM notifications
            """).fetchall()
            for row in rows:
                image = row["image"]
                if image.startswith("image://qsimage/"):
                    image = ""
                payload = {
                    "appName": row["app_name"],
                    "summary": row["summary"],
                    "body": row["body"],
                    "image": image,
                }
                fingerprint = _fingerprint(payload)
                if image == row["image"] and fingerprint == row["fingerprint"]:
                    continue
                conn.execute("""
                    UPDATE notifications SET image = ?, fingerprint = ? WHERE id = ?
                """, (image, fingerprint, row["id"]))
        try:
            DB_PATH.chmod(0o600)
        except OSError:
            pass
    finally:
        if owns_connection:
            conn.close()


def _text(value, limit=MAX_TEXT_LENGTH):
    return str(value or "")[:limit]


def _fingerprint(payload):
    identity = "\n".join((
        _text(payload.get("appName")).strip(),
        _text(payload.get("summary")),
        _text(payload.get("body")),
        _text(payload.get("image")),
    ))
    return hashlib.sha256(identity.encode("utf-8", errors="replace")).hexdigest()


def _row_to_item(row):
    image = row["image"]
    if image.startswith("image://qsimage/"):
        image = ""
    return {
        "id": "archive-" + str(row["id"]),
        "receivedAt": int(row["received_at"]),
        "appName": row["app_name"],
        "desktopEntry": row["desktop_entry"],
        "appIcon": row["app_icon"],
        "image": image,
        "summary": row["summary"],
        "body": row["body"],
        "urgency": int(row["urgency"]),
        "hints": json.loads(row["hints_json"] or "{}"),
        "actions": [],
        "tracked": True,
        "archived": True,
    }


def cleanup_image_cache(conn, force=False):
    """Bound archived notification images and amortize filesystem scans."""
    global _last_image_cleanup, _image_cleanup_calls
    _image_cleanup_calls += 1
    now = time.monotonic()
    if (not force and _last_image_cleanup
            and _image_cleanup_calls < IMAGE_CLEANUP_BATCH
            and now - _last_image_cleanup < IMAGE_CLEANUP_INTERVAL):
        return

    _last_image_cleanup = now
    _image_cleanup_calls = 0
    image_root = IMAGE_DIR.resolve()
    prefix = str(image_root) + "/"
    rows = conn.execute("""
        SELECT id, received_at, app_name, summary, body, image
        FROM notifications
        WHERE substr(image, 1, ?) = ?
        ORDER BY received_at DESC, id DESC
    """, (len(prefix), prefix)).fetchall()

    referenced = set()
    removed_paths = []
    retained_bytes = 0
    retained_count = 0
    for row in rows:
        try:
            resolved = Path(row["image"]).resolve(strict=True)
            resolved.relative_to(image_root)
            if not resolved.name.startswith("notification-") or resolved.suffix != ".png":
                raise ValueError("unexpected notification image path")
            size = resolved.stat().st_size
        except (OSError, ValueError):
            fingerprint = _fingerprint({
                "appName": row["app_name"],
                "summary": row["summary"],
                "body": row["body"],
                "image": "",
            })
            conn.execute("UPDATE notifications SET image = '', fingerprint = ? WHERE id = ?",
                         (fingerprint, row["id"]))
            raw_path = Path(row["image"])
            try:
                if (raw_path.parent.resolve() == image_root
                        and raw_path.name.startswith("notification-")
                        and raw_path.suffix == ".png"
                        and raw_path.is_symlink()):
                    raw_path.unlink()
            except OSError:
                pass
            continue

        within_budget = (
            retained_count < MAX_CACHED_NOTIFICATION_IMAGES
            and retained_bytes + size <= MAX_IMAGE_CACHE_BYTES
        )
        if within_budget:
            referenced.add(resolved)
            retained_count += 1
            retained_bytes += size
            continue

        # Keep the notification text and discard only its old cached image.
        fingerprint = _fingerprint({
            "appName": row["app_name"],
            "summary": row["summary"],
            "body": row["body"],
            "image": "",
        })
        conn.execute("UPDATE notifications SET image = '', fingerprint = ? WHERE id = ?",
                     (fingerprint, row["id"]))
        removed_paths.append(resolved)
    conn.commit()

    for path in removed_paths:
        try:
            path.unlink()
        except OSError:
            pass

    cutoff = time.time() - ORPHAN_IMAGE_MAX_AGE
    for path in IMAGE_DIR.glob("notification-*.png"):
        try:
            resolved = path.resolve(strict=True)
            resolved.relative_to(image_root)
            if resolved not in referenced and path.stat().st_mtime < cutoff:
                path.unlink()
        except (OSError, ValueError):
            pass


def record_notification(payload, conn=None):
    owns_connection = conn is None
    if owns_connection:
        init_db()
    received_value = payload.get("receivedAt")
    received_at = int(time.time() * 1000 if received_value is None else received_value)
    fingerprint = _fingerprint(payload)
    app_name = _text(payload.get("appName"), 512)
    desktop_entry = _text(payload.get("desktopEntry"), 512)
    if is_excluded_from_history(app_name):
        return None, False
    app_icon = _text(payload.get("appIcon"), 2048)
    image = _text(payload.get("image"), 4096)
    summary = _text(payload.get("summary"))
    body = _text(payload.get("body"))
    urgency_value = payload.get("urgency")
    urgency = int(1 if urgency_value is None else urgency_value)
    hints = payload.get("hints")
    if not isinstance(hints, dict):
        hints = {}
    hints_json = json.dumps(hints, ensure_ascii=False, separators=(",", ":"))
    if owns_connection:
        conn = get_db()
    try:
        conn.execute("BEGIN IMMEDIATE")
        # NotificationServer can replay tracked notifications after a shell
        # reload. Ignore only an identical replay within the server's 2s window.
        existing = conn.execute("""
            SELECT id, received_at, fingerprint, app_name, desktop_entry, app_icon,
                   image, summary, body, urgency, hints_json
            FROM notifications
            WHERE fingerprint = ? AND received_at BETWEEN ? AND ?
            ORDER BY received_at DESC, id DESC LIMIT 1
        """, (fingerprint, received_at - 2000, received_at + 2000)).fetchone()
        if existing:
            conn.commit()
            return _row_to_item(existing), False

        cur = conn.execute("""
            INSERT INTO notifications (
                received_at, fingerprint, app_name, desktop_entry, app_icon,
                image, summary, body, urgency, hints_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (received_at, fingerprint, app_name, desktop_entry, app_icon,
              image, summary, body, urgency, hints_json))
        row_id = cur.lastrowid
        conn.execute("""
            DELETE FROM notifications
            WHERE id IN (
                SELECT id FROM notifications
                ORDER BY received_at DESC, id DESC
                LIMIT -1 OFFSET ?
            )
        """, (MAX_HISTORY,))
        conn.commit()
        cleanup_image_cache(conn)
        row = conn.execute("""
            SELECT id, received_at, fingerprint, app_name, desktop_entry, app_icon,
                   image, summary, body, urgency, hints_json
            FROM notifications WHERE id = ?
        """, (row_id,)).fetchone()
        return _row_to_item(row), True
    finally:
        if owns_connection:
            conn.close()


def get_history(limit=LOAD_LIMIT, conn=None):
    owns_connection = conn is None
    if owns_connection:
        init_db()
    limit = max(1, min(int(limit), MAX_HISTORY))
    if owns_connection:
        conn = get_db()
    try:
        rows = conn.execute(f"""
            SELECT id, received_at, fingerprint, app_name, desktop_entry, app_icon,
                   image, summary, body, urgency, hints_json
            FROM notifications
            ORDER BY received_at DESC, id DESC LIMIT ?
        """, (limit,)).fetchall()
        return [_row_to_item(row) for row in rows]
    finally:
        if owns_connection:
            conn.close()


def clear_history(conn=None):
    owns_connection = conn is None
    if owns_connection:
        init_db()
        conn = get_db()
    try:
        with conn:
            conn.execute("DELETE FROM notifications")
        cleanup_image_cache(conn, force=True)
    finally:
        if owns_connection:
            conn.close()


def delete_notification(request, conn=None):
    owns_connection = conn is None
    if owns_connection:
        init_db()
        conn = get_db()
    try:
        item_id = str(request.get("id") or "")
        if item_id.startswith("archive-"):
            try:
                row_id = int(item_id.removeprefix("archive-"))
            except ValueError:
                return {"type": "deleted", "id": item_id, "deleted": False}
            cur = conn.execute("DELETE FROM notifications WHERE id = ?", (row_id,))
            conn.commit()
            cleanup_image_cache(conn, force=True)
            return {"type": "deleted", "id": item_id, "deleted": cur.rowcount > 0}

        payload = request.get("notification") or {}
        received_at = int(payload.get("receivedAt", 0))
        fingerprint = _fingerprint(payload)
        row = conn.execute("""
            SELECT id FROM notifications
            WHERE fingerprint = ? AND received_at BETWEEN ? AND ?
            ORDER BY ABS(received_at - ?) ASC, id DESC LIMIT 1
        """, (fingerprint, received_at - 5000, received_at + 5000, received_at)).fetchone()
        if row is None:
            return {"type": "deleted", "id": "", "deleted": False}
        archive_id = "archive-" + str(row["id"])
        conn.execute("DELETE FROM notifications WHERE id = ?", (row["id"],))
        conn.commit()
        cleanup_image_cache(conn, force=True)
        return {"type": "deleted", "id": archive_id, "deleted": True}
    finally:
        if owns_connection:
            conn.close()


def delete_notification_group(request, conn=None):
    owns_connection = conn is None
    if owns_connection:
        init_db()
        conn = get_db()
    try:
        group_key = str(request.get("groupKey") or "")
        if group_key.startswith("desktop:"):
            where, value = "desktop_entry = ?", group_key.removeprefix("desktop:")
        elif group_key.startswith("name:"):
            where, value = "desktop_entry = '' AND app_name = ?", group_key.removeprefix("name:")
        else:
            return {"type": "group-deleted", "groupKey": group_key, "deleted": 0}
        with conn:
            cur = conn.execute(
                f"DELETE FROM notifications WHERE {where}", (value,)
            )
        cleanup_image_cache(conn, force=True)
        return {"type": "group-deleted", "groupKey": group_key,
                "deleted": cur.rowcount}
    finally:
        if owns_connection:
            conn.close()


def update_notification_image(request, conn=None):
    owns_connection = conn is None
    if owns_connection:
        init_db()
        conn = get_db()
    try:
        payload = request.get("notification") or {}
        source_image = _text(payload.get("sourceImage"), 4096)
        target_image = Path(_text(payload.get("image"), 4096))
        try:
            target_image.resolve().relative_to(IMAGE_DIR.resolve())
        except (OSError, ValueError):
            return {"type": "error", "error": "Caminho de imagem fora do cache"}
        if not target_image.is_file():
            return {"type": "error", "error": "Imagem arquivada não encontrada"}

        lookup = dict(payload)
        lookup["image"] = source_image
        fingerprint = _fingerprint(lookup)
        received_at = int(payload.get("receivedAt", 0))
        row = conn.execute("""
            SELECT id FROM notifications
            WHERE fingerprint = ? AND received_at BETWEEN ? AND ?
            ORDER BY ABS(received_at - ?) ASC, id DESC LIMIT 1
        """, (fingerprint, received_at - 5000, received_at + 5000,
              received_at)).fetchone()
        if row is None:
            try:
                target_image.unlink()
            except OSError:
                pass
            cleanup_image_cache(conn)
            return {"type": "image-updated", "updated": False}

        with conn:
            conn.execute("""
                UPDATE notifications SET image = ?, fingerprint = ? WHERE id = ?
            """, (str(target_image), _fingerprint(payload), row["id"]))
        cleanup_image_cache(conn)
        saved = conn.execute("""
            SELECT id, received_at, fingerprint, app_name, desktop_entry,
                   app_icon, image, summary, body, urgency, hints_json
            FROM notifications WHERE id = ?
        """, (row["id"],)).fetchone()
        return {"type": "image-updated", "updated": True,
                "item": _row_to_item(saved)}
    finally:
        if owns_connection:
            conn.close()


def handle_request(request, conn=None):
    op = request.get("op")
    if op == "load":
        return {"type": "loaded", "items": get_history(request.get("limit", LOAD_LIMIT), conn)}
    if op == "append":
        item, inserted = record_notification(request.get("notification") or {}, conn)
        return {"type": "stored", "item": item, "inserted": inserted}
    if op == "update_image":
        return update_notification_image(request, conn)
    if op == "clear":
        clear_history(conn)
        return {"type": "cleared"}
    if op == "delete":
        return delete_notification(request, conn)
    if op == "delete_group":
        return delete_notification_group(request, conn)
    return {"type": "error", "error": "Operação inválida"}


def serve():
    init_db()
    conn = get_db()
    cleanup_image_cache(conn, force=True)
    for line in sys.stdin:
        try:
            request = json.loads(line)
            if not isinstance(request, dict):
                raise ValueError("A solicitação precisa ser um objeto JSON")
            response = handle_request(request, conn)
        except Exception as error:  # Keep the line-oriented worker alive.
            response = {"type": "error", "error": str(error)}
        print(json.dumps(response, ensure_ascii=False, separators=(",", ":")), flush=True)
    conn.close()


if __name__ == "__main__":
    serve()
