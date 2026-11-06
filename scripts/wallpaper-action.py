#!/usr/bin/env python3
"""
Wallpaper Action Helper for Quickshell Desktop Shell.
Handles picking, randomizing, and applying wallpapers using awww/swww
and updating the dynamic Chameleon theme.
Output envelope adheres strictly to {"ok": bool, "action": str, "error": str | None, ...}.
"""

import json
import configparser
import hashlib
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
CURRENT_WALLPAPER = CACHE_DIR / "current_wallpaper"
SHELL_DIR = Path(__file__).resolve().parent.parent
THEME_MANAGER = SHELL_DIR / "scripts" / "theme-manager.py"
WALLPAPER_STATE = STATE_DIR / "wallpaper.json"
PREVIEW_DIR = CACHE_DIR / "quickshell" / "wallpaper-previews"
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
WAYPAPER_CONFIG = CONFIG_HOME / "waypaper" / "config.ini"

VALID_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".jxl", ".bmp"}


def result(ok: bool, action: str, error: str | None = None, **kwargs):
    payload = {
        "ok": bool(ok),
        "version": 1,
        "action": action,
        "error": error or None,
    }
    payload.update(kwargs)
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if ok else 1


def detect_current_wallpaper_path() -> str | None:
    if shutil.which("awww"):
        try:
            res = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    if "image:" in line:
                        p = line.split("image:")[-1].strip()
                        if Path(p).is_file():
                            return p
        except Exception:
            pass

    if shutil.which("swww"):
        try:
            res = subprocess.run(["swww", "query"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    if "image:" in line:
                        p = line.split("image:")[-1].strip()
                        if Path(p).is_file():
                            return p
        except Exception:
            pass

    if CURRENT_WALLPAPER.is_file():
        try:
            saved = json.loads(WALLPAPER_STATE.read_text()).get("wallpaper")
            if saved and Path(saved).is_file():
                return saved
        except (OSError, ValueError, TypeError):
            pass
        legacy = configparser.ConfigParser()
        legacy.read(WAYPAPER_CONFIG)
        old = Path(legacy.get("Settings", "wallpaper", fallback="")).expanduser()
        if old.is_file():
            return str(old)
        return str(CURRENT_WALLPAPER)

    return None


def apply_wallpaper(image_path: Path | str) -> tuple[bool, str | None]:
    p = Path(image_path).resolve()
    if not p.is_file():
        return False, f"Arquivo não encontrado: {p}"

    # 1. Apply to wallpaper daemon
    applied_daemon = False
    if shutil.which("awww"):
        try:
            res = subprocess.run(["awww", "img", str(p)], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                applied_daemon = True
        except Exception:
            pass

    if not applied_daemon and shutil.which("swww"):
        try:
            res = subprocess.run(["swww", "img", str(p)], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                applied_daemon = True
        except Exception:
            pass

    if not applied_daemon:
        return False, "Não foi possível aplicar o wallpaper via awww ou swww"

    # 2. Update cache file and persistent selection
    try:
        CURRENT_WALLPAPER.parent.mkdir(parents=True, exist_ok=True)
        if p != CURRENT_WALLPAPER:
            shutil.copy2(p, CURRENT_WALLPAPER)
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        saved = json.loads(WALLPAPER_STATE.read_text()) if WALLPAPER_STATE.exists() else {}
        folder = Path(saved.get("folder", "")).expanduser()
        WALLPAPER_STATE.write_text(json.dumps({
            "wallpaper": str(p),
            "folder": str(folder if folder.is_dir() else p.parent),
        }))
    except Exception as e:
        return False, f"Falha ao atualizar cache do wallpaper: {e}"

    # 3. Trigger theme-manager update
    if THEME_MANAGER.is_file():
        try:
            subprocess.run([sys.executable, "-B", str(THEME_MANAGER), "update-wallpaper", str(p)],
                           capture_output=True, text=True, timeout=10)
        except Exception as e:
            return False, f"Falha ao atualizar tema Chameleon: {e}"

    return True, None


def cmd_get():
    wp = detect_current_wallpaper_path()
    if wp and Path(wp).is_file():
        p = Path(wp)
        return result(True, "get", wallpaper=str(p), filename=p.name)
    return result(False, "get", error="Nenhum wallpaper ativo detectado")


def cmd_pick():
    chosen = None
    if shutil.which("zenity"):
        try:
            cmd = [
                "zenity",
                "--file-selection",
                "--title=Selecione um Papel de Parede",
                '--file-filter=Imagens (*.png, *.jpg, *.jpeg, *.webp) | *.png *.jpg *.jpeg *.webp *.avif',
            ]
            current = detect_current_wallpaper_path()
            if current and Path(current).parent.is_dir():
                cmd.append(f"--filename={Path(current).parent}/")
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if res.returncode == 0 and res.stdout.strip():
                chosen = res.stdout.strip()
        except Exception as e:
            return result(False, "pick", f"Erro ao abrir seletor zenity: {e}")
    elif shutil.which("kdialog"):
        try:
            res = subprocess.run(["kdialog", "--getopenfilename", str(Path.home()), "*.png *.jpg *.jpeg *.webp"],
                                 capture_output=True, text=True, timeout=60)
            if res.returncode == 0 and res.stdout.strip():
                chosen = res.stdout.strip()
        except Exception as e:
            return result(False, "pick", f"Erro ao abrir seletor kdialog: {e}")
    else:
        return result(False, "pick", "Nenhum seletor de arquivos gráfico (zenity/kdialog) encontrado")

    if not chosen:
        return result(False, "pick", "Seleção cancelada pelo usuário")

    ok, err = apply_wallpaper(chosen)
    if ok:
        p = Path(chosen)
        return result(True, "pick", wallpaper=str(p), filename=p.name)
    return result(False, "pick", err)


def cmd_random():
    current = detect_current_wallpaper_path()
    candidates = collect_candidates(current, exclude_current=True, limit=None)

    if not candidates:
        return result(False, "random", "Nenhuma imagem encontrada nos diretórios de papel de parede")

    selected = random.choice(candidates)
    ok, err = apply_wallpaper(selected)
    if ok:
        return result(True, "random", wallpaper=str(selected), filename=selected.name)
    return result(False, "random", err)


def cmd_folder():
    if not shutil.which("zenity"):
        return result(False, "folder", "zenity não encontrado")
    res = subprocess.run(["zenity", "--file-selection", "--directory",
                          "--title=Selecionar pasta de wallpapers"],
                         capture_output=True, text=True)
    folder = Path(res.stdout.strip()).expanduser().resolve() if res.returncode == 0 else None
    if not folder or not folder.is_dir():
        return result(False, "folder", "Seleção cancelada")
    try:
        saved = json.loads(WALLPAPER_STATE.read_text()) if WALLPAPER_STATE.exists() else {}
        saved["folder"] = str(folder)
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        WALLPAPER_STATE.write_text(json.dumps(saved))
    except (OSError, ValueError) as e:
        return result(False, "folder", str(e))
    return result(True, "folder", folder=str(folder))


def cmd_restore():
    path = None
    try:
        path = json.loads(WALLPAPER_STATE.read_text()).get("wallpaper")
    except (OSError, ValueError, TypeError):
        pass
    if not path:
        legacy = configparser.ConfigParser()
        legacy.read(WAYPAPER_CONFIG)
        path = legacy.get("Settings", "wallpaper", fallback="")
    if not path and CURRENT_WALLPAPER.is_file():
        path = str(CURRENT_WALLPAPER)
    if not path:
        return result(False, "restore", "Nenhum wallpaper salvo")
    for attempt in range(5):
        ok, err = apply_wallpaper(Path(path).expanduser())
        if ok or attempt == 4:
            break
        time.sleep(0.5)
    return result(ok, "restore", err, wallpaper=str(Path(path).expanduser()) if ok else None)


def collect_candidates(current=None, exclude_current=False, limit=24):
    search_dirs = []
    try:
        saved = json.loads(WALLPAPER_STATE.read_text())
        folder = Path(saved.get("folder", "")).expanduser()
        if folder.is_dir():
            search_dirs.append(folder)
    except (OSError, ValueError, TypeError):
        pass
    if not search_dirs:
        legacy = configparser.ConfigParser()
        legacy.read(WAYPAPER_CONFIG)
        legacy_folder = Path(legacy.get("Settings", "folder", fallback="")).expanduser()
        if legacy_folder.is_dir():
            search_dirs.append(legacy_folder)
    if current and Path(current).parent.is_dir():
        parent = Path(current).parent
        if parent not in search_dirs and current != str(CURRENT_WALLPAPER):
            search_dirs.append(parent)

    user_pics = Path.home() / "Pictures" / "Wallpapers"
    if user_pics.is_dir() and user_pics not in search_dirs:
        search_dirs.append(user_pics)

    candidates = []
    seen = set()
    for d in search_dirs:
        for root, _, files in os.walk(d):
            for f in sorted(files):
                ext = Path(f).suffix.lower()
                if ext not in VALID_EXTENSIONS:
                    continue
                full = Path(root) / f
                if full in seen:
                    continue
                seen.add(full)
                if exclude_current and current and str(full) == current:
                    continue
                candidates.append(full)
                if limit is not None and len(candidates) >= limit:
                    return candidates
    return candidates


def cmd_list():
    current = detect_current_wallpaper_path()
    candidates = collect_candidates(current, exclude_current=False, limit=None)
    items = [{
        "path": str(p),
        "filename": p.name,
        "current": bool(current and str(p) == current),
    } for p in candidates]
    return result(True, "list", items=items, count=len(items))


def create_preview(image_path: Path | str) -> Path:
    """Return a cached JPEG preview for formats Qt Quick may not decode."""
    path = Path(image_path).expanduser().resolve()
    stat = path.stat()
    key = hashlib.sha256(
        f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode("utf-8")
    ).hexdigest()[:24]
    preview = PREVIEW_DIR / f"{key}.jpg"
    if preview.is_file():
        return preview

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    if path.suffix.lower() == ".jxl":
        converter = shutil.which("magick")
        if not converter:
            raise RuntimeError("ImageMagick (`magick`) com suporte a JPEG-XL não está instalado")
        subprocess.run([
            converter, str(path), "-thumbnail", "1000x600", "-background", "white",
            "-alpha", "remove", "-alpha", "off", "-quality", "86", str(preview),
        ], check=True, capture_output=True, text=True, timeout=30)
    else:
        from PIL import Image

        with Image.open(path) as source:
            image = source.convert("RGB")
            image.thumbnail((1000, 600), Image.Resampling.LANCZOS)
            image.save(preview, format="JPEG", quality=86)
    return preview


def cmd_preview(target: str):
    try:
        preview = create_preview(target)
    except (OSError, ValueError, ImportError, RuntimeError, subprocess.SubprocessError) as error:
        return result(False, "preview", f"Não foi possível gerar a prévia: {error}")
    return result(True, "preview", preview=str(preview))


def cmd_apply(target: str):
    p = Path(target).expanduser().resolve()
    ok, err = apply_wallpaper(p)
    if ok:
        return result(True, "apply", wallpaper=str(p), filename=p.name)
    return result(False, "apply", err)


def main():
    if len(sys.argv) < 2:
        return cmd_get()

    action = sys.argv[1].lower()
    if action == "get":
        return cmd_get()
    elif action == "pick":
        return cmd_pick()
    elif action == "random":
        return cmd_random()
    elif action == "folder":
        return cmd_folder()
    elif action == "restore":
        return cmd_restore()
    elif action == "list":
        return cmd_list()
    elif action == "preview":
        if len(sys.argv) < 3:
            return result(False, "preview", "Caminho do arquivo não fornecido")
        return cmd_preview(sys.argv[2])
    elif action == "apply":
        if len(sys.argv) < 3:
            return result(False, "apply", "Caminho do arquivo não fornecido")
        return cmd_apply(sys.argv[2])
    else:
        return result(False, action, f"Ação desconhecida: {action}")


if __name__ == "__main__":
    sys.exit(main())
