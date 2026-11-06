#!/usr/bin/env python3
"""
Theme Manager for Quickshell Desktop Shell.
Manages theme definitions and persistence in ~/.local/state/quickshell/theme.json.
Output envelope adheres strictly to {"ok": bool, "error": str | None, ...}.
"""

import argparse
import colorsys
import configparser
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from theme_colors import (
    brighten_hex,
    darken_hex,
    desaturate_hex,
    generate_harmonized_semantics,
    hex_to_rgb,
    hsl_to_hex,
    linear_to_srgb,
    oklch_to_rgb,
    rgb_to_hex,
    rgb_to_oklch,
    srgb_to_linear,
)
from theme_catalog import DEFAULT_THEME, GHOSTTY_THEME_MAP, THEMES

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
STATE_FILE = STATE_DIR / "theme.json"
CHAMELEON_PALETTE_FILE = STATE_DIR / "chameleon-palette.json"
WALLPAPER_COLOR_PREFS_FILE = STATE_DIR / "wallpaper-color-preferences.json"
CANONICAL_PALETTE_FILE = STATE_DIR / "current_palette.json"
ADAPTERS_FILE = STATE_DIR / "adapters.json"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
DEFAULT_WALLPAPER_PATH = CACHE_DIR / "current_wallpaper"
HYPR_CACHE_DIR = CACHE_DIR / "hypr"
HYPR_THEME_LUA = HYPR_CACHE_DIR / "theme.lua"
HYPRLOCK_COLORS_CONF = HYPR_CACHE_DIR / "hyprlock_colors.conf"
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
KVANTUM_DIR = CONFIG_DIR / "Kvantum"

def is_hyprland_session() -> bool:
    return (not os.environ.get("LABWC_PID")
            and "hyprland" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower().split(":"))


def is_mango_session() -> bool:
    desktops = os.environ.get("XDG_CURRENT_DESKTOP", "").lower().split(":")
    return "mango" in desktops or bool(os.environ.get("MANGO_INSTANCE_SIGNATURE"))

GHOSTTY_CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "ghostty" / "config"
GHOSTTY_THEMES_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "ghostty" / "themes"
KITTY_CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "kitty" / "kitty.conf"
KITTY_THEME_FILE = STATE_DIR / "kitty-theme.conf"
KITTY_RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
FASTFETCH_CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "fastfetch" / "config.jsonc"
MANGO_CONFIG_PATH = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "mango" / "config.conf"
GTK_THEMES_DIR = Path.home() / ".themes"



def get_chameleon_fallback(variant: str = "chameleon"):
    target = variant if variant in ("chameleon", "chameleon-light", "chameleon-oled") else "chameleon"
    source = "#6750a4"
    light = target == "chameleon-light"
    roles = material_tonal_spot_roles(source, is_dark=not light)
    semantics = generate_harmonized_semantics(280.0, 0.9 if light else 1.1)
    return material_chameleon_variant(target, source, roles, "", 0, 0.85, semantics)


