#!/usr/bin/env python3
"""
Optional one-shot importer from CopyQ to Quickshell native clipboard.
Reads up to 200 items from CopyQ without modifying CopyQ history.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import clipboard_store

def _copyq_cmd():
    native = shutil.which("copyq")
    if native:
        return [native]
    flatpak = shutil.which("flatpak")
    if flatpak:
        try:
            cp = subprocess.run([flatpak, "info", "com.github.hluk.copyq"], capture_output=True, timeout=2.0)
            if cp.returncode == 0:
                return [flatpak, "run", "--command=copyq", "com.github.hluk.copyq"]
        except Exception:
            pass
    return None

def import_copyq(limit=200):
    cmd = _copyq_cmd()
    if not cmd:
        print("CopyQ not found (neither native nor flatpak). Nothing to import.")
        return 0

    # Get clipboard tab
    try:
        cp = subprocess.run(cmd + ["config", "clipboard_tab"], capture_output=True, text=True, timeout=2.0)
        tab = (cp.stdout or "").strip() or "&clipboard"
    except Exception:
        tab = "&clipboard"

    script = """
tab(%s);
var maxItems = Math.min(size(), %d);
var imageMimes = ["image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/svg+xml"];
var result = [];

for (var i = 0; i < maxItems; ++i) {
    var formatsText = str(read("?", i));
    var formats = formatsText.split("\\n");
    var textMime = "";
    if (formats.indexOf("text/plain;charset=utf-8") >= 0) {
        textMime = "text/plain;charset=utf-8";
    } else if (formats.indexOf("UTF8_STRING") >= 0) {
        textMime = "UTF8_STRING";
    } else {
        textMime = mimeText;
    }
    var rawText = str(read(textMime, i));
    if ((!rawText || rawText.length === 0) && textMime !== mimeText) {
        rawText = str(read(mimeText, i));
    }
    var preview = rawText
        .replace(/\\u0000/g, "")
        .replace(/[\\r\\n]+/g, " ")
        .replace(/\\s+/g, " ")
        .trim();

    if (preview.length > 0) {
        var cleanRaw = rawText.replace(/\\u0000/g, "").trim();
        result.push({
            type: "text",
            mime: "text/plain",
            preview: preview.length > 80 ? preview.slice(0, 77) + "…" : preview,
            fullText: cleanRaw,
            index: i
        });
        continue;
    }

    var imageMime = "";
    for (var j = 0; j < imageMimes.length; ++j) {
        if (formats.indexOf(imageMimes[j]) >= 0) {
            imageMime = imageMimes[j];
            break;
        }
    }

    if (imageMime.length > 0) {
        result.push({
            type: "image",
            mime: imageMime,
            preview: "Imagem " + imageMime.split("/")[1].toUpperCase().replace("+XML", ""),
            index: i
        });
    }
}
print(JSON.stringify(result));
""" % (json.dumps(tab, ensure_ascii=False), int(limit))

    try:
        cp = subprocess.run(cmd + ["eval", "--", script], capture_output=True, text=True, timeout=10.0)
        if cp.returncode != 0:
            print("Failed to query CopyQ:", cp.stderr, file=sys.stderr)
            return 0
        items = json.loads(cp.stdout)
    except Exception as e:
        print("Error reading CopyQ items:", e, file=sys.stderr)
        return 0

    if not isinstance(items, list) or not items:
        print("No items found in CopyQ to import.")
        return 0

    imported = 0
    clipboard_store.init_db()

    # Process items in reverse order so newer items have higher timestamps
    for it in reversed(items):
        item_type = it.get("type")
        mime = it.get("mime")
        idx = it.get("index")

        if item_type == "text":
            full_text = it.get("fullText", "")
            preview = it.get("preview", "")
            if not full_text.strip():
                continue
            line_count = len(full_text.splitlines()) or 1
            char_count = len(full_text)
            content_hash = hashlib.sha256(full_text.encode("utf-8")).hexdigest()

            _, created = clipboard_store.record_item(
                item_type="text",
                primary_mime=mime or "text/plain",
                mime_types_list=[mime or "text/plain"],
                text_preview=preview,
                full_text=full_text,
                line_count=line_count,
                char_count=char_count,
                blob_path=None,
                content_hash=content_hash,
            )
            if created:
                imported += 1

        elif item_type == "image":
            # Fetch raw image bytes from CopyQ
            try:
                cp = subprocess.run(cmd + ["tab", tab, "read", mime, str(idx)], capture_output=True, timeout=3.0)
                raw_bytes = cp.stdout
            except Exception:
                raw_bytes = None

            if not raw_bytes:
                continue

            ext = clipboard_store.IMAGE_EXTENSIONS.get(mime, ".png")
            blob_path, content_hash = clipboard_store.save_blob(raw_bytes, ext)
            label = mime.split("/")[-1].upper().replace("+XML", "")

            _, created = clipboard_store.record_item(
                item_type="image",
                primary_mime=mime,
                mime_types_list=[mime],
                text_preview=f"Imagem {label}",
                full_text=f"[Imagem {label}]",
                line_count=1,
                char_count=0,
                blob_path=blob_path,
                content_hash=content_hash,
            )
            if created:
                imported += 1

    print(f"Successfully imported {imported} items from CopyQ to Quickshell clipboard database.")
    return imported

if __name__ == "__main__":
    limit = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 200
    import_copyq(limit)
