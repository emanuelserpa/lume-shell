"""Shared validation, state recovery, and HTTPS geolocation helpers for weather/nightlight."""

import json
import math
import os
import re
import sys
from pathlib import Path

_SCRIPT_DIR = str(Path(__file__).resolve().parent)
if _SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _SCRIPT_DIR)

from lume_paths import migrate_file

CITY_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
HTTPS_GEO_PROVIDERS = (
    "https://ipwho.is/",
    "https://ipapi.co/json/",
)
DISABLE_AUTO_GEO_ENV_VARS = (
    "LUME_WEATHER_DISABLE_AUTO_GEO",
    "LUME_DISABLE_AUTO_GEO",
)


def validate_coords(lat, lon):
    """Return rounded (lat, lon) floats if finite and in [-90, 90] x [-180, 180], else None."""
    if isinstance(lat, bool) or isinstance(lon, bool) or lat is None or lon is None:
        return None
    try:
        f_lat = float(lat)
        f_lon = float(lon)
    except (TypeError, ValueError, OverflowError):
        return None
    if not (math.isfinite(f_lat) and math.isfinite(f_lon)):
        return None
    if not (-90.0 <= f_lat <= 90.0) or not (-180.0 <= f_lon <= 180.0):
        return None
    return round(f_lat, 5), round(f_lon, 5)


def is_valid_city_id(value) -> bool:
    """Validate a saved city identifier (disallows control chars, slashes, 'auto', and '..')."""
    if not isinstance(value, str):
        return False
    if not value or value == "auto" or ".." in value:
        return False
    return bool(CITY_ID_RE.match(value))


def _clean_label(value, max_len: int = 120) -> str:
    if not isinstance(value, str):
        return ""
    cleaned = "".join(ch for ch in value if ch.isprintable() and ch not in "\r\n\t").strip()
    return cleaned[:max_len]


def sanitize_city_entry(raw) -> dict | None:
    """Validate and normalize one saved city record; returns None if invalid."""
    if not isinstance(raw, dict):
        return None
    cid = raw.get("id")
    if not is_valid_city_id(cid):
        return None
    coords = validate_coords(raw.get("latitude"), raw.get("longitude"))
    if coords is None:
        return None
    name = _clean_label(raw.get("name"))
    if not name:
        return None
    region = _clean_label(raw.get("region"))
    country = _clean_label(raw.get("country"))
    return {
        "id": cid,
        "name": name,
        "region": region,
        "country": country,
        "latitude": coords[0],
        "longitude": coords[1],
    }


def _parse_auto_location_flag(state: dict) -> bool:
    if "disable_auto_location" in state:
        raw_disabled = state.get("disable_auto_location")
        if isinstance(raw_disabled, bool):
            return not raw_disabled
    raw_enabled = state.get("auto_location")
    if isinstance(raw_enabled, bool):
        return raw_enabled
    return True


def sanitize_weather_state(raw) -> dict:
    """Normalize a parsed weather state dict and gracefully drop malformed entries."""
    default = {"selected": "auto", "cities": [], "auto_location": True}
    if not isinstance(raw, dict):
        return default

    auto_location = _parse_auto_location_flag(raw)

    raw_cities = raw.get("cities")
    sanitized_cities = []
    seen_ids = set()
    if isinstance(raw_cities, list):
        for entry in raw_cities:
            city = sanitize_city_entry(entry)
            if city is None or city["id"] in seen_ids:
                continue
            seen_ids.add(city["id"])
            sanitized_cities.append(city)

    selected_raw = raw.get("selected")
    if isinstance(selected_raw, str) and (selected_raw == "auto" or selected_raw in seen_ids):
        selected = selected_raw
    else:
        selected = "auto"

    return {
        "selected": selected,
        "cities": sanitized_cities,
        "auto_location": auto_location,
    }


def load_sanitized_weather_state(state_file: Path) -> dict:
    """Load and validate weather.json, recovering cleanly on malformed JSON or schemas."""
    migrate_file(state_file)
    try:
        with state_file.open(encoding="utf-8") as handle:
            raw = json.load(handle)
    except (OSError, json.JSONDecodeError, ValueError):
        return {"selected": "auto", "cities": [], "auto_location": True}
    return sanitize_weather_state(raw)


def is_auto_geo_disabled(state: dict | None = None) -> bool:
    """Return True when automatic IP geolocation is disabled via env or state."""
    for var in DISABLE_AUTO_GEO_ENV_VARS:
        val = os.environ.get(var, "").strip().lower()
        if val in ("1", "true", "yes", "on"):
            return True
    if isinstance(state, dict) and state.get("auto_location") is False:
        return True
    return False


def _default_https_get(url: str, timeout: float, user_agent: str):
    import requests

    resp = requests.get(
        url,
        timeout=timeout,
        headers={"User-Agent": user_agent},
    )
    resp.raise_for_status()
    return resp.json()


def fetch_https_geolocation(
    timeout: float = 5.0,
    user_agent: str = "lume-shell Weather",
    get_fn=None,
) -> tuple[str, float, float] | None:
    """Query HTTPS IP-geolocation providers and return (city, lat, lon) with validated coords."""
    fetcher = get_fn or _default_https_get
    for url in HTTPS_GEO_PROVIDERS:
        if not url.startswith("https://"):
            continue
        try:
            payload = fetcher(url, timeout, user_agent)
        except Exception:
            continue
        if not isinstance(payload, dict):
            continue
        if payload.get("success") is False or payload.get("error"):
            continue
        coords = validate_coords(payload.get("latitude"), payload.get("longitude"))
        if coords is None:
            continue
        city = _clean_label(payload.get("city")) or "Localização automática"
        return city, coords[0], coords[1]
    return None