def detect_current_wallpaper() -> str | None:
    """
    Detecta o wallpaper ativo no sistema.
    1. Consulta o daemon awww se estiver rodando
    2. Consulta o daemon swww se estiver rodando
    3. Consulta hyprpaper se estiver rodando
    4. Usa ~/.cache/current_wallpaper
    """
    import shutil
    import subprocess

    # 1. awww query
    if shutil.which("awww"):
        try:
            res = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                m = re.search(r"currently displaying:\s*image:\s*(.+)$", res.stdout.strip(), re.MULTILINE)
                if m:
                    p = Path(m.group(1).strip())
                    if p.is_file():
                        return str(p)
        except Exception:
            pass

    # 2. swww query
    if shutil.which("swww"):
        try:
            res = subprocess.run(["swww", "query"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                m = re.search(r"image:\s*(.+)$", res.stdout.strip(), re.MULTILINE)
                if m:
                    p = Path(m.group(1).strip())
                    if p.is_file():
                        return str(p)
        except Exception:
            pass

    # 3. hyprpaper
    if is_hyprland_session() and shutil.which("hyprctl"):
        try:
            res = subprocess.run(["hyprctl", "hyprpaper", "listactive"], capture_output=True, text=True, timeout=1)
            if res.returncode == 0:
                m = re.search(r"=\s*(.+)$", res.stdout.strip(), re.MULTILINE)
                if m:
                    p = Path(m.group(1).strip())
                    if p.is_file():
                        return str(p)
        except Exception:
            pass

    # 4. ~/.cache/current_wallpaper
    if DEFAULT_WALLPAPER_PATH.is_file():
        return str(DEFAULT_WALLPAPER_PATH)

    return None


def compute_top_luminance(im) -> float:
    """
    Calcula a luminância perceptual média da faixa superior (15%) do wallpaper,
    onde a barra do Quickshell se posiciona.
    """
    try:
        top_strip = im.crop((0, 0, im.width, max(1, int(im.height * 0.15))))
        thumb = top_strip.resize((60, 60))
        colors = thumb.getcolors(3600) or []
        if not colors:
            return 0.5
        total_lum = sum((0.2126 * r + 0.7152 * g + 0.0722 * b) * count for count, (r, g, b) in colors)
        total_count = sum(count for count, _ in colors)
        return total_lum / (total_count * 255.0)
    except Exception:
        return 0.5


def material_tonal_spot_roles(source_hex: str, is_dark: bool = True) -> dict:
    """Material Color Utilities Tonal Spot, 2021 specification."""
    vendor_dir = str(Path(__file__).with_name("vendor"))
    if vendor_dir not in sys.path:
        sys.path.insert(0, vendor_dir)
    from materialyoucolor.hct import Hct
    from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot
    from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors

    scheme = SchemeTonalSpot(Hct.from_int(int("ff" + source_hex[1:], 16)), is_dark, 0.0, spec_version="2021")
    colors = MaterialDynamicColors(spec="2021")
    roles = (
        "background", "surface", "surfaceContainerLowest", "surfaceContainerLow",
        "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest",
        "surfaceVariant", "onSurface", "onSurfaceVariant", "outline", "outlineVariant",
        "primary", "onPrimary", "primaryContainer", "onPrimaryContainer",
        "secondary", "secondaryContainer", "onSecondaryContainer", "tertiary",
        "error", "errorContainer", "onErrorContainer",
    )
    return {role: getattr(colors, role).get_hex(scheme)[:7].lower() for role in roles}


def material_chameleon_variant(variant_id, source_hex, roles, wallpaper, wallpaper_mtime,
                               alpha, semantics):
    is_light = variant_id == "chameleon-light"
    is_oled = variant_id == "chameleon-oled"
    names = {"chameleon": "Chameleon", "chameleon-light": "Chameleon Light",
             "chameleon-oled": "Chameleon OLED"}
    colors = {
        "backgroundAlpha": 0.96 if is_oled else (0.94 if is_light else alpha),
        "backgroundOpaque": "#000000" if is_oled else roles["background"],
        "surface": "#000000" if is_oled else roles["surface"],
        "surfaceContainerLowest": "#000000" if is_oled else roles["surfaceContainerLowest"],
        "surfaceContainerLow": "#000000" if is_oled else roles["surfaceContainerLow"],
        "surfaceContainer": roles["surfaceContainer"],
        "surfaceElevated": roles["surfaceContainer"],
        "surfaceHover": roles["surfaceContainerHigh"],
        "surfaceContainerHigh": roles["surfaceContainerHigh"],
        "surfaceContainerHighest": roles["surfaceContainerHighest"],
        "surfaceSelected": roles["primaryContainer"],
        "surfaceVariant": roles["surfaceVariant"],
        "border": roles["outline"],
        "borderSubtle": roles["outlineVariant"],
        "outline": roles["outline"],
        "outlineVariant": roles["outlineVariant"],
        "foreground": roles["onSurface"],
        "offWhite": roles["onSurfaceVariant"],
        "grey": roles["outline"],
        "textMuted": roles["onSurfaceVariant"],
        "textDisabled": roles["outline"],
        "accent": roles["primary"],
        "accentMuted": roles["primaryContainer"],
        "primary": roles["primary"],
        "onPrimary": roles["onPrimary"],
        "primaryContainer": roles["primaryContainer"],
        "onPrimaryContainer": roles["onPrimaryContainer"],
        "secondary": roles["secondary"],
        "secondaryContainer": roles["secondaryContainer"],
        "onSecondaryContainer": roles["onSecondaryContainer"],
        "tertiary": roles["tertiary"],
        "error": roles["error"],
        "errorContainer": roles["errorContainer"],
        "onErrorContainer": roles["onErrorContainer"],
        "onSurface": roles["onSurface"],
        "onSurfaceVariant": roles["onSurfaceVariant"],
        **semantics,
    }
    return {
        "id": variant_id, "name": names[variant_id],
        "category": "light" if is_light else "dark",
        "description": "Material Tonal Spot do papel de parede" + (" com fundo preto" if is_oled else ""),
        "wallpaper": str(wallpaper), "wallpaper_mtime": wallpaper_mtime,
        "sourceColor": source_hex, "accent": roles["primary"], "colors": colors,
    }


def _wallpaper_candidates(path):
    from PIL import Image
    img = Image.open(path).convert("RGB")
    thumb = img.resize((160, 160))
    quantized = thumb.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    palette_raw = quantized.getpalette()[:48 * 3]
    colors_freq = quantized.getcolors(160 * 160) or []
    ranked = []
    for count, idx in colors_freq:
        rgb = tuple(palette_raw[idx * 3:idx * 3 + 3])
        L, C, h = rgb_to_oklch(*rgb)
        if C >= 0.02 and 0.10 <= L <= 0.90:
            score = C * 3.0 + (1.0 - abs(L - 0.65) * 1.5) + math.log1p(count) * 0.15
            ranked.append((score, L, C, h, count, rgb))
    ranked.sort(key=lambda item: item[0], reverse=True)
    selected = []
    for item in ranked:
        L, C, h = item[1:4]
        rgb = item[5]
        # A perceptual separation threshold prevents near-duplicate swatches.
        if all(math.sqrt((L - other[0]) ** 2 + (C - other[1]) ** 2 +
                         (min(abs(h - other[2]), 360 - abs(h - other[2])) / 180 * 0.25) ** 2) >= 0.12
               for other in selected):
            selected.append((L, C, h, rgb))
            if len(selected) == 5:
                break
    return ["#{:02x}{:02x}{:02x}".format(*item[3]) for item in selected], img


def _wallpaper_identity(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _wallpaper_color_preference(path):
    try:
        prefs = json.loads(WALLPAPER_COLOR_PREFS_FILE.read_text(encoding="utf-8"))
        return prefs.get(_wallpaper_identity(path))
    except Exception:
        return None


def _save_wallpaper_color_preference(path, color):
    try:
        prefs = json.loads(WALLPAPER_COLOR_PREFS_FILE.read_text(encoding="utf-8"))
    except Exception:
        prefs = {}
    prefs[_wallpaper_identity(path)] = color
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = WALLPAPER_COLOR_PREFS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(prefs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(WALLPAPER_COLOR_PREFS_FILE)


def extract_chameleon_palette(wallpaper_path=None, target_variant="chameleon", source_color=None, persist=True):
    """
    Escolhe uma cor do wallpaper e gera três esquemas Material Tonal Spot:
    normal, claro e OLED. Salva os tokens em
    ~/.local/state/quickshell/chameleon-palette.json.
    """
    target = str(target_variant or "chameleon").strip().lower()
    detected = wallpaper_path or detect_current_wallpaper()
    path = Path(detected) if detected else DEFAULT_WALLPAPER_PATH
    if not path.is_file():
        if CHAMELEON_PALETTE_FILE.is_file():
            try:
                cached = json.loads(CHAMELEON_PALETTE_FILE.read_text(encoding="utf-8"))
                if target in cached.get("variants", {}):
                    return cached["variants"][target]
                return cached
            except Exception:
                pass
        return get_chameleon_fallback(target)

    try:
        from PIL import Image

        img = Image.open(path).convert("RGB")
        top_lum = compute_top_luminance(img)

        # Transparência dinâmica adaptada à luminosidade de fundo
        if top_lum >= 0.65:
            bg_alpha = 0.90
        elif top_lum >= 0.45:
            bg_alpha = 0.86
        elif top_lum >= 0.25:
            bg_alpha = 0.82
        else:
            bg_alpha = 0.78

        thumb = img.resize((160, 160))
        quantized = thumb.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
        palette_raw = quantized.getpalette()[:48 * 3]
        colors_freq = quantized.getcolors(160 * 160) or []

        chromatic_candidates = []
        for count, idx in colors_freq:
            r, g, b = palette_raw[idx * 3], palette_raw[idx * 3 + 1], palette_raw[idx * 3 + 2]
            L, C, h = rgb_to_oklch(r, g, b)
            # Ignora quase-brancos, pretos absolutos e tons desprovidos de croma
            if C >= 0.02 and 0.10 <= L <= 0.90:
                score = C * 3.0 + (1.0 - abs(L - 0.65) * 1.5) + math.log1p(count) * 0.15
                chromatic_candidates.append((score, L, C, h, count, (r, g, b)))

        chromatic_candidates.sort(key=lambda x: x[0], reverse=True)
        if chromatic_candidates:
            best = chromatic_candidates[0]
            dom_h = best[3]
        else:
            dom_h = 220.0  # Fallback: azul ardósia

        sem_tonal = generate_harmonized_semantics(dom_h, 1.1)
        sem_light = generate_harmonized_semantics(dom_h, 0.9)
        selected_color = source_color or _wallpaper_color_preference(path)
        source_hex = selected_color.lower() if selected_color else (
            "#{:02x}{:02x}{:02x}".format(*(chromatic_candidates[0][5] if chromatic_candidates else (90, 130, 170))))
        material_roles = material_tonal_spot_roles(source_hex)
        material_roles_light = material_tonal_spot_roles(source_hex, is_dark=False)
        wp_stat = path.stat()

        variants_map = {
            "chameleon": material_chameleon_variant(
                "chameleon", source_hex, material_roles, path, wp_stat.st_mtime,
                bg_alpha, sem_tonal),
            "chameleon-light": material_chameleon_variant(
                "chameleon-light", source_hex, material_roles_light, path,
                wp_stat.st_mtime, 0.94, sem_light),
            "chameleon-oled": material_chameleon_variant(
                "chameleon-oled", source_hex, material_roles, path,
                wp_stat.st_mtime, 0.96, sem_tonal),
        }

        palette_payload = {
            "wallpaper": str(path),
            "wallpaper_mtime": wp_stat.st_mtime,
            "algorithm": "material-tonal-spot-2021-v2",
            "top_luminance": top_lum,
            "dominant_hue": dom_h,
            "variants": variants_map,
            **variants_map["chameleon"],
        }

        # Also copy to DEFAULT_WALLPAPER_PATH if different so cache stays updated
        if persist and path != DEFAULT_WALLPAPER_PATH:
            try:
                import shutil
                shutil.copy2(path, DEFAULT_WALLPAPER_PATH)
            except Exception:
                pass

        if persist:
            STATE_DIR.mkdir(parents=True, exist_ok=True)
            temp_file = CHAMELEON_PALETTE_FILE.with_suffix(".tmp")
            temp_file.write_text(json.dumps(palette_payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
            temp_file.replace(CHAMELEON_PALETTE_FILE)

        curr = read_current_theme_id()
        if persist and curr.startswith("chameleon"):
            active_var = variants_map.get(curr, variants_map["chameleon"])
            try:
                generate_ghostty_chameleon_theme(active_var)
                sync_ghostty_theme(curr, palette=active_var)
            except Exception:
                pass
            sync_kitty_theme(curr, palette=active_var)

        return variants_map.get(target, variants_map["chameleon"])
    except Exception:
        return get_chameleon_fallback(target)


def get_chameleon_palette(variant_id: str = "chameleon"):
    v = str(variant_id or "chameleon").strip().lower()
    active_wp = detect_current_wallpaper()
    if active_wp and Path(active_wp).is_file():
        wp_path = Path(active_wp)
        if CHAMELEON_PALETTE_FILE.is_file():
            try:
                cached = json.loads(CHAMELEON_PALETTE_FILE.read_text(encoding="utf-8"))
                if (cached.get("algorithm") == "material-tonal-spot-2021-v2" and
                    cached.get("wallpaper") == str(wp_path) and
                    cached.get("wallpaper_mtime") == wp_path.stat().st_mtime and
                    cached.get("sourceColor") == (_wallpaper_color_preference(wp_path) or cached.get("sourceColor"))):
                    if v in cached.get("variants", {}):
                        return cached["variants"][v]
                    return cached
            except Exception:
                pass
        return extract_chameleon_palette(wp_path, target_variant=v)
    if CHAMELEON_PALETTE_FILE.is_file():
        try:
            cached = json.loads(CHAMELEON_PALETTE_FILE.read_text(encoding="utf-8"))
            if v in cached.get("variants", {}):
                return cached["variants"][v]
            return cached
        except Exception:
            pass
    return extract_chameleon_palette(target_variant=v)


def generate_ghostty_theme_file(theme_name: str, palette: dict, themes_dir: Path | None = None) -> Path:
    """
    Gera um arquivo de tema customizado para o Ghostty (~/.config/ghostty/themes/<theme_name>).
    """
    c = palette.get("colors", {})
    t_dir = themes_dir if themes_dir is not None else GHOSTTY_THEMES_DIR
    t_dir.mkdir(parents=True, exist_ok=True)
    theme_file = t_dir / theme_name

    bg = c.get("backgroundOpaque", "#07131b")
    fg = c.get("foreground", "#ecf3f8")
    accent = c.get("accent", "#4ca8e0")
    surface = c.get("surface", "#13212b")
    surface_hover = c.get("surfaceHover", "#293a46")
    surface_selected = c.get("surfaceSelected", surface_hover)
    grey = c.get("grey", "#8d9aa3")
    off_white = c.get("offWhite", fg)

    red = c.get("red", "#e86883")
    green = c.get("green", "#56c888")
    yellow = c.get("yellow", "#d3d166")
    blue = c.get("blue", "#44a6ef")
    pink = c.get("pink", "#d490e6")
    cyan = c.get("cyan", "#4fccd8")

    bright_red = brighten_hex(red, 0.08)
    bright_green = brighten_hex(green, 0.08)
    bright_yellow = brighten_hex(yellow, 0.08)
    bright_blue = brighten_hex(blue, 0.08)
    bright_pink = brighten_hex(pink, 0.08)
    bright_cyan = brighten_hex(cyan, 0.08)

    lines = [
        f"palette = 0={surface}",
        f"palette = 1={red}",
        f"palette = 2={green}",
        f"palette = 3={yellow}",
        f"palette = 4={blue}",
        f"palette = 5={pink}",
        f"palette = 6={cyan}",
        f"palette = 7={off_white}",
        f"palette = 8={grey}",
        f"palette = 9={bright_red}",
        f"palette = 10={bright_green}",
        f"palette = 11={bright_yellow}",
        f"palette = 12={bright_blue}",
        f"palette = 13={bright_pink}",
        f"palette = 14={bright_cyan}",
        f"palette = 15={fg}",
        f"background = {bg}",
        f"foreground = {fg}",
        f"cursor-color = {accent}",
        f"cursor-text = {bg}",
        f"selection-background = {surface_selected}",
        f"selection-foreground = {fg}",
    ]
    content = "\n".join(lines) + "\n"
    temp_file = theme_file.with_suffix(".tmp")
    temp_file.write_text(content, encoding="utf-8")
    temp_file.replace(theme_file)
    return theme_file


def generate_ghostty_chameleon_theme(palette: dict | None = None, themes_dir: Path | None = None) -> Path:
    """
    Gera o arquivo de tema customizado do Ghostty (~/.config/ghostty/themes/chameleon)
    com base nas cores extraídas da paleta Chameleon.
    """
    p = palette or get_chameleon_palette(read_current_theme_id())
    return generate_ghostty_theme_file("chameleon", p, themes_dir=themes_dir)


def read_current_theme_id():
    try:
        if STATE_FILE.is_file():
            data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            theme_id = str(data.get("theme", "")).strip().lower()
            if theme_id in ("chameleon-vibrant", "chameleon-tonal", "chameleon-material"):
                return "chameleon"
            if theme_id in THEMES:
                return theme_id
    except Exception:
        pass
    return DEFAULT_THEME


def write_current_theme_id(theme_id):
    if theme_id not in THEMES:
        raise ValueError(f"Tema desconhecido: '{theme_id}'. Disponíveis: {', '.join(THEMES.keys())}")
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    temp_file = STATE_FILE.with_suffix(".tmp")
    data = {"theme": theme_id}
    temp_file.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temp_file.replace(STATE_FILE)
    return theme_id


def palette_hash(theme_dict: dict | None) -> str:
    """Stable hash of a theme palette for adapter sync verification."""
    try:
        colors = (theme_dict or {}).get("colors", {})
        canonical = json.dumps(colors, sort_keys=True, ensure_ascii=False)
        return hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16]
    except Exception:
        return ""


def read_adapter_state() -> dict:
    try:
        if ADAPTERS_FILE.is_file():
            data = json.loads(ADAPTERS_FILE.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return data
    except Exception:
        pass
    return {}


def record_adapter(name: str, ok: bool, theme_id: str, theme_dict: dict | None = None):
    """Persist per-adapter sync state: file existence alone never counts."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        state = read_adapter_state()
        state[str(name)] = {
            "ok": bool(ok),
            "theme": str(theme_id),
            "hash": palette_hash(theme_dict) if ok else "",
        }
        temp_file = ADAPTERS_FILE.with_suffix(".tmp")
        temp_file.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        temp_file.replace(ADAPTERS_FILE)
    except Exception:
        pass


def _read_text_safe(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


def _matching_json_brace(text: str, opening: int) -> int:
    """Find a matching JSON/JSONC brace while ignoring strings and comments."""
    depth = 0
    in_string = False
    escaped = False
    line_comment = False
    block_comment = False
    i = opening
    while i < len(text):
        char = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
        elif block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                i += 1
        elif in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == "/" and nxt == "/":
            line_comment = True
            i += 1
        elif char == "/" and nxt == "*":
            block_comment = True
            i += 1
        elif char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("Unbalanced JSONC object")


def _jsonc_object_span(text: str, name: str, start: int = 0, end: int | None = None) -> tuple[int, int]:
    limit = len(text) if end is None else end
    match = re.search(r'"' + re.escape(name) + r'"\s*:\s*\{', text[start:limit])
    if not match:
        raise ValueError(f"JSONC object not found: {name}")
    opening = start + match.end() - 1
    return opening, _matching_json_brace(text, opening)


def _set_jsonc_object_values(text: str, object_start: int, object_end: int, values: dict[str, str]) -> str:
    body = text[object_start + 1:object_end]
    for key, value in values.items():
        pattern = re.compile(r'("' + re.escape(key) + r'"\s*:\s*)"(?:\\.|[^"\\])*"')
        body, count = pattern.subn(lambda m: m.group(1) + json.dumps(value), body, count=1)
        if count != 1:
            raise ValueError(f"JSONC color entry not found: {key}")
    return text[:object_start + 1] + body + text[object_end:]


def sync_fastfetch_theme(theme_id: str, theme_dict: dict, config_path: Path | None = None) -> bool:
    """Keep Fastfetch logo and labels aligned with the active desktop palette."""
    path = config_path or FASTFETCH_CONFIG_PATH
    colors = (theme_dict or {}).get("colors", {})
    accent = str(colors.get("accent", "")).lower()
    cyan = str(colors.get("cyan", accent)).lower()
    pink = str(colors.get("pink", accent)).lower()
    if not accent or not re.fullmatch(r"#[0-9a-f]{6}", accent):
        record_adapter("fastfetch", False, theme_id, theme_dict)
        return False
    try:
        text = path.read_text(encoding="utf-8")
        logo_start, logo_end = _jsonc_object_span(text, "logo")
        logo_color_start, logo_color_end = _jsonc_object_span(text, "color", logo_start, logo_end)
        text = _set_jsonc_object_values(text, logo_color_start, logo_color_end, {"1": accent, "2": cyan})
        display_start, display_end = _jsonc_object_span(text, "display")
        display_color_start, display_color_end = _jsonc_object_span(text, "color", display_start, display_end)
        text = _set_jsonc_object_values(text, display_color_start, display_color_end,
                                        {"keys": accent, "title": pink})
        temp = path.with_suffix(path.suffix + ".tmp")
        temp.write_text(text, encoding="utf-8")
        temp.replace(path)
        ok = True
    except (OSError, ValueError):
        ok = False
    record_adapter("fastfetch", ok, theme_id, theme_dict)
    return ok


def verify_adapter(name: str, theme_id: str, theme_dict: dict | None = None) -> bool:
    """Releitura barata dos arquivos de destino. Existência do arquivo
    nunca basta: o conteúdo precisa corresponder à paleta aplicada."""
    tid = str(theme_id or "").strip().lower()
    colors = (theme_dict or {}).get("colors", {})
    accent = str(colors.get("accent", "")).lower()
    home = Path.home()
    cfg_home = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    cache_home = Path(os.environ.get("XDG_CACHE_HOME", home / ".cache"))
    try:
        if name == "ghostty":
            mapped = GHOSTTY_THEME_MAP.get(tid, "")
            if not mapped:
                return False
            content = _read_text_safe(GHOSTTY_CONFIG_PATH)
            return f"theme = {mapped}" in content
        if name == "kitty":
            expected = kitty_theme_contents(theme_dict or {})
            config = _read_text_safe(KITTY_CONFIG_PATH)
            return (bool(expected.strip())
                    and KITTY_THEME_FILE.is_file()
                    and _read_text_safe(KITTY_THEME_FILE) == expected
                    and _kitty_theme_include(KITTY_THEME_FILE) in config
                    and "allow_remote_control socket-only" in config)
        if name == "hyprland":
            if not accent:
                return False
            content = _read_text_safe(HYPR_THEME_LUA)
            surface = colors.get("surface", "")
            foreground = colors.get("foreground", "")
            active_text = colors.get("onPrimary") or _readable_on(accent)
            expected = (
                to_hyprland_hex_rgba(accent, "ee"),
                to_hyprland_hex_rgba(surface, "e8"),
                to_hyprland_hex_rgba(active_text, "ff"),
                to_hyprland_hex_rgba(foreground, "ff"),
            )
            return all(value.lower() in content.lower() for value in expected)
        if name == "hyprlock":
            if not accent:
                return False
            content = _read_text_safe(HYPRLOCK_COLORS_CONF)
            return to_hyprlang_rgba(colors.get("accent", ""), 0.60) in content
        if name == "labwc":
            if not accent:
                return False
            content = _read_text_safe(cfg_home / "labwc" / "themerc-override").lower()
            bg = str(colors.get("backgroundOpaque", "")).lower()
            return accent in content and (not bg or bg in content)
        if name == "mango":
            content = _read_text_safe(cfg_home / "mango" / "config.conf")
            expected = {
                "group_bar_decorate_fg_color": to_theme_hex_rgba(
                    colors.get("foreground", ""), 0xFF),
                "group_bar_decorate_bg_color": to_theme_hex_rgba(colors.get("surface", ""), 0xE8),
                "group_bar_decorate_focus_fg_color": to_theme_hex_rgba(
                    colors.get("onPrimary") or _readable_on(accent), 0xFF),
                "group_bar_decorate_focus_bg_color": to_theme_hex_rgba(accent, 0xEE),
                "group_bar_decorate_border_color": to_theme_hex_rgba(accent, 0xEE),
            }
            return bool(content) and all(
                re.search(r"^\s*" + re.escape(key) + r"\s*=\s*" + re.escape(value) + r"\s*$",
                          content, re.MULTILINE | re.IGNORECASE)
                for key, value in expected.items()
            )
        if name == "fastfetch":
            content = _read_text_safe(FASTFETCH_CONFIG_PATH)
            expected = {
                '"1": "' + accent + '"',
                '"2": "' + str(colors.get("cyan", accent)).lower() + '"',
                '"keys": "' + accent + '"',
                '"title": "' + str(colors.get("pink", accent)).lower() + '"',
            }
            return bool(content) and all(value in content.lower() for value in expected)
        if name == "gtk":
            theme_name = "chameleon" if tid.startswith("chameleon") else f"quickshell-{tid}"
            ini = _read_text_safe(cfg_home / "gtk-3.0" / "settings.ini")
            if f"gtk-theme-name = {theme_name}" not in ini \
                    and f"gtk-theme-name={theme_name}" not in ini:
                return theme_name == "Adwaita" and "gtk-theme-name" in ini
            if theme_name == "Adwaita" or not accent:
                return True
            css = _read_text_safe(home / ".themes" / theme_name / "gtk-3.0" / "gtk.css")
            return accent in css.lower()
        if name == "btop":
            conf = _read_text_safe(cfg_home / "btop" / "btop.conf")
            if 'color_theme = "chameleon"' not in conf:
                return False
            if not accent:
                return True
            theme_file = _read_text_safe(cfg_home / "btop" / "themes" / "chameleon.theme")
            return f'hi_fg="{accent}"'.lower() in theme_file.lower()
        if name == "qt":
            qt_conf = _read_text_safe(cfg_home / "qt6ct" / "qt6ct.conf")
            m = re.search(r"^style=(.+)$", qt_conf, flags=re.MULTILINE)
            style = m.group(1).strip() if m else ""
            if style == "breeze":
                if not accent:
                    return False
                r, g, b = hex_to_rgb(accent)
                colors_file = _read_text_safe(cfg_home / "qt6ct" / "colors" / "Chameleon.colors")
                return f"BackgroundNormal={r}, {g}, {b}" in colors_file
            kv = _read_text_safe(CONFIG_DIR / "Kvantum" / "kvantum.kvconfig")
            if "theme=chameleon" not in kv:
                return False
            if not accent:
                return True
            kvcss = _read_text_safe(CONFIG_DIR / "Kvantum" / "chameleon" / "chameleon.kvconfig")
            return accent in kvcss.lower()
    except Exception:
        return False
    return False


def adapter_in_sync(name: str, theme_id: str, theme_dict: dict | None = None) -> bool:
    entry = read_adapter_state().get(str(name), {})
    if not entry.get("ok"):
        return False
    if entry.get("theme") != str(theme_id):
        return False
    expected = palette_hash(theme_dict)
    if not expected or entry.get("hash") != expected:
        return False
    return verify_adapter(name, theme_id, theme_dict)


def get_cached_variants() -> dict | None:
    if CHAMELEON_PALETTE_FILE.is_file():
        try:
            cached = json.loads(CHAMELEON_PALETTE_FILE.read_text(encoding="utf-8"))
            return cached.get("variants")
        except Exception:
            pass
    return None


def cmd_get(theme_id=None):
    current = read_current_theme_id()
    target_id = (theme_id or current).strip().lower()
    if target_id.startswith("chameleon"):
        THEMES[target_id] = get_chameleon_palette(target_id)
    if target_id not in THEMES:
        return {"ok": False, "error": f"Tema '{target_id}' não encontrado", "current": current}
    theme_info = THEMES[target_id]
    return {
        "ok": True,
        "error": None,
        "current": current,
        "theme": theme_info,
        "variants": get_cached_variants(),
        "adapters": {
            "quickshell": True,
            "kitty": adapter_in_sync("kitty", target_id, theme_info),
            "ghostty": adapter_in_sync("ghostty", target_id, theme_info),
            "hyprland": adapter_in_sync("hyprland", target_id, theme_info),
            "hyprlock": adapter_in_sync("hyprlock", target_id, theme_info),
            "gtk": adapter_in_sync("gtk", target_id, theme_info),
            "btop": adapter_in_sync("btop", target_id, theme_info),
            "qt": adapter_in_sync("qt", target_id, theme_info),
            "labwc": adapter_in_sync("labwc", target_id, theme_info),
            "mango": adapter_in_sync("mango", target_id, theme_info),
            "fastfetch": adapter_in_sync("fastfetch", target_id, theme_info),
        },
    }


def cmd_sync_hyprlock():
    """Gera a paleta do lock no cache convencional, inclusive no primeiro login."""
    current = read_current_theme_id()
    if current.startswith("chameleon"):
        THEMES[current] = get_chameleon_palette(current)
    theme_info = THEMES.get(current, THEMES.get(DEFAULT_THEME))
    if not theme_info:
        return {"ok": False, "error": "Não foi possível carregar o tema atual"}
    ok = sync_hyprlock_theme(palette=theme_info)
    return {
        "ok": ok,
        "error": None if ok else "Falha ao gerar as cores do Hyprlock",
        "current": current,
        "adapter": "hyprlock",
    }


def cmd_list():
    current = read_current_theme_id()
    for cid in ["chameleon", "chameleon-light", "chameleon-oled"]:
        THEMES[cid] = get_chameleon_palette(cid)
    items = []
    for tid, info in THEMES.items():
        items.append({
            "id": tid,
            "name": info["name"],
            "category": info["category"],
            "description": info["description"],
            "accent": info["accent"],
            "active": (tid == current),
        })
    items.sort(key=lambda x: x["name"].lower())
    return {
        "ok": True,
        "error": None,
        "current": current,
        "themes": items,
    }


def kitty_theme_contents(palette: dict) -> str:
    """Render the active semantic palette in kitty's native config format."""
    colors = palette.get("colors", {})
    background = colors.get("backgroundOpaque", "#1e1e2e")
    foreground = colors.get("foreground", "#cdd6f4")
    accent = colors.get("accent", "#89b4fa")
    selection = colors.get("surfaceSelected", colors.get("surfaceHover", "#45475a"))
    ansi = [
        colors.get("surface", background),
        colors.get("red", "#f38ba8"),
        colors.get("green", "#a6e3a1"),
        colors.get("yellow", "#f9e2af"),
        colors.get("blue", "#89b4fa"),
        colors.get("pink", "#f5c2e7"),
        colors.get("cyan", "#94e2d5"),
        colors.get("offWhite", foreground),
        colors.get("grey", "#585b70"),
        brighten_hex(colors.get("red", "#f38ba8"), 0.08),
        brighten_hex(colors.get("green", "#a6e3a1"), 0.08),
        brighten_hex(colors.get("yellow", "#f9e2af"), 0.08),
        brighten_hex(colors.get("blue", "#89b4fa"), 0.08),
        brighten_hex(colors.get("pink", "#f5c2e7"), 0.08),
        brighten_hex(colors.get("cyan", "#94e2d5"), 0.08),
        foreground,
    ]
    lines = [
        f"foreground {foreground}",
        f"background {background}",
        f"selection_foreground {foreground}",
        f"selection_background {selection}",
        f"cursor {accent}",
        f"cursor_text_color {background}",
    ]
    lines.extend(f"color{index} {value}" for index, value in enumerate(ansi))
    return "\n".join(lines) + "\n"


def _kitty_theme_include(theme_file: Path) -> str:
    include = "${HOME}/.local/state/quickshell/kitty-theme.conf"
    default_state_file = Path.home() / ".local/state/quickshell/kitty-theme.conf"
    if theme_file != default_state_file:
        include = str(theme_file)
    return include


def _kitty_managed_config(config_path: Path, theme_file: Path) -> str:
    """Keep kitty's theme include and private runtime socket configured once."""
    content = _read_text_safe(config_path)
    start = "# BEGIN Quickshell theme integration"
    end = "# END Quickshell theme integration"
    include = _kitty_theme_include(theme_file)
    block = "\n".join((
        start,
        "allow_remote_control socket-only",
        "listen_on unix:${XDG_RUNTIME_DIR}/quickshell-kitty-{kitty_pid}",
        f"include {include}",
        end,
    ))
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.DOTALL)
    if pattern.search(content):
        updated = pattern.sub(block, content, count=1)
    else:
        updated = content.rstrip() + "\n\n" + block + "\n"
    return updated


def reload_kitty_config() -> bool:
    """Ask each Kitty process owned by this user to reload its config."""
    try:
        result = subprocess.run(
            ["pgrep", "-u", str(os.getuid()), "-x", "kitty"],
            capture_output=True, text=True, timeout=2,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    if result.returncode != 0:
        return False

    reloaded = False
    for value in result.stdout.split():
        try:
            os.kill(int(value), signal.SIGUSR1)
            reloaded = True
        except (ProcessLookupError, PermissionError, ValueError):
            continue
    return reloaded


def sync_kitty_theme(theme_id: str, config_path: Path | None = None,
                     theme_file: Path | None = None, palette: dict | None = None) -> bool:
    """Write kitty's startup theme and update all reachable kitty windows."""
    config = config_path if config_path is not None else KITTY_CONFIG_PATH
    target = theme_file if theme_file is not None else KITTY_THEME_FILE
    active_palette = palette or THEMES.get(theme_id)
    if not config.is_file() or not active_palette:
        record_adapter("kitty", False, theme_id)
        return False

    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        content = kitty_theme_contents(active_palette)
        temp_file = target.with_suffix(target.suffix + ".tmp")
        temp_file.write_text(content, encoding="utf-8")
        temp_file.replace(target)

        new_config = _kitty_managed_config(config, target)
        if new_config != config.read_text(encoding="utf-8"):
            temp_config = config.with_suffix(config.suffix + ".tmp")
            temp_config.write_text(new_config, encoding="utf-8")
            temp_config.replace(config)

        sockets = sorted(KITTY_RUNTIME_DIR.glob("quickshell-kitty-*"))
        updated_live_windows = False
        if sockets:
            executable = shutil.which("kitten") or shutil.which("kitty")
            if executable:
                results = [subprocess.run(
                    [executable, "@", "--to", f"unix:{socket}", "set-colors",
                     "--all", "--configured", str(target)],
                    capture_output=True, text=True, timeout=3,
                ) for socket in sockets]
                updated_live_windows = all(result.returncode == 0 for result in results)

        # The SIGUSR1 fallback also works in already-open Kitty processes that
        # predate the remote-control socket setting.
        if not updated_live_windows:
            reload_kitty_config()

        record_adapter("kitty", True, theme_id, active_palette)
        return True
    except (OSError, subprocess.SubprocessError, ValueError):
        record_adapter("kitty", False, theme_id)
        return False


def get_ghostty_ptys() -> list[str]:
    """
    Encontra todos os pseudo-terminais (/dev/pts/*) pertencentes a instâncias do Ghostty.
    """
    ptys = set()
    import subprocess
    try:
        res = subprocess.run(["pgrep", "-u", str(os.getuid()), "ghostty"], capture_output=True, text=True, timeout=1)
        if res.returncode == 0:
            for gpid in res.stdout.strip().split():
                c_res = subprocess.run(["pgrep", "-P", gpid], capture_output=True, text=True, timeout=1)
                if c_res.returncode == 0:
                    for cpid in c_res.stdout.strip().split():
                        for fd in [0, 1, 2]:
                            p = Path(f"/proc/{cpid}/fd/{fd}")
                            try:
                                target = os.readlink(p)
                                if target.startswith("/dev/pts/") and target != "/dev/ptmx":
                                    ptys.add(target)
                            except Exception:
                                pass
    except Exception:
        pass
    return sorted(list(ptys))


def broadcast_osc_palette(palette: dict | None = None) -> int:
    """
    Transmite sequências de controle OSC (OSC 10, 11, 12, 4) para todos os terminais
    Ghostty ativos para atualização visual imediata de superfícies abertas.
    """
    if not palette or "colors" not in palette:
        return 0

    c = palette["colors"]
    bg = c.get("backgroundOpaque", "#07131b")
    fg = c.get("foreground", "#ecf3f8")
    accent = c.get("accent", "#4ca8e0")
    surface = c.get("surface", "#13212b")
    surface_hover = c.get("surfaceHover", "#293a46")
    grey = c.get("grey", "#8d9aa3")
    off_white = c.get("offWhite", "#d6e2ec")

    red = c.get("red", "#e86883")
    green = c.get("green", "#56c888")
    yellow = c.get("yellow", "#d3d166")
    blue = c.get("blue", "#44a6ef")
    pink = c.get("pink", "#d490e6")
    cyan = c.get("cyan", "#4fccd8")

    bright_red = brighten_hex(red, 0.08)
    bright_green = brighten_hex(green, 0.08)
    bright_yellow = brighten_hex(yellow, 0.08)
    bright_blue = brighten_hex(blue, 0.08)
    bright_pink = brighten_hex(pink, 0.08)
    bright_cyan = brighten_hex(cyan, 0.08)

    ansi = [
        surface, red, green, yellow, blue, pink, cyan, off_white,
        grey, bright_red, bright_green, bright_yellow, bright_blue, bright_pink, bright_cyan, fg
    ]

    seqs = [f"\033]10;{fg}\007", f"\033]11;{bg}\007", f"\033]12;{accent}\007"]
    for i, col in enumerate(ansi):
        seqs.append(f"\033]4;{i};{col}\007")
    payload = "".join(seqs)

    count = 0
    for pty in get_ghostty_ptys():
        try:
            with open(pty, "w", encoding="utf-8") as f:
                f.write(payload)
                f.flush()
            count += 1
        except Exception:
            pass
    return count


def reload_ghostty() -> bool:
    """
    Envia sinal SIGUSR2 para todos os processos Ghostty do usuário atual
    para forçar o recarregamento imediato da configuração e do tema.
    """
    import shutil
    import subprocess

    if shutil.which("pkill"):
        try:
            res = subprocess.run(
                ["pkill", "-SIGUSR2", "-u", str(os.getuid()), "ghostty"],
                capture_output=True,
                text=True,
                timeout=2,
            )
            return res.returncode == 0
        except Exception:
            pass
    return False


def sync_ghostty_theme(theme_id: str, config_path: Path | None = None, themes_dir: Path | None = None, palette: dict | None = None) -> bool:
    """
    Sincroniza o tema selecionado com a configuração do Ghostty (~/.config/ghostty/config).
    O Ghostty recebe o sinal SIGUSR2 e recarrega as cores instantaneamente sem fechar os terminais.
    """
    path = config_path if config_path is not None else GHOSTTY_CONFIG_PATH
    if not path.is_file():
        record_adapter("ghostty", False, theme_id)
        return False

    ghostty_theme = GHOSTTY_THEME_MAP.get(theme_id)
    if not ghostty_theme:
        record_adapter("ghostty", False, theme_id)
        return False

    if theme_id.startswith("chameleon"):
        try:
            generate_ghostty_chameleon_theme(palette=palette, themes_dir=themes_dir)
        except Exception:
            pass
    elif theme_id.startswith("dracula-pro"):
        try:
            t_data = palette or THEMES.get(theme_id)
            if t_data:
                generate_ghostty_theme_file(theme_id, t_data, themes_dir=themes_dir)
        except Exception:
            pass

    try:
        content = path.read_text(encoding="utf-8")
        if re.search(r"^\s*theme\s*=.*$", content, flags=re.MULTILINE):
            new_content = re.sub(r"^\s*theme\s*=.*$", f"theme = {ghostty_theme}", content, flags=re.MULTILINE, count=1)
        else:
            new_content = content.rstrip() + f"\ntheme = {ghostty_theme}\n"

        temp_file = path.with_suffix(".tmp")
        temp_file.write_text(new_content, encoding="utf-8")
        temp_file.replace(path)

        active_palette = palette or THEMES.get(theme_id) or (get_chameleon_palette(theme_id) if theme_id.startswith("chameleon") else None)
        if active_palette:
            broadcast_osc_palette(active_palette)
        reload_ghostty()
        record_adapter("ghostty", True, theme_id, active_palette)
        return True
    except Exception:
        record_adapter("ghostty", False, theme_id)
        return False


def hex_to_rgb_tuple(hex_str: str) -> tuple[int, int, int]:
    h = str(hex_str or "#000000").lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    elif len(h) < 6:
        h = h.ljust(6, "0")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def to_hyprlang_rgba(hex_str: str, alpha: float = 1.0) -> str:
    r, g, b = hex_to_rgb_tuple(hex_str)
    return f"rgba({r}, {g}, {b}, {alpha:.2f})"


def to_hyprlang_rgb(hex_str: str) -> str:
    r, g, b = hex_to_rgb_tuple(hex_str)
    return f"rgb({r}, {g}, {b})"


def to_hyprland_hex_rgba(hex_str: str, alpha_hex: str = "ee") -> str:
    h = str(hex_str or "#89b4fa").lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    elif len(h) < 6:
        h = h.ljust(6, "0")
    return f"rgba({h[:6]}{alpha_hex})"


def export_canonical_palette(theme_data: dict) -> Path:
    """
    Salva a paleta canônica central em ~/.local/state/quickshell/current_palette.json.
    Essa paleta serve como Single Source of Truth para todas as integrações.
    """
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        out = {
            "id": theme_data.get("id", ""),
            "name": theme_data.get("name", ""),
            "wallpaper": str(detect_current_wallpaper() or ""),
            "colors": theme_data.get("colors", {}),
        }
        temp = CANONICAL_PALETTE_FILE.with_suffix(".tmp")
        temp.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        temp.replace(CANONICAL_PALETTE_FILE)
    except Exception:
        pass
    return CANONICAL_PALETTE_FILE


def sync_hyprland_theme(palette: dict | None = None, cache_dir: Path | None = None) -> bool:
    """
    Gera ~/.cache/hypr/theme.lua e aplica as cores de borda no Hyprland ao vivo via hyprctl eval.
    """
    if not palette or "colors" not in palette:
        return False
    try:
        target_dir = cache_dir if cache_dir is not None else HYPR_CACHE_DIR
        target_dir.mkdir(parents=True, exist_ok=True)
        target_file = target_dir / "theme.lua"

        colors = palette["colors"]
        accent = colors.get("accent", "#89b4fa")
        surface = colors.get("surface", "#313244")
        foreground = colors.get("foreground", "#cdd6f4")
        active_text = colors.get("onPrimary") or _readable_on(accent)

        active_border = to_hyprland_hex_rgba(accent, "ee")
        inactive_border = to_hyprland_hex_rgba(surface, "88")
        group_border_active = to_hyprland_hex_rgba(accent, "ee")
        group_border_inactive = to_hyprland_hex_rgba(surface, "88")
        groupbar_active = to_hyprland_hex_rgba(accent, "ee")
        groupbar_inactive = to_hyprland_hex_rgba(surface, "e8")
        groupbar_text_active = to_hyprland_hex_rgba(active_text, "ff")
        groupbar_text_inactive = to_hyprland_hex_rgba(foreground, "ff")

        lua_content = (
            "-- Generated by Quickshell Theme Manager\n"
            "return {\n"
            f'    id = "{palette.get("id", "")}",\n'
            f'    active_border = "{active_border}",\n'
            f'    inactive_border = "{inactive_border}",\n'
            f'    group_border_active = "{group_border_active}",\n'
            f'    group_border_inactive = "{group_border_inactive}",\n'
            f'    groupbar_active = "{groupbar_active}",\n'
            f'    groupbar_inactive = "{groupbar_inactive}",\n'
            f'    groupbar_text_active = "{groupbar_text_active}",\n'
            f'    groupbar_text_inactive = "{groupbar_text_inactive}",\n'
            "}\n"
        )

        tmp = target_file.with_suffix(".tmp")
        tmp.write_text(lua_content, encoding="utf-8")
        tmp.replace(target_file)

        # Se hyprctl estiver presente, atualiza o compositor ao vivo
        if is_hyprland_session() and shutil.which("hyprctl"):
            eval_cmd = (
                f'hl.config({{ general = {{ col = {{ '
                f'active_border = {{ colors = {{ "{active_border}" }}, angle = 45 }}, '
                f'inactive_border = "{inactive_border}" '
                f'}} }}, group = {{ col = {{ '
                f'border_active = {{ colors = {{ "{group_border_active}" }}, angle = 45 }}, '
                f'border_inactive = "{group_border_inactive}", '
                f'border_locked_active = {{ colors = {{ "{group_border_active}" }}, angle = 45 }}, '
                f'border_locked_inactive = "{group_border_inactive}" '
                f'}}, groupbar = {{ col = {{ '
                f'active = "{groupbar_active}", '
                f'inactive = "{groupbar_inactive}", '
                f'locked_active = "{groupbar_active}", '
                f'locked_inactive = "{groupbar_inactive}" '
                f'}}, text_color = "{groupbar_text_active}", '
                f'text_color_inactive = "{groupbar_text_inactive}" '
                f'}} }} }} }})'
            )
            try:
                subprocess.run(
                    ["hyprctl", "eval", eval_cmd],
                    capture_output=True,
                    text=True,
                    timeout=1,
                )
            except Exception:
                pass
        record_adapter("hyprland", True, str((palette or {}).get("id", "")), palette)
        return True
    except Exception:
        record_adapter("hyprland", False, str((palette or {}).get("id", "")))
        return False


def to_theme_hex_rgba(color: str, alpha: int) -> str:
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", str(color)):
        return ""
    return f"0x{color[1:]}{alpha:02X}".upper()


def sync_mango_theme(palette: dict | None = None, config_path: Path | None = None) -> bool:
    """Keep Mango's compact group tabs aligned with the active theme palette."""
    tid = str((palette or {}).get("id", ""))
    colors = (palette or {}).get("colors", {})
    accent = str(colors.get("accent", "")).lower()
    surface = str(colors.get("surface", "")).lower()
    foreground = str(colors.get("foreground", "")).lower()
    active_text = str(colors.get("onPrimary") or _readable_on(accent)).lower()
    path = config_path if config_path is not None else MANGO_CONFIG_PATH
    if not all(re.fullmatch(r"#[0-9a-f]{6}", c) for c in (accent, surface, foreground, active_text)):
        record_adapter("mango", False, tid, palette)
        return False

    values = {
        "group_bar_decorate_fg_color": to_theme_hex_rgba(foreground, 0xFF),
        "group_bar_decorate_bg_color": to_theme_hex_rgba(surface, 0xE8),
        "group_bar_decorate_focus_fg_color": to_theme_hex_rgba(active_text, 0xFF),
        "group_bar_decorate_focus_bg_color": to_theme_hex_rgba(accent, 0xEE),
        "group_bar_decorate_border_color": to_theme_hex_rgba(accent, 0xEE),
    }
    try:
        content = path.read_text(encoding="utf-8")
        for key, value in values.items():
            pattern = re.compile(r"^[ \t]*" + re.escape(key) + r"[ \t]*=.*$", re.MULTILINE)
            content, count = pattern.subn(f"{key}={value}", content, count=1)
            if count != 1:
                raise ValueError(f"Mango setting not found: {key}")
        temp = path.with_suffix(path.suffix + ".tmp")
        temp.write_text(content, encoding="utf-8")
        temp.replace(path)
        if is_mango_session() and shutil.which("mmsg"):
            try:
                subprocess.run(
                    ["mmsg", "dispatch", "reload_config"],
                    capture_output=True, text=True, timeout=3,
                )
            except Exception:
                pass
        record_adapter("mango", True, tid, palette)
        return True
    except (OSError, ValueError):
        record_adapter("mango", False, tid, palette)
        return False


def sync_hyprlock_theme(palette: dict | None = None, cache_dir: Path | None = None) -> bool:
    """
    Gera ~/.cache/hypr/hyprlock_colors.conf com variáveis de cor para o hyprlock.
    """
    if not palette or "colors" not in palette:
        return False
    try:
        target_dir = cache_dir if cache_dir is not None else HYPRLOCK_COLORS_CONF.parent
        target_dir.mkdir(parents=True, exist_ok=True)
        target_file = target_dir / "hyprlock_colors.conf"

        colors = palette["colors"]
        accent = colors.get("accent", "#89b4fa")
        surface = colors.get("surface", "#313244")
        foreground = colors.get("foreground", "#cdd6f4")
        lock_surface = colors.get("backgroundOpaque", surface)
        is_light = palette.get("category") == "light"
        lock_border = colors.get("grey", "#8c8fa1") if is_light else "#ffffff"
        green = colors.get("green", "#a6e3a1")
        red = colors.get("red", "#f38ba8")

        conf_content = (
            "# Generated by Quickshell Theme Manager\n"
            f"$accent = {to_hyprlang_rgba(accent, 0.60)}\n"
            f"$surface = {to_hyprlang_rgba(surface, 0.90)}\n"
            f"$lockSurface = {to_hyprlang_rgba(lock_surface, 0.68)}\n"
            f"$lockBorder = {to_hyprlang_rgba(lock_border, 0.22 if is_light else 0.12)}\n"
            f"$font = {to_hyprlang_rgb(foreground)}\n"
            f"$fontAlpha = {to_hyprlang_rgba(foreground, 0.80)}\n"
            f"$check = {to_hyprlang_rgba(green, 1.00)}\n"
            f"$fail = {to_hyprlang_rgba(red, 1.00)}\n"
        )

        tmp = target_file.with_suffix(".tmp")
        tmp.write_text(conf_content, encoding="utf-8")
        tmp.replace(target_file)
        record_adapter("hyprlock", True, str((palette or {}).get("id", "")), palette)
        return True
    except Exception:
        record_adapter("hyprlock", False, str((palette or {}).get("id", "")))
        return False


def reconfigure_labwc() -> bool:
    """Recarrega o labwc ao vivo; só faz sentido dentro da sessão labwc."""
    if not os.environ.get("LABWC_PID"):
        return False
    if not shutil.which("labwc"):
        return False
    try:
        res = subprocess.run(
            ["labwc", "--reconfigure"],
            capture_output=True, text=True, timeout=5,
        )
        return res.returncode == 0
    except Exception:
        return False


def sync_labwc_theme(palette: dict | None = None, config_home: Path | None = None) -> bool:
    """
    Gera ~/.config/labwc/themerc-override a partir da paleta e recarrega
    o labwc ao vivo quando estiver na sessão labwc (LABWC_PID).
    """
    tid = str((palette or {}).get("id", ""))
    if not palette or "colors" not in palette:
        record_adapter("labwc", False, tid)
        return False
    try:
        base = config_home if config_home is not None else Path(
            os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        target_dir = base / "labwc"
        target_dir.mkdir(parents=True, exist_ok=True)
        target_file = target_dir / "themerc-override"

        colors = palette["colors"]
        accent = colors.get("accent", "#89b4fa")
        bg = colors.get("backgroundOpaque", "#1e1e2e")
        surface_hover = colors.get("surfaceHover", "#45475a")
        foreground = colors.get("foreground", "#cdd6f4")
        grey = colors.get("grey", "#585b70")

        override_content = (
            f"# Generated by Quickshell Theme Manager — tema {tid}.\n"
            "# Regenerado em `set` / `update-wallpaper`. Edições manuais aqui\n"
            "# são substituídas na próxima sincronização de tema.\n"
            "border.width: 2\n"
            f"window.active.border.color: {accent}\n"
            f"window.inactive.border.color: {surface_hover}\n"
            f"window.active.title.bg.color: {bg}\n"
            f"window.inactive.title.bg.color: {darken_hex(bg)}\n"
            f"window.active.label.text.color: {foreground}\n"
            f"window.inactive.label.text.color: {grey}\n"
            f"window.active.button.unpressed.image.color: {foreground}\n"
            f"window.inactive.button.unpressed.image.color: {grey}\n"
            f"window.button.hover.bg.color: {surface_hover}\n"
            "window.button.hover.bg.corner-radius: 6\n"
            f"menu.border.color: {surface_hover}\n"
            f"menu.items.bg.color: {bg}\n"
            f"menu.items.text.color: {foreground}\n"
            f"menu.items.active.bg.color: {surface_hover}\n"
            f"menu.items.active.text.color: {foreground}\n"
            f"menu.separator.color: {grey}\n"
            f"menu.title.bg.color: {accent}\n"
            f"menu.title.text.color: {bg}\n"
            f"osd.bg.color: {bg}\n"
            f"osd.border.color: {surface_hover}\n"
            f"osd.label.text.color: {foreground}\n"
            f"osd.window-switcher.style-classic.item.active.border.color: {accent}\n"
            f"osd.window-switcher.style-classic.item.active.bg.color: {surface_hover}\n"
        )

        tmp = target_file.with_suffix(".tmp")
        tmp.write_text(override_content, encoding="utf-8")
        tmp.replace(target_file)
        # Melhor esforço: falha no reload ao vivo não invalida a escrita.
        try:
            reconfigure_labwc()
        except Exception:
            pass
        record_adapter("labwc", True, tid, palette)
        return True
    except Exception:
        record_adapter("labwc", False, tid)
        return False


def gtk_theme_dirs() -> list[Path]:
    home = Path.home()
    seen = []
    for base in (
        home / ".themes",
        Path(os.environ.get("XDG_DATA_HOME", home / ".local/share")) / "themes",
        Path("/usr/share/themes"),
    ):
        if base.is_dir() and base not in seen:
            seen.append(base)
    return seen


def gtk_theme_installed(name: str) -> bool:
    """Adwaita é embutido; demais temas exigem gtk-3.0 ou gtk-4.0 no disco."""
    if name == "Adwaita":
        return True
    for base in gtk_theme_dirs():
        d = base / name
        if (d / "gtk-3.0" / "gtk.css").is_file() or (d / "gtk-4.0" / "gtk.css").is_file():
            return True
    return False


def pick_gtk_theme(category: str) -> str:
    """Escolhe tema instalado por categoria, com fallback seguro."""
    if category == "light":
        for base in gtk_theme_dirs():
            try:
                names = sorted(p.name for p in base.iterdir() if p.is_dir())
            except OSError:
                continue
            for n in names:
                if n.startswith("catppuccin-latte-") and "hdpi" not in n and "xhdpi" not in n:
                    if gtk_theme_installed(n):
                        return n
        return "Adwaita"
    preferred = "catppuccin-mocha-pink-standard-default"
    if gtk_theme_installed(preferred):
        return preferred
    for base in gtk_theme_dirs():
        try:
            names = sorted(p.name for p in base.iterdir() if p.is_dir())
        except OSError:
            continue
        for n in names:
            if n.startswith("catppuccin-mocha-") and n.endswith("-standard-default") \
                    and "hdpi" not in n and "xhdpi" not in n:
                if gtk_theme_installed(n):
                    return n
    return "Adwaita"


def _write_gtk_settings_ini(gtk_theme: str, dark: bool, config_home: Path | None = None) -> bool:
    base = config_home if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    wrote = False
    for version in ("gtk-3.0", "gtk-4.0"):
        ini = base / version / "settings.ini"
        try:
            ini.parent.mkdir(parents=True, exist_ok=True)
            cfg = configparser.ConfigParser()
            if ini.is_file():
                cfg.read(ini, encoding="utf-8")
            if not cfg.has_section("Settings"):
                cfg.add_section("Settings")
            cfg.set("Settings", "gtk-theme-name", gtk_theme)
            cfg.set("Settings", "gtk-application-prefer-dark-theme", "1" if dark else "0")
            tmp = ini.with_suffix(".tmp")
            with tmp.open("w", encoding="utf-8") as f:
                cfg.write(f)
            tmp.replace(ini)
            wrote = True
        except Exception:
            pass
    return wrote


def _chameleon_gtk_css(c: dict) -> str:
    """Render the GTK fallback stylesheet from the active semantic palette."""
    surface = c.get("surface", "#313244")
    values = {
        "BG": c.get("backgroundOpaque", "#1e1e2e"),
        "SURF": surface,
        "HOVER": c.get("surfaceHover", "#45475a"),
        "FG": c.get("foreground", "#cdd6f4"),
        "DIM": c.get("offWhite", "#bac2de"),
        "GREY": c.get("grey", "#585b70"),
        "ACC": c.get("accent", "#89b4fa"),
        "RED": c.get("red", "#f38ba8"),
        "GREEN": c.get("green", "#a6e3a1"),
        "YELLOW": c.get("yellow", "#f9e2af"),
        "MANTLE": darken_hex(surface),
    }
    stylesheet = (SCRIPT_DIR / "templates" / "gtk-chameleon.css").read_text(encoding="utf-8")
    for name, value in values.items():
        stylesheet = stylesheet.replace(f"__QS_{name}__", value)
    return stylesheet


def _chameleon_derived(c: dict) -> dict:
    bg = c.get("backgroundOpaque", "#1e1e2e")
    surf = c.get("surface", "#313244")
    hover = c.get("surfaceHover", "#45475a")
    fg = c.get("foreground", "#cdd6f4")
    dim = c.get("offWhite", "#bac2de")
    grey = c.get("grey", "#585b70")
    acc = c.get("accent", "#89b4fa")
    red = c.get("red", "#f38ba8")
    green = c.get("green", "#a6e3a1")
    yellow = c.get("yellow", "#f9e2af")
    blue = c.get("blue", "#89b4fa")
    pink = c.get("pink", "#f5c2e7")
    cyan = c.get("cyan", "#94e2d5")
    orange = c.get("orange", "#fab387")
    return {
        "bg": bg, "mantle": darken_hex(bg, 0.035), "crust": darken_hex(bg, 0.07),
        "surface": surf, "surface_hover": hover,
        "surface_bright": brighten_hex(hover, 0.06),
        "fg": fg, "dim": dim, "grey": grey,
        "grey_light": brighten_hex(grey, 0.12),
        "acc": acc, "red": red, "green": green, "yellow": yellow,
        "blue": blue, "pink": pink, "cyan": cyan, "orange": orange,
        "red_dark": darken_hex(red, 0.08), "green_dark": darken_hex(green, 0.08),
        "yellow_dark": darken_hex(yellow, 0.08),
        "blue_light": brighten_hex(blue, 0.08),
    }


def _chameleon_for_template_hex(hx: str, d: dict) -> str | None:
    """Map a Catppuccin Mocha hex to the chameleon equivalent by role,
    falling back to nearest-hue semantic for one-off shades."""
    h = hx.lower()
    explicit = {
        "#1e1e2e": d["bg"], "#181825": d["mantle"], "#11111b": d["crust"],
        "#14141f": d["mantle"], "#0b0b12": d["crust"], "#0a0a0f": d["crust"],
        "#060609": "#000000",
        "#313244": d["surface"], "#393947": d["surface_hover"],
        "#45475a": d["surface_hover"], "#585b70": d["surface_bright"],
        "#282938": d["surface"], "#242434": d["surface"],
        "#292936": d["surface"], "#333342": d["surface_hover"],
        "#34343f": d["surface_hover"], "#35353d": d["surface_hover"],
        "#3d3e4c": d["surface_hover"], "#3e3e5f": d["surface_hover"],
        "#444556": d["surface_hover"], "#4d4d54": d["surface_hover"],
        "#5d5d6a": d["grey"],
        "#cdd6f4": d["fg"], "#eff1f5": d["fg"],
        "#bac2de": d["dim"], "#a6adc8": d["dim"], "#b0b2b9": d["grey"],
        "#9399b2": d["grey_light"], "#7f849c": d["grey"],
        "#6c7086": d["grey"], "#8c7189": d["grey"],
        "#9f9792": d["grey"], "#7b736e": d["grey"], "#605955": d["grey"],
        "#574f4a": d["grey"], "#474341": d["grey"], "#463e39": d["grey"],
        "#403c3a": d["grey"], "#393634": d["grey"], "#342c27": d["grey"],
        "#33302f": d["grey"], "#2b2928": d["grey"],
        "#f5c2e7": d["acc"], "#cba6f7": d["acc"],
        "#f38ba8": d["red"], "#ed547e": d["red_dark"],
        "#fab387": d["orange"], "#f9e2af": d["yellow"],
        "#f5cd76": d["yellow_dark"], "#a6e3a1": d["green"],
        "#79d572": d["green_dark"], "#94e2d5": d["cyan"],
        "#89dceb": d["cyan"], "#89b4fa": d["blue"],
        "#74c7ec": d["blue"], "#b4befe": d["blue_light"],
    }
    if h in explicit:
        return explicit[h]
    try:
        r, g, b = hex_to_rgb(h)
        hh, _, ss = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if ss < 0.15:
            return None
        deg = hh * 360.0
        if deg < 15 or deg >= 345:
            return d["red"]
        if deg < 45:
            return d["orange"]
        if deg < 70:
            return d["yellow"]
        if deg < 160:
            return d["green"]
        if deg < 195:
            return d["cyan"]
        if deg < 250:
            return d["blue"]
        return d["pink"]
    except Exception:
        return None


def _recolor_css_template(css: str, d: dict) -> str:
    def sub_hex(m):
        mapped = _chameleon_for_template_hex(m.group(0), d)
        return mapped if mapped else m.group(0)

    css = re.sub(r"#[0-9a-fA-F]{6}\b", sub_hex, css)

    rgb_map = {
        (239, 241, 245): hex_to_rgb(d["fg"]),
        (17, 17, 27): hex_to_rgb(d["crust"]),
        (30, 30, 46): hex_to_rgb(d["bg"]),
        (49, 50, 68): hex_to_rgb(d["surface"]),
        (11, 11, 18): hex_to_rgb(d["crust"]),
        (245, 194, 231): hex_to_rgb(d["acc"]),
        (243, 139, 168): hex_to_rgb(d["red"]),
    }

    def sub_rgba(m):
        key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        alpha = m.group(4).strip()
        if key in rgb_map:
            r, g, b = rgb_map[key]
            return f"rgba({r}, {g}, {b}, {alpha})"
        return m.group(0)

    return re.sub(r"rgba\((\d+),\s*(\d+),\s*(\d+),([^)]*)\)", sub_rgba, css)


def _find_gtk_template() -> Path | None:
    cands = []
    for base in gtk_theme_dirs():
        try:
            names = sorted(p.name for p in base.iterdir() if p.is_dir())
        except OSError:
            continue
        for n in names:
            d = base / n
            if ((d / "gtk-3.0" / "gtk.css").is_file()
                    and (d / "gtk-4.0" / "gtk.css").is_file()
                    and "hdpi" not in n and "xhdpi" not in n):
                cands.append(d)
    for d in cands:
        if d.name == "catppuccin-mocha-pink-standard-default":
            return d
    for d in cands:
        if d.name.startswith("catppuccin-mocha-"):
            return d
    return cands[0] if cands else None


def _recolor_svg_text(text: str, d: dict) -> str:
    def sub(m):
        mapped = _chameleon_for_template_hex(m.group(0), d)
        return mapped if mapped else m.group(0)

    return re.sub(r"#[0-9a-fA-F]{6}\b", sub, text)


def generate_gtk_chameleon_theme(palette: dict | None = None,
                                 themes_dir: Path | None = None,
                                 name: str = "chameleon") -> Path:
    """Generate ~/.themes/chameleon (GTK 3+4) from the active palette.

    Recolors the installed Catppuccin Mocha template role by role, so the
    structure stays Catppuccin while every color follows the palette.
    Falls back to the flat generator when no template is installed.
    """
    p = palette or get_chameleon_palette(read_current_theme_id())
    c = p.get("colors", {})
    t_dir = themes_dir if themes_dir is not None else GTK_THEMES_DIR
    theme_dir = t_dir / name
    template = None if themes_dir is not None else _find_gtk_template()
    for version in ("gtk-3.0", "gtk-4.0"):
        vdir = theme_dir / version
        vdir.mkdir(parents=True, exist_ok=True)
        if template is not None:
            src = template / version / "gtk.css"
            try:
                css = _recolor_css_template(
                    src.read_text(encoding="utf-8"), _chameleon_derived(c))
            except OSError:
                css = _chameleon_gtk_css(c)
            asrc = template / version / "assets"
            adst = vdir / "assets"
            if asrc.is_dir():
                # Sempre recolorido: assets copiados uma vez manteriam
                # as cores do wallpaper anterior.
                if adst.is_dir():
                    shutil.rmtree(adst, ignore_errors=True)
                try:
                    adst.mkdir(parents=True, exist_ok=True)
                    for svg in sorted(asrc.glob("*.svg")):
                        try:
                            adst.joinpath(svg.name).write_text(
                                _recolor_svg_text(
                                    svg.read_text(encoding="utf-8"),
                                    _chameleon_derived(c)),
                                encoding="utf-8")
                        except OSError:
                            pass
                except OSError:
                    pass
        else:
            css = _chameleon_gtk_css(c)
        for name in ("gtk.css", "gtk-dark.css"):
            tmp = vdir / (name + ".tmp")
            tmp.write_text(css, encoding="utf-8")
            tmp.replace(vdir / name)
    index = (
        "[Desktop Entry]\n"
        "Type=X-GNOME-Metatheme\n"
        f"Name={name}\n"
        "Comment=Dynamic palette (Quickshell)\n"
        "Encoding=UTF-8\n"
        "\n"
        "[X-GNOME-Metatheme]\n"
        f"GtkTheme={name}\n"
    )
    tmp = theme_dir / "index.theme.tmp"
    tmp.write_text(index, encoding="utf-8")
    tmp.replace(theme_dir / "index.theme")
    return theme_dir


def _relative_luminance(hex_str: str) -> float:
    r, g, b = hex_to_rgb(hex_str)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def _accent_color_name(hex_str: str) -> str:
    """Closest org.gnome.desktop.interface accent-color for a hex accent."""
    try:
        r, g, b = hex_to_rgb(hex_str)
        h, _, s = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if s < 0.18:
            return "slate"
        deg = h * 360.0
        if deg < 15 or deg >= 340:
            return "red"
        if deg < 45:
            return "orange"
        if deg < 70:
            return "yellow"
        if deg < 160:
            return "green"
        if deg < 190:
            return "teal"
        if deg < 250:
            return "blue"
        if deg < 290:
            return "purple"
        return "pink"
    except Exception:
        return "blue"


def libadwaita_recolor_css(theme_dict: dict | None) -> str:
    """gtk.css overrides with libadwaita recoloring vars from the palette."""
    c = (theme_dict or {}).get("colors", {})
    bg = c.get("backgroundOpaque", "#1e1e2e")
    fg = c.get("foreground", "#cdd6f4")
    surf = c.get("surface", "#313244")
    hover = c.get("surfaceHover", "#45475a")
    mantle = darken_hex(bg, 0.035)
    # Large flat libadwaita areas desaturated toward neutral (bar-like);
    # accent and semantic colors keep full saturation.
    surf_n = desaturate_hex(surf)
    hover_n = desaturate_hex(hover)
    mantle_n = desaturate_hex(mantle)
    dim = c.get("offWhite", "#bac2de")
    acc = c.get("accent", "#89b4fa")
    red = c.get("red", "#f38ba8")
    green = c.get("green", "#a6e3a1")
    yellow = c.get("yellow", "#f9e2af")
    acc_fg = "#1e1e2e" if _relative_luminance(acc) > 0.55 else "#ffffff"
    err_fg = "#1e1e2e" if _relative_luminance(red) > 0.55 else "#ffffff"
    return f"""/* Generated by Quickshell Theme Manager: libadwaita recoloring. */
@define-color window_bg_color {bg};
@define-color window_fg_color {fg};
@define-color view_bg_color {surf_n};
@define-color view_fg_color {fg};
@define-color headerbar_bg_color {mantle_n};
@define-color headerbar_fg_color {fg};
@define-color headerbar_border_color {hover_n};
@define-color headerbar_backdrop_color {bg};
@define-color card_bg_color {surf_n};
@define-color card_fg_color {fg};
@define-color dialog_bg_color {surf_n};
@define-color dialog_fg_color {fg};
@define-color popover_bg_color {surf_n};
@define-color popover_fg_color {fg};
@define-color thumbnail_bg_color {hover_n};
@define-color thumbnail_fg_color {dim};
@define-color accent_bg_color {acc};
@define-color accent_fg_color {acc_fg};
@define-color accent_color {acc};
@define-color destructive_bg_color {red};
@define-color destructive_fg_color {err_fg};
@define-color destructive_color {red};
@define-color success_bg_color {green};
@define-color success_fg_color #1e1e2e;
@define-color success_color {green};
@define-color warning_bg_color {yellow};
@define-color warning_fg_color #1e1e2e;
@define-color warning_color {yellow};
@define-color error_bg_color {red};
@define-color error_fg_color {err_fg};
@define-color error_color {red};
"""


def _write_libadwaita_css(theme_dict: dict | None,
                          config_home: Path | None = None) -> bool:
    base = config_home if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    css_file = base / "gtk-4.0" / "gtk.css"
    try:
        css_file.parent.mkdir(parents=True, exist_ok=True)
        if css_file.is_file():
            current = css_file.read_text(encoding="utf-8")
            if "Generated by Quickshell Theme Manager" not in current:
                bak = css_file.with_suffix(".css.bak")
                if not bak.is_file():
                    shutil.copy2(css_file, bak)
        tmp = css_file.with_suffix(".css.tmp")
        tmp.write_text(libadwaita_recolor_css(theme_dict), encoding="utf-8")
        tmp.replace(css_file)
        return True
    except Exception:
        return False


def generate_btop_chameleon_theme(palette: dict | None = None,
                                  config_home: Path | None = None) -> Path | None:
    """Generate a btop .theme from the active palette (flat key=value)."""
    p = palette or get_chameleon_palette(read_current_theme_id())
    c = p.get("colors", {})
    bg = c.get("backgroundOpaque", "#1e1e2e")
    fg = c.get("foreground", "#cdd6f4")
    surf = c.get("surface", "#313244")
    hover = c.get("surfaceHover", "#45475a")
    grey = c.get("grey", "#585b70")
    acc = c.get("accent", "#89b4fa")
    red = c.get("red", "#f38ba8")
    green = c.get("green", "#a6e3a1")
    yellow = c.get("yellow", "#f9e2af")
    blue = c.get("blue", "#89b4fa")
    pink = c.get("pink", "#f5c2e7")
    base = Path(config_home) if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    tdir = base / "btop" / "themes"
    try:
        tdir.mkdir(parents=True, exist_ok=True)
        grad = ("green", green, "yellow", yellow, "red", red)
        lines = [
            "# Generated by Quickshell Theme Manager: chameleon palette.",
            f'theme_bg="{bg}"',
            f'theme_fg="{fg}"',
            f'title="{fg}"',
            f'hi_fg="{acc}"',
            f'selected_bg="{hover}"',
            f'selected_fg="{acc}"',
            f'inactive_fg="{grey}"',
            f'graph_text="{yellow}"',
            f'meter_bg="{hover}"',
            f'proc_misc="{yellow}"',
            f'cpu_box="{pink}"',
            f'mem_box="{green}"',
            f'net_box="{red}"',
            f'proc_box="{blue}"',
            f'div_line="{surf}"',
        ]
        for box in ("temp", "cpu", "free", "cached", "available",
                    "used", "download", "upload"):
            lines += [f'{box}_start="{green}"', f'{box}_mid="{yellow}"',
                      f'{box}_end="{red}"']
        theme_file = tdir / "chameleon.theme"
        tmp = theme_file.with_suffix(".tmp")
        tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
        tmp.replace(theme_file)
        return theme_file
    except Exception:
        return None


def _set_btop_theme(theme_name: str, config_home: Path | None = None) -> bool:
    base = Path(config_home) if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    conf = base / "btop" / "btop.conf"
    try:
        if not conf.is_file():
            return False
        text = conf.read_text(encoding="utf-8")
        if re.search(r'^\s*color_theme\s*=', text, flags=re.MULTILINE):
            text = re.sub(r'^\s*color_theme\s*=.*$',
                          f'color_theme = "{theme_name}"',
                          text, flags=re.MULTILINE, count=1)
        else:
            text = text.rstrip() + f'\ncolor_theme = "{theme_name}"\n'
        tmp = conf.with_suffix(".tmp")
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(conf)
        return True
    except Exception:
        return False


def _find_kvantum_template(kvantum_dir: Path | None = None) -> Path | None:
    base = kvantum_dir if kvantum_dir is not None else KVANTUM_DIR
    if not base.is_dir():
        return None
    cands = []
    try:
        for p in sorted(base.iterdir()):
            if p.is_dir() and next(p.glob("*.kvconfig"), None):
                cands.append(p)
    except OSError:
        return None
    for d in cands:
        if d.name == "catppuccin-mocha-pink":
            return d
    for d in cands:
        if d.name.startswith("catppuccin-mocha-"):
            return d
    return cands[0] if cands else None


def _recolor_kvconfig_text(text: str, d: dict) -> str:
    def sub8(m):
        mapped = _chameleon_for_template_hex("#" + m.group(1), d)
        return (mapped + m.group(2)) if mapped else m.group(0)

    text = re.sub(r"#([0-9a-fA-F]{6})([0-9a-fA-F]{2})\b", sub8, text)

    def sub6(m):
        mapped = _chameleon_for_template_hex(m.group(0), d)
        return mapped if mapped else m.group(0)

    return re.sub(r"#[0-9a-fA-F]{6}\b", sub6, text)


def _triplet(hex_str: str) -> str:
    r, g, b = hex_to_rgb(hex_str)
    return f"{r}, {g}, {b}"


def _readable_on(hex_str: str) -> str:
    return "#1e1e2e" if _relative_luminance(hex_str) > 0.55 else "#ffffff"


def build_breeze_colors(theme_dict: dict | None) -> str:
    """qt6ct color scheme built from Breeze role structure with
    chameleon hues (replaces template recoloring)."""
    c = (theme_dict or {}).get("colors", {})
    bg = c.get("backgroundOpaque", "#1e1e2e")
    surf = c.get("surface", "#313244")
    hover = c.get("surfaceHover", "#45475a")
    mantle = darken_hex(bg, 0.035)
    fg = c.get("foreground", "#cdd6f4")
    dim = c.get("offWhite", "#bac2de")
    grey = c.get("grey", "#585b70")
    acc = c.get("accent", "#89b4fa")
    red = c.get("red", "#f38ba8")
    green = c.get("green", "#a6e3a1")
    yellow = c.get("yellow", "#f9e2af")
    blue = c.get("blue", "#89b4fa")
    pink = c.get("pink", "#f5c2e7")
    acc_fg = _readable_on(acc)

    # Mesma lição do libadwaita: grandes áreas planas dessaturadas.
    surf_n = desaturate_hex(surf)
    hover_n = desaturate_hex(hover)
    mantle_n = desaturate_hex(mantle)

    def section(bg_, alt, fg_, dim_, link, neg, neu, pos, dec_f, dec_h):
        return {
            "BackgroundAlternate": _triplet(alt),
            "BackgroundNormal": _triplet(bg_),
            "DecorationFocus": _triplet(dec_f),
            "DecorationHover": _triplet(dec_h),
            "ForegroundActive": _triplet(fg_),
            "ForegroundInactive": _triplet(dim_),
            "ForegroundLink": _triplet(link),
            "ForegroundNegative": _triplet(neg),
            "ForegroundNeutral": _triplet(neu),
            "ForegroundNormal": _triplet(fg_),
            "ForegroundPositive": _triplet(pos),
            "ForegroundVisited": _triplet(pink),
        }

    sections = {
        "Colors:Window": section(bg, surf, fg, dim, blue, red, yellow, green, acc, hover),
        "Colors:View": section(surf_n, hover_n, fg, dim, blue, red, yellow, green, acc, hover),
        "Colors:Button": section(surf_n, hover_n, fg, dim, blue, red, yellow, green, acc, hover),
        "Colors:Selection": section(acc, acc, acc_fg, acc_fg, acc_fg, acc_fg,
                                    acc_fg, acc_fg, acc, hover),
        "Colors:Tooltip": section(hover_n, hover_n, fg, dim, blue, red, yellow, green, acc, hover),
        "Colors:Complementary": section(hover_n, surf_n, fg, dim, blue, red, yellow, green, acc, hover),
        "Colors:Header": section(mantle_n, mantle_n, fg, dim, blue, red, yellow, green, acc, hover),
    }
    out = ["# Generated by Quickshell Theme Manager: breeze roles, chameleon hues.", ""]
    for name, keys in sections.items():
        out.append(f"[{name}]")
        for k, v in keys.items():
            out.append(f"{k}={v}")
        out.append("")
    return "\n".join(out)


def _recolor_rgb_triplets(text: str, d: dict) -> str:
    def sub(m):
        hx = "#{:02x}{:02x}{:02x}".format(
            int(m.group(1)), int(m.group(2)), int(m.group(3)))
        mapped = _chameleon_for_template_hex(hx, d)
        if not mapped:
            return m.group(0)
        r, g, b = hex_to_rgb(mapped)
        return f"{r}, {g}, {b}"

    return re.sub(r"(\d{1,3}), (\d{1,3}), (\d{1,3})", sub, text)


def _flatten_kvantum_tabs(css: str) -> str:
    """Flat tab style (text + indicator) instead of the inherited
    raised button frame, closer to the bar pill language."""

    def section(name: str, body: str) -> str:
        lines = [l for l in body.splitlines() if not l.startswith("frame=")]
        return f"[{name}]\n" + "\n".join(lines) + "\nframe=false\n"

    def sub_tab(m):
        return section("Tab", m.group(1))

    return re.sub(r"\[Tab\]\n((?:[^\[]*\n)*?)(?=\[|\Z)", sub_tab, css, count=1)


def generate_qt_chameleon_theme(palette: dict | None = None,
                               config_home: Path | None = None,
                               kvantum_dir: Path | None = None) -> Path | None:
    """Generate Kvantum chameleon theme + qt6ct colors from the palette."""
    p = palette or get_chameleon_palette(read_current_theme_id())
    c = p.get("colors", {})
    d = _chameleon_derived(c)
    base = Path(config_home) if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    kv_base = kvantum_dir if kvantum_dir is not None else base / "Kvantum"
    template = _find_kvantum_template(kvantum_dir if kvantum_dir is not None else None)
    src_cfg = next(template.glob("*.kvconfig"), None) if template else None
    out_dir = None
    if src_cfg is not None:
        try:
            out_dir = kv_base / "chameleon"
            out_dir.mkdir(parents=True, exist_ok=True)
            css = _recolor_kvconfig_text(src_cfg.read_text(encoding="utf-8"), d)
            css = _flatten_kvantum_tabs(css)
            tmp = out_dir / "chameleon.kvconfig.tmp"
            tmp.write_text(css, encoding="utf-8")
            tmp.replace(out_dir / "chameleon.kvconfig")
            for svg in template.glob("*.svg"):
                dst = out_dir / svg.name
                if not dst.is_file():
                    try:
                        shutil.copy2(svg, dst)
                    except OSError:
                        pass
        except OSError:
            out_dir = None

    # qt6ct color scheme: built from Breeze roles (template only
    # supplies the non-color sections below).
    try:
        qt6ct_conf = base / "qt6ct" / "qt6ct.conf"
        if qt6ct_conf.is_file():
            colors_dir = base / "qt6ct" / "colors"
            colors_dir.mkdir(parents=True, exist_ok=True)
            out_colors = colors_dir / "Chameleon.colors"
            scheme_text = build_breeze_colors(p)
            template_src = Path("/usr/share/color-schemes/CatppuccinMochaPink.colors")
            if template_src.is_file():
                try:
                    raw = template_src.read_text(encoding="utf-8")
                    extra = []
                    keep = False
                    for line in raw.splitlines(keepends=True):
                        if line.startswith("[ColorEffects:") or line.startswith("[General]") \
                                or line.startswith("[KDE]") or line.startswith("[WM]"):
                            keep = True
                        elif line.startswith("["):
                            keep = False
                        if keep:
                            extra.append(line)
                    if extra:
                        scheme_text += "\n" + _recolor_rgb_triplets("".join(extra), d)
                except OSError:
                    pass
            tmp = out_colors.with_suffix(".tmp")
            tmp.write_text(scheme_text, encoding="utf-8")
            tmp.replace(out_colors)
            text = qt6ct_conf.read_text(encoding="utf-8")
            if re.search(r"^color_scheme_path=", text, flags=re.MULTILINE):
                text = re.sub(r"^color_scheme_path=.*$",
                              f"color_scheme_path={out_colors}",
                              text, flags=re.MULTILINE, count=1)
            else:
                text = text.rstrip() + f"\ncolor_scheme_path={out_colors}\n"
            # Breeze carrega a paleta do esquema acima sem relevo herdado;
            # Kvantum continua gerado como alternativa (style=kvantum).
            if re.search(r"^style=", text, flags=re.MULTILINE):
                text = re.sub(r"^style=.*$", "style=breeze",
                              text, flags=re.MULTILINE, count=1)
            else:
                text = text.rstrip() + "\nstyle=breeze\n"
            tmp = qt6ct_conf.with_suffix(".tmp")
            tmp.write_text(text, encoding="utf-8")
            tmp.replace(qt6ct_conf)
    except OSError:
        pass
    return out_dir


def _set_kvantum_theme(theme_name: str, kvantum_dir: Path | None = None) -> bool:
    base = kvantum_dir if kvantum_dir is not None else KVANTUM_DIR
    conf = base / "kvantum.kvconfig"
    try:
        if not conf.is_file():
            return False
        text = conf.read_text(encoding="utf-8")
        if re.search(r"^theme=", text, flags=re.MULTILINE):
            text = re.sub(r"^theme=.*$", f"theme={theme_name}",
                          text, flags=re.MULTILINE, count=1)
        else:
            text = text.rstrip() + f"\ntheme={theme_name}\n"
        tmp = conf.with_suffix(".tmp")
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(conf)
        return True
    except Exception:
        return False


def sync_qt_theme(theme_id: str, theme_dict: dict | None = None,
                  config_home: Path | None = None,
                  kvantum_dir: Path | None = None) -> bool:
    """Fase 4: gera tema Kvantum chameleon e seleciona; cores qt6ct junto.

    Só atua quando há Kvantum configurado; caso contrário registra
    fora de sync em vez de falhar silenciosamente.
    """
    tid = str(theme_id or "").strip().lower()
    info = theme_dict or THEMES.get(tid, {})
    active = info if info.get("colors") else None
    kv_base = kvantum_dir if kvantum_dir is not None else KVANTUM_DIR
    qt_conf = (Path(config_home) if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))) / "qt6ct" / "qt6ct.conf"
    if _find_kvantum_template(kvantum_dir) is None and not kv_base.is_dir() \
            and not qt_conf.is_file():
        record_adapter("qt", False, tid)
        return False
    out = generate_qt_chameleon_theme(palette=active, config_home=config_home,
                                      kvantum_dir=kvantum_dir)
    _base = Path(config_home) if config_home is not None else Path(
        os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    colors_ok = (_base / "qt6ct" / "colors" / "Chameleon.colors").is_file()
    kv_ok = False
    if out is not None:
        kv_ok = _set_kvantum_theme("chameleon", kvantum_dir=kvantum_dir)
    ok = kv_ok or colors_ok
    if not (_find_kvantum_template(kvantum_dir) is not None
            or (_base / "qt6ct" / "qt6ct.conf").is_file()):
        ok = False
    record_adapter("qt", ok, tid, active if ok else None)
    return ok


def sync_btop_theme(theme_id: str, theme_dict: dict | None = None,
                    config_home: Path | None = None) -> bool:
    """Fase 3: gera chameleon.theme e seleciona no btop.conf."""
    tid = str(theme_id or "").strip().lower()
    info = theme_dict or THEMES.get(tid, {})
    active = info if info.get("colors") else None
    theme_file = generate_btop_chameleon_theme(palette=active,
                                               config_home=config_home)
    if theme_file is None:
        record_adapter("btop", False, tid)
        return False
    ok = _set_btop_theme("chameleon", config_home=config_home)
    record_adapter("btop", ok, tid, active if ok else None)
    return ok


def sync_gtk_theme(theme_id: str, theme_dict: dict | None = None,
                   config_home: Path | None = None,
                   themes_dir: Path | None = None) -> bool:
    """Fase 2+: preferência claro/escuro + tema GTK instalado ou gerado.

    Temas chameleon geram ~/.themes/chameleon a partir da paleta ativa;
    demais temas escolhem entre instalados (fallback Adwaita).
    Espelha em gsettings + settings.ini do GTK 3/4.
    """
    tid = str(theme_id or "").strip().lower()
    info = theme_dict or THEMES.get(tid, {})
    dark = str(info.get("category", "dark")).lower() != "light"
    scheme = "prefer-dark" if dark else "prefer-light"
    if tid.startswith("chameleon"):
        gtk_theme = "chameleon"
        try:
            active = info if info.get("colors") else None
            generate_gtk_chameleon_theme(palette=active, themes_dir=themes_dir,
                                         name=gtk_theme)
        except Exception:
            gtk_theme = pick_gtk_theme("dark" if dark else "light")
    else:
        # Temas estáticos também ganham CSS da própria paleta em vez de
        # herdar um Catppuccin fixo que não os representa.
        gtk_theme = f"quickshell-{tid}"
        try:
            active = info if info.get("colors") else None
            generate_gtk_chameleon_theme(palette=active, themes_dir=themes_dir,
                                         name=gtk_theme)
        except Exception:
            gtk_theme = pick_gtk_theme("dark" if dark else "light")

    gsettings_ok = False
    if shutil.which("gsettings"):
        try:
            r1 = subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface",
                 "color-scheme", f"'{scheme}'"],
                capture_output=True, text=True, timeout=5,
            )
            r2 = subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface",
                 "gtk-theme", gtk_theme],
                capture_output=True, text=True, timeout=5,
            )
            gsettings_ok = r1.returncode == 0 and r2.returncode == 0
        except Exception:
            gsettings_ok = False

    ini_ok = _write_gtk_settings_ini(gtk_theme, dark, config_home=config_home)
    adw_ok = _write_libadwaita_css(info, config_home=config_home)
    if shutil.which("gsettings"):
        try:
            r3 = subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface",
                 "accent-color", _accent_color_name(str(info.get("colors", {}).get("accent", "#89b4fa")))],
                capture_output=True, text=True, timeout=5,
            )
            gsettings_ok = gsettings_ok and r3.returncode == 0
        except Exception:
            pass
    ok = gsettings_ok or ini_ok or adw_ok
    record_adapter("gtk", ok, tid, info if ok else None)
    return ok


