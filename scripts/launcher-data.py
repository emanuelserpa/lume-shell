#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

EMOJI_DB_FILE = Path(__file__).resolve().parent.parent / "data" / "emojis.json"

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
STATE_FILE = STATE_DIR / "launcher-usage.json"
EMOJI_USAGE_FILE = STATE_DIR / "launcher-emoji-usage.json"
# Unicode emoji that default to text presentation in the Misc Symbols/Dingbats
# blocks. Emoji sequences with VS16 and pictographs in the supplementary emoji
# blocks are recognized separately below.
EMOJI_PRESENTATION_RANGES = (
    (0x231A, 0x231B), (0x23E9, 0x23EC), (0x23F0, 0x23F0), (0x23F3, 0x23F3),
    (0x25FD, 0x25FE), (0x2614, 0x2615), (0x2648, 0x2653), (0x267F, 0x267F),
    (0x2693, 0x2693), (0x26A1, 0x26A1), (0x26AA, 0x26AB), (0x26BD, 0x26BE),
    (0x26C4, 0x26C5), (0x26CE, 0x26CE), (0x26D4, 0x26D4), (0x26EA, 0x26EA),
    (0x26F2, 0x26F3), (0x26F5, 0x26F5), (0x26FA, 0x26FA), (0x26FD, 0x26FD),
    (0x2705, 0x2705), (0x270A, 0x270B), (0x2728, 0x2728), (0x274C, 0x274C),
    (0x274E, 0x274E), (0x2753, 0x2755), (0x2757, 0x2757), (0x2795, 0x2797),
    (0x27B0, 0x27B0), (0x27BF, 0x27BF), (0x2B1B, 0x2B1C), (0x2B50, 0x2B50),
    (0x2B55, 0x2B55),
)
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell"
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
import clipboard_store


def out(obj):
    if isinstance(obj, dict):
        obj = dict(obj, version=1)
    print(json.dumps(obj, ensure_ascii=False))

def load_usage():
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}

def save_usage(data):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(STATE_FILE)

def usage():
    out({"usage": load_usage()})

def bump(name):
    name = str(name or "").strip()
    data = load_usage()
    if name:
        data[name] = int(data.get(name, 0)) + 1
        # Keep the file bounded.
        if len(data) > 250:
            data = dict(sorted(data.items(), key=lambda kv: kv[1], reverse=True)[:200])
        save_usage(data)
    out({"ok": True, "usage": data})

def load_emoji_usage():
    try:
        data = json.loads(EMOJI_USAGE_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}

def mark_emoji(value):
    char = str(value or "").strip()
    usage = load_emoji_usage()
    if char:
        try:
            previous = max(0, int(usage.get(char, 0)))
        except (TypeError, ValueError):
            previous = 0
        usage[char] = previous + 1
        if len(usage) > 1000:
            usage = dict(sorted(usage.items(), key=lambda item: item[1], reverse=True)[:800])
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = EMOJI_USAGE_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(usage, ensure_ascii=False), encoding="utf-8")
        tmp.replace(EMOJI_USAGE_FILE)
    out({"ok": True})

def files(query):
    q = str(query or "").strip()
    if not q:
        out({"items": []})
        return

    home = str(Path.home())
    items = []

    fd = shutil.which("fd")
    if fd:
        cmd = [
            fd, "--absolute-path", "--hidden",
            "--exclude", ".cache",
            "--exclude", ".git",
            "--exclude", "node_modules",
            "--max-results", "40",
            q, home
        ]
        try:
            cp = subprocess.run(cmd, capture_output=True, text=True, timeout=2.5)
            lines = cp.stdout.splitlines()
        except Exception:
            lines = []
    else:
        # Conservative fallback; only scan a few common top-level locations.
        roots = [Path.home() / n for n in ("Documents", "Downloads", "Pictures", "Videos", "Music")]
        lines = []
        needle = q.lower()
        for root in roots:
            if not root.exists():
                continue
            try:
                for p in root.rglob("*"):
                    if needle in p.name.lower():
                        lines.append(str(p))
                        if len(lines) >= 40:
                            break
            except Exception:
                pass
            if len(lines) >= 40:
                break

    seen = set()
    for raw in lines:
        path = Path(raw)
        s = str(path)
        if s in seen:
            continue
        seen.add(s)
        try:
            is_dir = path.is_dir()
        except Exception:
            is_dir = False

        parent = str(path.parent)
        try:
            parent = parent.replace(str(Path.home()), "~", 1)
        except Exception:
            pass

        items.append({
            "path": s,
            "name": path.name or s,
            "parent": parent,
            "is_dir": is_dir
        })
        if len(items) >= 20:
            break

    out({"items": items})


