#!/usr/bin/env python3
"""
Persistent clipboard daemon for Quickshell.
Monitors Wayland clipboard via `wl-paste --watch` and stores
items in SQLite and blob storage.
"""

import fcntl
import hashlib
import json
import os
import shutil
import signal
import subprocess
import sys
sys.dont_write_bytecode = True
import time
from pathlib import Path


# Add script directory to sys.path to load clipboard_store
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from clipboard_store import (
    BASE_DIR,
    IMAGE_EXTENSIONS,
    MAX_BLOB_BYTES,
    MAX_TEXT_BYTES,
    init_db,
    record_item,
    save_blob,
)

IMAGE_MIMES = [
    "image/png",
    "image/jpeg",
    "image/webp",
    "image/gif",
    "image/bmp",
    "image/svg+xml",
]

TEXT_MIMES = [
    "text/plain;charset=utf-8",
    "text/plain",
    "UTF8_STRING",
    "text/uri-list",
    "text/html",
]

# Transient owners (e.g. grimblast/swappy copy-and-exit) may not serve bytes
# on the very first read after `wl-paste --watch` fires. Retry briefly only
# when a read comes back empty; the happy path costs nothing extra.
LIST_RETRY_ATTEMPTS = 3
PASTE_RETRY_ATTEMPTS = 3
PASTE_RETRY_DELAY = 0.2
CAPTURE_ROUNDS = 3
IMAGE_PASTE_TIMEOUT = 3.0
TEXT_PASTE_TIMEOUT = 2.0


def _paste_once(mime, timeout):
    try:
        cp = subprocess.run(
            ["wl-paste", "--type", mime, "--no-newline"],
            capture_output=True,
            timeout=timeout,
        )
        if cp.returncode != 0:
            return b""
        return cp.stdout or b""
    except Exception:
        return b""


def _paste_with_retry(mime, timeout):
    data = b""
    for _ in range(PASTE_RETRY_ATTEMPTS):
        data = _paste_once(mime, timeout)
        if data:
            break
        time.sleep(PASTE_RETRY_DELAY)
    return data


def _list_types_with_retry():
    for _ in range(LIST_RETRY_ATTEMPTS):
        try:
            cp = subprocess.run(
                ["wl-paste", "--list-types"],
                capture_output=True,
                text=True,
                timeout=2.0,
            )
            if cp.returncode == 0:
                types = [line.strip() for line in cp.stdout.splitlines() if line.strip()]
                if types:
                    return types
        except Exception:
            pass
        time.sleep(PASTE_RETRY_DELAY)
    return []

def _capture_bytes(mime, timeout, initial_types):
    """Paste with retries, re-resolving offered types each round so an
    owner that flaps mid-capture is picked up instead of retried blindly."""
    types = initial_types
    for round_index in range(CAPTURE_ROUNDS):
        if round_index:
            types = _list_types_with_retry()
        if mime not in types:
            continue
        data = _paste_with_retry(mime, timeout)
        if data:
            return data, types
    return b"", types


def capture_clipboard():
    if not shutil.which("wl-paste"):
        return

    # 1. Query available offered types
    available_types = _list_types_with_retry()

    if not available_types:
        return

    # 2. Check for image types
    matched_image_mime = None
    for mime in IMAGE_MIMES:
        if mime in available_types:
            matched_image_mime = mime
            break

    if matched_image_mime:
        raw_bytes, available_types = _capture_bytes(matched_image_mime, IMAGE_PASTE_TIMEOUT, available_types)

        if not raw_bytes:
            return

        if len(raw_bytes) > MAX_BLOB_BYTES:
            print(f"quickshell-clipboard: ignoring image exceeding size limit ({len(raw_bytes)} bytes)", file=sys.stderr)
            return

        ext = IMAGE_EXTENSIONS.get(matched_image_mime, ".png")
        blob_path, content_hash = save_blob(raw_bytes, ext)
        label = matched_image_mime.split("/")[-1].upper().replace("+XML", "")

        record_item(
            item_type="image",
            primary_mime=matched_image_mime,
            mime_types_list=available_types,
            text_preview=f"Imagem {label}",
            full_text=f"[Imagem {label}]",
            line_count=1,
            char_count=0,
            blob_path=blob_path,
            content_hash=content_hash,
        )
        return

    # 3. Check for text types
    matched_text_mime = None
    for mime in TEXT_MIMES:
        if mime in available_types:
            matched_text_mime = mime
            break

    if matched_text_mime:
        raw_bytes, _ = _capture_bytes(matched_text_mime, TEXT_PASTE_TIMEOUT, available_types)

        if not raw_bytes:
            return

        if len(raw_bytes) > MAX_TEXT_BYTES:
            print(f"quickshell-clipboard: ignoring text exceeding size limit ({len(raw_bytes)} bytes)", file=sys.stderr)
            return

        text = raw_bytes.decode("utf-8", errors="replace")
        clean_text = text.replace("\r\n", "\n").replace("\r", "\n")
        if not clean_text.strip():
            return

        preview = " ".join(clean_text.split())
        if len(preview) > 80:
            preview = preview[:77] + "…"

        line_count = len(clean_text.splitlines()) or 1
        char_count = len(clean_text)
        content_hash = hashlib.sha256(clean_text.encode("utf-8")).hexdigest()

        record_item(
            item_type="text",
            primary_mime=matched_text_mime,
            mime_types_list=available_types,
            text_preview=preview,
            full_text=clean_text,
            line_count=line_count,
            char_count=char_count,
            blob_path=None,
            content_hash=content_hash,
        )

def run_daemon():
    if not shutil.which("wl-paste"):
        print("quickshell-clipboard: error: wl-paste is not available on PATH", file=sys.stderr)
        sys.exit(1)

    BASE_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = BASE_DIR / "daemon.lock"
    lock_file = open(lock_path, "w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (IOError, OSError):
        print("quickshell-clipboard: daemon already running", file=sys.stderr)
        sys.exit(0)

    init_db()

    # Capture initial clipboard state
    try:
        capture_clipboard()
    except Exception:
        pass

    running = True
    child = None

    def on_signal(signum, frame):
        nonlocal running
        running = False
        if child and child.poll() is None:
            child.terminate()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGHUP, on_signal)

    watch_cmd = [
        "wl-paste",
        "--watch",
        sys.executable,
        str(Path(__file__).resolve()),
        "--capture",
    ]

    while running:
        try:
            child = subprocess.Popen(watch_cmd)
            while running and child.poll() is None:
                try:
                    child.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    pass
        except Exception:
            if running:
                time.sleep(1.0)

        if not running:
            break
        time.sleep(1.0)

    if child and child.poll() is None:
        try:
            child.terminate()
            child.wait(timeout=2.0)
        except Exception:
            child.kill()


def drain_watch_stdin():
    # wl-paste --watch pipes the selection into each callback. The capture
    # below queries the offered MIME types itself, but its callback must still
    # consume this pipe: a screenshot can fill it and stall the watcher.
    while sys.stdin.buffer.read(65536):
        pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--capture":
        drain_watch_stdin()
        capture_clipboard()
    elif len(sys.argv) > 1 and sys.argv[1] == "--status":
        from clipboard_store import get_snapshot
        items = get_snapshot(5)
        print(json.dumps({"count": len(items), "recent": items}, ensure_ascii=False, indent=2))
    else:
        run_daemon()