def apply_all_adapters(
    theme_id: str,
    theme_dict: dict,
    ghostty_config: Path | None = None,
    ghostty_themes_dir: Path | None = None,
    kitty_config: Path | None = None,
    kitty_theme_file: Path | None = None,
    hypr_cache_dir: Path | None = None,
    gtk_config_home: Path | None = None,
    gtk_themes_dir: Path | None = None,
    btop_config_home: Path | None = None,
    qt_config_home: Path | None = None,
    qt_kvantum_dir: Path | None = None,
    labwc_config_home: Path | None = None,
    mango_config_path: Path | None = None,
) -> dict[str, bool]:
    """Apply one palette to every adapter, isolating each adapter's failure."""
    export_canonical_palette(theme_dict)

    def sync_ghostty() -> bool:
        if theme_id.startswith("chameleon"):
            generate_ghostty_chameleon_theme(palette=theme_dict, themes_dir=ghostty_themes_dir)
        elif theme_id.startswith("dracula-pro"):
            generate_ghostty_theme_file(theme_id, theme_dict, themes_dir=ghostty_themes_dir)
        return sync_ghostty_theme(
            theme_id,
            config_path=ghostty_config,
            themes_dir=ghostty_themes_dir,
            palette=theme_dict,
        )
    def sync_kitty() -> bool:
        return sync_kitty_theme(
            theme_id,
            config_path=kitty_config,
            theme_file=kitty_theme_file,
            palette=theme_dict,
        )
    adapters = {
        "kitty": sync_kitty,
        "ghostty": sync_ghostty,
        "hyprland": lambda: sync_hyprland_theme(palette=theme_dict, cache_dir=hypr_cache_dir),
        "hyprlock": lambda: sync_hyprlock_theme(palette=theme_dict),
        "gtk": lambda: sync_gtk_theme(
            theme_id, theme_dict, config_home=gtk_config_home, themes_dir=gtk_themes_dir),
        "btop": lambda: sync_btop_theme(
            theme_id, theme_dict, config_home=btop_config_home),
        "qt": lambda: sync_qt_theme(
            theme_id, theme_dict, config_home=qt_config_home,
            kvantum_dir=qt_kvantum_dir),
        "labwc": lambda: sync_labwc_theme(
            palette=theme_dict, config_home=labwc_config_home),
        "mango": lambda: sync_mango_theme(palette=theme_dict, config_path=mango_config_path),
        "fastfetch": lambda: sync_fastfetch_theme(theme_id, theme_dict),
    }
    results = {name: _run_adapter(sync) for name, sync in adapters.items()}
    return {"quickshell": True, **results}