CLIPBOARD_INDEX_FILE = CACHE_DIR / "clipboard-index.json"

def _save_clipboard_index(payload):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = CLIPBOARD_INDEX_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        tmp.replace(CLIPBOARD_INDEX_FILE)
    except Exception:
        pass

def clipboard_cache():
    try:
        payload = json.loads(CLIPBOARD_INDEX_FILE.read_text(encoding="utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("invalid cache")
        payload["cached"] = True
        out(payload)
    except Exception:
        items = clipboard_store.get_snapshot(60)
        out({
            "available": True,
            "backend": "native",
            "cached": True,
            "items": items,
        })

def clipboard_snapshot(limit=60):
    if not shutil.which("wl-paste") or not shutil.which("wl-copy"):
        out({
            "available": False,
            "backend": "native",
            "error": "wl-clipboard não disponível",
            "items": [],
        })
        return

    limit = max(1, min(int(limit), 200))
    try:
        items = clipboard_store.get_snapshot(limit)
        payload = {
            "available": True,
            "backend": "native",
            "cached": False,
            "items": items,
        }
    except Exception as exc:
        payload = {
            "available": False,
            "backend": "native",
            "error": str(exc),
            "items": [],
        }

    _save_clipboard_index(payload)
    out(payload)

def clipboard_restore(item_id, signature=""):
    if not shutil.which("wl-copy"):
        out({"ok": False, "error": "wl-copy não disponível"})
        return
    if not str(item_id).strip():
        out({"ok": False, "error": "invalid item"})
        return
    ok, err = clipboard_store.restore_item(str(item_id).strip(), signature or None)
    out({"ok": ok, "error": err} if not ok else {"ok": True})

def clipboard_remove(item_id, signature=""):
    if not str(item_id).strip():
        out({"ok": False, "error": "invalid item"})
        return
    ok, err = clipboard_store.remove_item(str(item_id).strip(), signature or None)
    out({"ok": ok, "error": err} if not ok else {"ok": True})

def clipboard_open_image(item_id, signature=""):
    if not str(item_id).strip():
        out({"ok": False, "error": "invalid item"})
        return
    ok, err = clipboard_store.open_image(str(item_id).strip(), signature or None)
    out({"ok": ok, "error": err} if not ok else {"ok": True})

def clipboard_thumbnails(request_json):
    try:
        requests = json.loads(request_json or "[]")
    except Exception:
        requests = []

    if not isinstance(requests, list):
        requests = []

    thumb_list = clipboard_store.get_thumbnails(requests)
    thumbs = {str(t["id"]): t["thumbnail"] for t in thumb_list}
    out({
        "available": True,
        "backend": "native",
        "thumbnails": thumbs,
    })

def clipboard_capture_state():
    out({"ok": True, "paused": clipboard_store.clipboard_capture_paused()})

def clipboard_capture_set(value):
    value = str(value or "").strip().lower()
    if value not in ("pause", "resume"):
        out({"ok": False, "error": "Use pause ou resume."})
        return
    paused = value == "pause"
    if not clipboard_store.set_clipboard_capture_paused(paused):
        out({"ok": False, "error": "Não foi possível salvar a preferência de captura."})
        return
    out({"ok": True, "paused": paused})


def _rofimoji_data_dirs():
    dirs = []

    # User overrides/additional datasets supported by rofimoji.
    xdg = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    dirs.append(xdg / "rofimoji" / "data")

    # Current Arch package layout: the Python package is named "picker",
    # and bundled character files live in picker/data.
    try:
        import importlib.util

        for module_name in ("picker", "rofimoji"):
            spec = importlib.util.find_spec(module_name)
            if spec and spec.origin:
                pkg = Path(spec.origin).resolve().parent
                dirs.extend([
                    pkg / "data",
                    pkg / "picker" / "data",
                    pkg.parent / "picker" / "data",
                ])
    except Exception:
        pass

    # Version-agnostic Arch/Python fallbacks.
    for lib_root in (Path("/usr/lib"), Path("/usr/local/lib")):
        try:
            for py_dir in lib_root.glob("python3.*"):
                dirs.append(py_dir / "site-packages" / "picker" / "data")
                dirs.append(py_dir / "site-packages" / "rofimoji" / "data")
        except Exception:
            pass

    # Historical / custom install locations.
    dirs.extend([
        Path("/usr/share/rofimoji/data"),
        Path("/usr/local/share/rofimoji/data"),
    ])

    result = []
    seen = set()

    for d in dirs:
        try:
            key = str(d.resolve())
        except Exception:
            key = str(d)

        if key in seen:
            continue
        seen.add(key)

        if d.exists() and d.is_dir():
            result.append(d)

    return result

def _norm_emoji(text):
    if not text:
        return ""
    return "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    ).lower().strip()

def _is_emoji_char(value):
    char = str(value or "")
    points = [ord(codepoint) for codepoint in char]
    if not points:
        return False
    if 0x20E3 in points:  # Keycap sequences (e.g. 1️⃣).
        return True
    if any(0x1F000 <= point <= 0x1FAFF for point in points):
        return True
    if 0xFE0F in points:  # Explicit emoji presentation selector.
        return True
    return any(start <= point <= end
               for point in points
               for start, end in EMOJI_PRESENTATION_RANGES)

def emoji(query):
    q = _norm_emoji(query)
    usage = load_emoji_usage()

    def usage_bonus(char):
        # Give repeated personal use a clear but bounded influence over the
        # dataset's built-in popularity score.
        try:
            count = max(0, int(usage.get(char, 0)))
        except (TypeError, ValueError):
            count = 0
        return min(1000, count * 200)

    if not EMOJI_DB_FILE.exists():
        out({"available": False, "items": []})
        return

    try:
        data = json.loads(EMOJI_DB_FILE.read_text(encoding="utf-8"))
    except Exception:
        out({"available": False, "items": []})
        return

    # This catalog includes punctuation and standalone modifiers as well as
    # emoji. Keep non-emoji Unicode characters out of both the grid and search.
    data = [item for item in data if _is_emoji_char(item.get("char", ""))]

    if not q:
        sorted_popular = sorted(
            data,
            key=lambda item: (item.get("pop", 0) + usage_bonus(item.get("char", "")),
                              usage_bonus(item.get("char", "")), item.get("pop", 0)),
            reverse=True,
        )
        items = [
            {
                "char": x["char"],
                "name": x["name"],
                "description": x["name"]
            }
            for x in sorted_popular[:40]
        ]
        out({"available": True, "items": items})
        return

    tokens = q.split()
    scored = []
    for it in data:
        name = it.get("name", "")
        norm_name = _norm_emoji(name)
        keywords = it.get("keywords", [])
        pop = it.get("pop", 0)
        score = 0

        # Exact whole match
        if norm_name == q:
            score += 3000
        elif q in keywords:
            score += 2200
        elif norm_name.startswith(q):
            score += 1500
        elif any(k.startswith(q) for k in keywords):
            score += 1000

        # Multi-token matching (e.g. "heart hands", "mão coração", "gato rindo")
        if len(tokens) > 1:
            all_match = True
            token_score = 0
            for t in tokens:
                if t in norm_name:
                    token_score += 350
                elif any(t in k for k in keywords):
                    token_score += 300
                elif any(k.startswith(t) for k in keywords):
                    token_score += 250
                else:
                    all_match = False
                    break
            if all_match:
                score += 1200 + token_score
        else:
            # Single token partial
            if q in norm_name:
                score += 400
            elif any(q in k for k in keywords):
                score += 300

        if score > 0:
            personal_score = usage_bonus(it.get("char", ""))
            scored.append((score + pop + personal_score, score, personal_score, pop, it))

    scored.sort(key=lambda item: item[:4], reverse=True)
    items = [
        {
            "char": item[4]["char"],
            "name": item[4]["name"],
            "description": item[4]["name"]
        }
        for item in scored[:40]
    ]
    out({"available": True, "items": items})

def windows():
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower().split(":")
    if os.environ.get("LABWC_PID") or "hyprland" not in desktop:
        out({"available": False, "items": []})
        return
    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        out({"available": False, "items": []})
        return

    try:
        cp = subprocess.run(
            [hyprctl, "clients", "-j"],
            capture_output=True,
            text=True,
            timeout=2.0,
        )
        clients = json.loads(cp.stdout or "[]")
    except Exception:
        out({"available": True, "items": []})
        return

    items = []
    for c in clients:
        pid = c.get("pid")
        if not isinstance(pid, int) or pid <= 0:
            continue

        title = str(c.get("title") or "").strip()
        cls = str(c.get("class") or c.get("initialClass") or "").strip()
        address = str(c.get("address") or "").strip()
        ws_obj = c.get("workspace") or {}
        ws_id = ws_obj.get("id")
        ws_name = str(ws_obj.get("name") or "")

        items.append({
            "pid": pid,
            "title": title or cls or f"PID {pid}",
            "class": cls or "unknown",
            "address": address,
            "workspaceId": ws_id,
            "workspaceName": ws_name,
        })

    out({"available": True, "items": items})

def main():
    if len(sys.argv) < 2:
        out({"error": "missing action"})
        return 1

    action = sys.argv[1]
    if action == "usage":
        usage()
    elif action == "bump":
        bump(sys.argv[2] if len(sys.argv) > 2 else "")
    elif action == "emoji-mark":
        mark_emoji(sys.argv[2] if len(sys.argv) > 2 else "")
    elif action == "files":
        files(sys.argv[2] if len(sys.argv) > 2 else "")
    elif action == "clipboard-cache":
        clipboard_cache()
    elif action == "clipboard-snapshot":
        try:
            limit = int(sys.argv[2]) if len(sys.argv) > 2 else 200
        except Exception:
            limit = 200
        clipboard_snapshot(max(1, min(limit, 200)))
    elif action == "clipboard-capture-state":
        clipboard_capture_state()
    elif action == "clipboard-capture":
        clipboard_capture_set(sys.argv[2] if len(sys.argv) > 2 else "")
    elif action == "clipboard-restore":
        clipboard_restore(sys.argv[2] if len(sys.argv) > 2 else "",
                          sys.argv[3] if len(sys.argv) > 3 else "")
    elif action == "clipboard-remove":
        clipboard_remove(sys.argv[2] if len(sys.argv) > 2 else "",
                         sys.argv[3] if len(sys.argv) > 3 else "")
    elif action == "clipboard-open-image":
        clipboard_open_image(sys.argv[2] if len(sys.argv) > 2 else "",
                             sys.argv[3] if len(sys.argv) > 3 else "")
    elif action == "clipboard-thumbnails":
        clipboard_thumbnails(sys.argv[2] if len(sys.argv) > 2 else "[]")
    elif action == "emoji":
        emoji(sys.argv[2] if len(sys.argv) > 2 else "")
    elif action == "windows":
        windows()
    else:
        out({"error": "unknown action"})
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
