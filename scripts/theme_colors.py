"""Pure color conversion and semantic palette helpers for theme adapters."""

import colorsys
import math


def rgb_to_hex(r, g, b):
    return f"#{int(round(r)):02x}{int(round(g)):02x}{int(round(b)):02x}"


def hsl_to_hex(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))
    return rgb_to_hex(r * 255, g * 255, b * 255)


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    clean = str(hex_str or "").lstrip("#")
    if len(clean) == 6:
        try:
            return int(clean[0:2], 16), int(clean[2:4], 16), int(clean[4:6], 16)
        except ValueError:
            pass
    return 128, 128, 128


def brighten_hex(hex_str: str, amount: float = 0.08) -> str:
    r, g, b = hex_to_rgb(hex_str)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return hsl_to_hex(h, s, min(0.95, l + amount))


def darken_hex(hex_str: str, amount: float = 0.06) -> str:
    r, g, b = hex_to_rgb(hex_str)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return hsl_to_hex(h, s, max(0.02, l - amount))


def desaturate_hex(hex_str: str, factor: float = 0.35) -> str:
    """Reduce saturation, keeping lightness: neutralizes large flat areas
    from strongly tinted wallpapers while the accent stays vivid."""
    r, g, b = hex_to_rgb(hex_str)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return hsl_to_hex(h, max(0.0, min(1.0, s * factor)), l)


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c: float) -> float:
    c_clamped = max(0.0, min(1.0, c))
    return 12.92 * c_clamped if c_clamped <= 0.0031308 else 1.055 * (c_clamped ** (1.0 / 2.4)) - 0.055


def rgb_to_oklch(r: float, g: float, b: float) -> tuple[float, float, float]:
    lr = srgb_to_linear(r / 255.0)
    lg = srgb_to_linear(g / 255.0)
    lb = srgb_to_linear(b / 255.0)

    l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
    m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
    s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

    l_ = max(0.0, l) ** (1.0 / 3.0)
    m_ = max(0.0, m) ** (1.0 / 3.0)
    s_ = max(0.0, s) ** (1.0 / 3.0)

    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b_ = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    C = math.sqrt(a * a + b_ * b_)
    h = math.degrees(math.atan2(b_, a)) % 360.0
    return L, C, h


def oklch_to_rgb(L: float, C: float, h_deg: float) -> str:
    h_rad = math.radians(h_deg % 360.0)
    a = C * math.cos(h_rad)
    b_ = C * math.sin(h_rad)

    l_ = L + 0.3963377774 * a + 0.2158037573 * b_
    m_ = L - 0.1055613458 * a - 0.0638541728 * b_
    s_ = L - 0.0894841775 * a - 1.2914855480 * b_

    l = l_ ** 3
    m = m_ ** 3
    s = s_ ** 3

    lr = +4.0767434729 * l - 3.3077115913 * m + 0.2309699292 * s
    lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    r = int(round(linear_to_srgb(lr) * 255))
    g = int(round(linear_to_srgb(lg) * 255))
    b = int(round(linear_to_srgb(lb) * 255))
    return f"#{r:02x}{g:02x}{b:02x}"


def generate_harmonized_semantics(dom_h: float, sat_factor: float = 1.0) -> dict[str, str]:
    base_semantics = {
        "red": (0.68, 0.16 * sat_factor, 27.0),
        "orange": (0.75, 0.14 * sat_factor, 55.0),
        "yellow": (0.84, 0.13 * sat_factor, 90.0),
        "green": (0.75, 0.14 * sat_factor, 145.0),
        "cyan": (0.78, 0.11 * sat_factor, 200.0),
        "blue": (0.70, 0.14 * sat_factor, 245.0),
        "pink": (0.75, 0.14 * sat_factor, 330.0),
    }
    res = {}
    for name, (l, c, base_h) in base_semantics.items():
        diff = ((dom_h - base_h + 180.0) % 360.0) - 180.0
        shifted_h = (base_h + diff * 0.12) % 360.0
        res[name] = oklch_to_rgb(l, c, shifted_h)
    return res