def _run_adapter(sync) -> bool:
    try:
        return bool(sync())
    except Exception:
        return False


def cmd_set(theme_id):
    tid = str(theme_id or "").strip().lower()
    if tid not in THEMES:
        return {
            "ok": False,
            "error": f"Tema '{tid}' não encontrado. Disponíveis: {', '.join(THEMES.keys())}",
            "current": read_current_theme_id(),
        }
    if tid.startswith("chameleon"):
        THEMES[tid] = extract_chameleon_palette(target_variant=tid)
    new_id = write_current_theme_id(tid)
    theme_dict = THEMES[new_id]
    adapters = apply_all_adapters(new_id, theme_dict)
    return {
        "ok": True,
        "error": None,
        "current": new_id,
        "theme": theme_dict,
        "variants": get_cached_variants(),
        "kitty_synced": adapters.get("kitty", False),
        "ghostty_synced": adapters.get("ghostty", False),
        "adapters": adapters,
    }


def cmd_next():
    current = read_current_theme_id()
    keys = sorted(list(THEMES.keys()), key=lambda k: THEMES[k]["name"].lower())
    try:
        idx = keys.index(current)
        next_id = keys[(idx + 1) % len(keys)]
    except ValueError:
        next_id = keys[0]
    return cmd_set(next_id)


def cmd_update_wallpaper(wallpaper_path=None):
    current = read_current_theme_id()
    target_var = current if current.startswith("chameleon") else "chameleon"
    # Sem mudança real de wallpaper e com cache válido: não reextrai
    # (evita loop com o watcher de ~/.cache/current_wallpaper).
    active_wp = wallpaper_path or detect_current_wallpaper()
    if active_wp and Path(active_wp).is_file() and CHAMELEON_PALETTE_FILE.is_file():
        try:
            cached = json.loads(CHAMELEON_PALETTE_FILE.read_text(encoding="utf-8"))
            if cached.get("algorithm") == "material-tonal-spot-2021-v2" and \
                    cached.get("wallpaper") == str(Path(active_wp)) and \
                    cached.get("wallpaper_mtime") == Path(active_wp).stat().st_mtime and \
                    cached.get("sourceColor") == (_wallpaper_color_preference(Path(active_wp)) or cached.get("sourceColor")):
                for cid in ["chameleon", "chameleon-light", "chameleon-oled"]:
                    THEMES[cid] = get_chameleon_palette(cid)
                theme_info = THEMES.get(current, THEMES.get(DEFAULT_THEME))
                return {
                    "ok": True,
                    "error": None,
                    "current": current,
                    "theme": cached.get("variants", {}).get(target_var, cached),
                    "variants": get_cached_variants(),
                    "kitty_synced": adapter_in_sync("kitty", current, theme_info),
                    "ghostty_synced": False,
                    "adapters": {
                        "quickshell": True,
                        "kitty": adapter_in_sync("kitty", current, theme_info),
                        "ghostty": adapter_in_sync("ghostty", current, theme_info),
                        "hyprland": adapter_in_sync("hyprland", current, theme_info),
                        "hyprlock": adapter_in_sync("hyprlock", current, theme_info),
                        "gtk": adapter_in_sync("gtk", current, theme_info),
                        "btop": adapter_in_sync("btop", current, theme_info),
                        "qt": adapter_in_sync("qt", current, theme_info),
                        "labwc": adapter_in_sync("labwc", current, theme_info),
                        "mango": (
                            adapter_in_sync("mango", current, theme_info)
                            or sync_mango_theme(theme_info)
                        ),
                        "fastfetch": (
                            adapter_in_sync("fastfetch", current, theme_info)
                            or sync_fastfetch_theme(current, theme_info)
                        ),
                    },
                }
        except Exception:
            pass
    palette = extract_chameleon_palette(wallpaper_path, target_variant=target_var)
    for cid in ["chameleon", "chameleon-light", "chameleon-oled"]:
        THEMES[cid] = get_chameleon_palette(cid)

    if current.startswith("chameleon"):
        write_current_theme_id(current)
        active_pal = THEMES.get(current, palette)
        adapters = apply_all_adapters(current, active_pal)
    else:
        active_theme = THEMES.get(current, THEMES.get(DEFAULT_THEME))
        export_canonical_palette(active_theme)
        # Tema estático: paleta não mudou, só relata estado verificado.
        adapters = {
            "quickshell": True,
            "kitty": adapter_in_sync("kitty", current, active_theme),
            "ghostty": adapter_in_sync("ghostty", current, active_theme),
            "hyprland": adapter_in_sync("hyprland", current, active_theme),
            "hyprlock": adapter_in_sync("hyprlock", current, active_theme),
            "gtk": adapter_in_sync("gtk", current, active_theme),
            "btop": adapter_in_sync("btop", current, active_theme),
            "qt": adapter_in_sync("qt", current, active_theme),
            "labwc": adapter_in_sync("labwc", current, active_theme),
            "mango": adapter_in_sync("mango", current, active_theme),
            "fastfetch": adapter_in_sync("fastfetch", current, active_theme),
        }

    return {
        "ok": True,
        "error": None,
        "current": current,
        "theme": palette,
        "variants": get_cached_variants(),
        "kitty_synced": adapters.get("kitty", False),
        "ghostty_synced": adapters.get("ghostty", False),
        "adapters": adapters,
    }


def cmd_wallpaper_colors(wallpaper_path=None):
    path = Path(wallpaper_path or detect_current_wallpaper() or "")
    if not path.is_file():
        return {"ok": False, "error": "Wallpaper ativo não encontrado"}
    colors, _ = _wallpaper_candidates(path)
    automatic = colors[0] if colors else "#5a82aa"
    return {"ok": True, "data": {"wallpaper": str(path), "colors": colors,
                                    "automatic": automatic,
                                    "selected": _wallpaper_color_preference(path)}}


def cmd_preview_wallpaper_color(wallpaper_path, color, variant):
    if variant not in ("chameleon", "chameleon-light", "chameleon-oled"):
        return {"ok": False, "error": "Variante inválida"}
    path = Path(wallpaper_path)
    if not path.is_file():
        return {"ok": False, "error": "Wallpaper não encontrado"}
    if color == "auto":
        colors, _ = _wallpaper_candidates(path)
        color = colors[0] if colors else "#5a82aa"
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", str(color or "")):
        return {"ok": False, "error": "Cor inválida"}
    palette = extract_chameleon_palette(path, variant, color, persist=False)
    return {"ok": True, "data": {"theme": palette}}


def cmd_set_wallpaper_color(wallpaper_path, color, variant):
    path = Path(wallpaper_path)
    active = detect_current_wallpaper()
    if not path.is_file() or not active or os.path.realpath(path) != os.path.realpath(active):
        return {"ok": False, "error": "O wallpaper ativo mudou; atualize a galeria e tente novamente"}
    if variant not in ("chameleon", "chameleon-light", "chameleon-oled"):
        return {"ok": False, "error": "Variante inválida"}
    if color != "auto":
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", str(color or "")):
            return {"ok": False, "error": "Cor inválida"}
        colors, _ = _wallpaper_candidates(path)
        if color.lower() not in colors:
            return {"ok": False, "error": "A cor não pertence às opções deste wallpaper"}
    _save_wallpaper_color_preference(path, None if color == "auto" else color.lower())
    return cmd_set(variant)


def main():
    parser = argparse.ArgumentParser(description="Gerenciador de Temas do Quickshell")
    parser.add_argument("action", nargs="?", default="get", choices=["get", "list", "set", "next", "update-wallpaper", "wallpaper-colors", "preview-wallpaper-color", "set-wallpaper-color", "sync-hyprlock"], help="Ação a executar")
    parser.add_argument("theme", nargs="?", default=None, help="ID do tema ou caminho do wallpaper")
    parser.add_argument("color", nargs="?", default=None)
    parser.add_argument("variant", nargs="?", default=None)
    args = parser.parse_args()

    try:
        # Include reads: palette discovery can also update caches/adapters.
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with (STATE_DIR / "theme-manager.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.action == "list":
                res = cmd_list()
            elif args.action == "set":
                if not args.theme:
                    res = {"ok": False, "error": "ID do tema obrigatório para a ação 'set'"}
                else:
                    res = cmd_set(args.theme)
            elif args.action == "next":
                res = cmd_next()
            elif args.action == "update-wallpaper":
                res = cmd_update_wallpaper(args.theme)
            elif args.action == "wallpaper-colors":
                res = cmd_wallpaper_colors(args.theme)
            elif args.action == "preview-wallpaper-color":
                res = cmd_preview_wallpaper_color(args.theme, args.color, args.variant)
            elif args.action == "set-wallpaper-color":
                res = cmd_set_wallpaper_color(args.theme, args.color, args.variant)
            elif args.action == "sync-hyprlock":
                res = cmd_sync_hyprlock()
            else:
                res = cmd_get(args.theme)
    except Exception as e:
        res = {"ok": False, "error": str(e)}

    if isinstance(res, dict):
        res.setdefault("version", 1)
    print(json.dumps(res, ensure_ascii=False, indent=2))
    return 0 if res.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
