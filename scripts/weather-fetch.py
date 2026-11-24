#!/usr/bin/env python3
import datetime
import html
import json
import math
import os
import tempfile
import subprocess
from pathlib import Path

from network_utils import prefer_ipv4_resolution
from weather_state_utils import (
    fetch_https_geolocation,
    is_auto_geo_disabled,
    load_sanitized_weather_state,
    validate_coords,
)

prefer_ipv4_resolution()

import requests

WEATHER_CODES = {
    # Nerd Fonts 3.x / Material Design weather glyphs
    # Clear / cloudy
    "113": "󰖙",  # sunny / clear
    "116": "󰖕",  # partly cloudy
    "119": "󰖐",  # cloudy
    "122": "󰖐",  # overcast
    "143": "󰖑",  # mist

    # Rain / drizzle
    "176": "󰖗",
    "263": "󰖗",
    "266": "󰖗",
    "281": "󰖗",
    "284": "󰖗",
    "293": "󰖖",
    "296": "󰖖",
    "299": "󰖖",
    "302": "󰖖",
    "305": "󰖖",
    "308": "󰖖",
    "311": "󰖖",
    "314": "󰖖",
    "353": "󰖗",
    "356": "󰖖",
    "359": "󰖖",

    # Thunder
    "200": "󰙾",
    "386": "󰙾",
    "389": "󰙾",

    # Snow / sleet / hail
    "179": "󰖘",
    "182": "󰖘",
    "185": "󰖘",
    "227": "󰖘",
    "230": "󰖘",
    "317": "󰖘",
    "320": "󰖘",
    "323": "󰖘",
    "326": "󰖘",
    "329": "󰖘",
    "332": "󰖘",
    "335": "󰖘",
    "338": "󰖘",
    "350": "󰖘",
    "362": "󰖘",
    "365": "󰖘",
    "368": "󰖘",
    "371": "󰖘",
    "374": "󰖘",
    "377": "󰖘",
    "392": "󰙾",
    "395": "󰙾",

    # Dense fog
    "248": "󰖑",
    "260": "󰖑",
}

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "lume-shell"
CACHE_FILE = CACHE_DIR / "weather.json"

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
STATE_FILE = STATE_DIR / "weather.json"


WMO_DESCRIPTION_PT = {
    0: "Céu limpo",
    1: "Predominantemente limpo",
    2: "Parcialmente nublado",
    3: "Nublado",
    45: "Nevoeiro",
    48: "Nevoeiro com geada",
    51: "Garoa fraca",
    53: "Garoa moderada",
    55: "Garoa intensa",
    56: "Garoa congelante fraca",
    57: "Garoa congelante intensa",
    61: "Chuva fraca",
    63: "Chuva moderada",
    65: "Chuva forte",
    66: "Chuva congelante fraca",
    67: "Chuva congelante forte",
    71: "Neve fraca",
    73: "Neve moderada",
    75: "Neve forte",
    77: "Grãos de neve",
    80: "Pancadas de chuva fracas",
    81: "Pancadas de chuva",
    82: "Pancadas de chuva fortes",
    85: "Pancadas de neve fracas",
    86: "Pancadas de neve fortes",
    95: "Trovoadas",
    96: "Trovoadas com granizo",
    99: "Trovoadas fortes com granizo",
}


def wmo_to_internal(code: int) -> str:
    if code == 0:
        return "113"
    if code in (1, 2):
        return "116"
    if code == 3:
        return "122"
    if code in (45, 48):
        return "248"
    if code in (51, 53, 55, 56, 57):
        return "266"
    if code in (61, 63, 65, 66, 67):
        return "296"
    if code in (71, 73, 75, 77):
        return "323"
    if code in (80, 81, 82):
        return "353"
    if code in (85, 86):
        return "368"
    if code in (95, 96, 99):
        return "389"
    return "119"


def weather_description_pt(code: int) -> str:
    return WMO_DESCRIPTION_PT.get(code, "Condição desconhecida")


def get_day_label(date_str: str, index: int) -> str:
    if index == 0:
        return "Hoje"
    if index == 1:
        return "Amanhã"

    try:
        dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
        weekdays = [
            "Segunda", "Terça", "Quarta", "Quinta",
            "Sexta", "Sábado", "Domingo",
        ]
        return f"{weekdays[dt.weekday()]} ({dt:%d/%m})"
    except ValueError:
        return date_str


def load_city_state() -> dict:
    return load_sanitized_weather_state(STATE_FILE)


def get_auto_location(state: dict | None = None) -> tuple[str, str]:
    city_name = "Localização automática"
    location_query = ""

    if is_auto_geo_disabled(state):
        return city_name, location_query

    resolved = fetch_https_geolocation(
        timeout=5.0,
        user_agent="Quickshell Weather",
    )
    if resolved is not None:
        resolved_city, lat, lon = resolved
        city_name = resolved_city or city_name
        location_query = f"{lat},{lon}"

    return city_name, location_query


def get_location() -> tuple[str, str, str]:
    state = load_city_state()
    selected = state.get("selected", "auto")

    if selected != "auto":
        for city in state.get("cities", []):
            if city.get("id") != selected:
                continue

            coords = validate_coords(city.get("latitude"), city.get("longitude"))
            if coords is None:
                break

            name = city.get("name") or "Cidade salva"
            region = city.get("region") or ""
            display = f"{name}, {region}" if region else name
            return display, f"{coords[0]},{coords[1]}", selected

    if is_auto_geo_disabled(state):
        raise RuntimeError("Localização automática desativada")

    name, query = get_auto_location(state)
    return name, query, "auto"


def get_period(hourly_data: dict, time_str: str) -> tuple[str, str]:
    item = hourly_data.get(time_str, {})

    if not item:
        return "󰖐", "--°C"

    icon = WEATHER_CODES.get(str(item.get("weatherCode")), "󰖐")
    temp = f"{item.get('tempC', '--')}°C"

    return icon, temp


def save_cache(city_name: str, city_id: str, data: dict) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    cache_data = {
        "city_name": city_name,
        "city_id": city_id,
        "updated_at": datetime.datetime.now().isoformat(timespec="seconds"),
        "weather_data": data,
    }

    # Atomic replacement keeps concurrent readers from seeing partial JSON.
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=CACHE_DIR,
        prefix="weather.",
        suffix=".tmp",
        delete=False,
    ) as temp_file:
        json.dump(cache_data, temp_file, ensure_ascii=False)
        temp_file.write("\n")
        temp_name = temp_file.name

    os.replace(temp_name, CACHE_FILE)


def _safe_int(value, default: int = -1) -> int:
    if isinstance(value, bool) or value is None:
        return default
    try:
        num = int(value)
        return num
    except (TypeError, ValueError, OverflowError):
        return default


def _safe_round(value, default=0):
    if isinstance(value, bool) or value is None:
        return default
    try:
        num = float(value)
    except (TypeError, ValueError, OverflowError):
        return default
    if not math.isfinite(num):
        return default
    return round(num)


def load_cache() -> dict | None:
    try:
        with CACHE_FILE.open(encoding="utf-8") as file:
            cache = json.load(file)

        if not isinstance(cache, dict):
            return None
        weather_data = cache.get("weather_data")
        if not isinstance(weather_data, dict):
            return None
        conditions = weather_data.get("current_condition")
        if not isinstance(conditions, list) or not conditions or not isinstance(conditions[0], dict):
            return None

        return cache
    except (OSError, json.JSONDecodeError, ValueError):
        return None


def fetch_weather() -> tuple[str, str, dict]:
    city_name, location_query, city_id = get_location()

    if not location_query or "," not in location_query:
        raise RuntimeError("Localização indisponível")

    lat_str, lon_str = location_query.split(",", 1)
    coords = validate_coords(lat_str, lon_str)
    if coords is None:
        raise RuntimeError("Coordenadas inválidas")
    lat, lon = str(coords[0]), str(coords[1])

    proc = subprocess.run(
        [
            "curl",
            "--fail",
            "--silent",
            "--show-error",
            "--location",
            "--compressed",
            "--connect-timeout", "8",
            "--max-time", "15",
            "--retry", "2",
            "--retry-delay", "1",
            "-G",
            "https://api.open-meteo.com/v1/forecast",
            "--data-urlencode", f"latitude={lat}",
            "--data-urlencode", f"longitude={lon}",
            "--data-urlencode", "current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m",
            "--data-urlencode", "hourly=temperature_2m,weather_code",
            "--data-urlencode", "daily=temperature_2m_max,temperature_2m_min,weather_code",
            "--data-urlencode", "timezone=auto",
            "--data-urlencode", "forecast_days=5",
        ],
        text=True,
        capture_output=True,
        timeout=20,
    )

    if proc.returncode != 0:
        detail = proc.stderr.strip() or f"curl exit {proc.returncode}"
        raise RuntimeError(detail)

    raw = json.loads(proc.stdout)
    if not isinstance(raw, dict):
        raise ValueError("Resposta JSON inesperada")

    current = raw.get("current")
    current = current if isinstance(current, dict) else {}
    hourly = raw.get("hourly")
    hourly = hourly if isinstance(hourly, dict) else {}
    daily = raw.get("daily")
    daily = daily if isinstance(daily, dict) else {}

    current_code = _safe_int(current.get("weather_code"), -1)

    transformed = {
        "current_time": str(current.get("time") or ""),
        "current_condition": [{
            "temp_C": _safe_round(current.get("temperature_2m"), 0),
            "FeelsLikeC": _safe_round(current.get("apparent_temperature"), 0),
            "humidity": _safe_round(current.get("relative_humidity_2m"), 0),
            "windspeedKmph": _safe_round(current.get("wind_speed_10m"), 0),
            "weatherCode": wmo_to_internal(current_code),
            "lang_pt": [{"value": weather_description_pt(current_code)}],
        }],
        "weather": [],
    }

    hourly_times = hourly.get("time") if isinstance(hourly.get("time"), list) else []
    hourly_temps = hourly.get("temperature_2m") if isinstance(hourly.get("temperature_2m"), list) else []
    hourly_codes = hourly.get("weather_code") if isinstance(hourly.get("weather_code"), list) else []

    hourly_by_date = {}

    for i, iso_time in enumerate(hourly_times):
        if not isinstance(iso_time, str):
            continue
        try:
            dt = datetime.datetime.fromisoformat(iso_time)
        except ValueError:
            continue

        date_key = dt.date().isoformat()
        hour_key = f"{dt.hour}00"

        temp = hourly_temps[i] if i < len(hourly_temps) else "--"
        code = hourly_codes[i] if i < len(hourly_codes) else -1

        hourly_by_date.setdefault(date_key, []).append({
            "time": hour_key,
            "tempC": _safe_round(temp, "--") if temp != "--" else "--",
            "weatherCode": wmo_to_internal(_safe_int(code, -1)),
        })

    dates = daily.get("time") if isinstance(daily.get("time"), list) else []
    maxes = daily.get("temperature_2m_max") if isinstance(daily.get("temperature_2m_max"), list) else []
    mins = daily.get("temperature_2m_min") if isinstance(daily.get("temperature_2m_min"), list) else []

    for i, date_key in enumerate(dates[:5]):
        if not isinstance(date_key, str):
            continue
        transformed["weather"].append({
            "date": date_key,
            "maxtempC": _safe_round(maxes[i], "--") if i < len(maxes) else "--",
            "mintempC": _safe_round(mins[i], "--") if i < len(mins) else "--",
            "hourly": hourly_by_date.get(date_key, []),
        })

    return city_name, city_id, transformed


def _esc(value) -> str:
    return html.escape(str(value), quote=True)


def build_output(cache: dict, stale: bool) -> dict:
    city_name = str(cache.get("city_name") or "Localização atual")
    data = cache["weather_data"]

    current = data["current_condition"][0]
    lang_pt = current.get("lang_pt")
    weather_desc_list = current.get("weatherDesc")
    pt_val = lang_pt[0].get("value") if isinstance(lang_pt, list) and lang_pt and isinstance(lang_pt[0], dict) else None
    en_val = weather_desc_list[0].get("value") if isinstance(weather_desc_list, list) and weather_desc_list and isinstance(weather_desc_list[0], dict) else None

    weather_desc = str(pt_val or en_val or "Clima desconhecido").capitalize()

    temp_c = current.get("temp_C", "--")
    feels_like = current.get("FeelsLikeC", "--")
    humidity = current.get("humidity", "--")
    wind = current.get("windspeedKmph", "--")

    current_icon = WEATHER_CODES.get(
        str(current.get("weatherCode")),
        "󰖐",
    )

    tooltip_lines = [
        f"<b>{_esc(city_name)}: {_esc(weather_desc)}</b>",
        f"Sensação: {_esc(feels_like)}°C · Umidade: {_esc(humidity)}% · Vento: {_esc(wind)} km/h",
        "",
    ]

    hours = []

    try:
        current_time = datetime.datetime.fromisoformat(
            str(data.get("current_time") or "")
        )
    except ValueError:
        current_time = datetime.datetime.now().replace(
            minute=0, second=0, microsecond=0
        )

    weather_days = data.get("weather") if isinstance(data.get("weather"), list) else []
    all_hourly = []
    for day in weather_days:
        if not isinstance(day, dict):
            continue
        date_key = str(day.get("date") or "")
        day_hourly = day.get("hourly") if isinstance(day.get("hourly"), list) else []
        for item in day_hourly:
            if not isinstance(item, dict):
                continue
            raw_hour = str(item.get("time") or "")
            try:
                hour = int(raw_hour[:-2]) if raw_hour.endswith("00") else int(raw_hour)
                dt = datetime.datetime.fromisoformat(
                    f"{date_key}T{hour:02d}:00"
                )
            except (ValueError, TypeError):
                continue

            if dt >= current_time.replace(minute=0, second=0, microsecond=0):
                all_hourly.append((dt, item))

    all_hourly.sort(key=lambda pair: pair[0])

    for dt, item in all_hourly[:6]:
        hours.append({
            "label": f"{dt.hour:02d}h",
            "icon": WEATHER_CODES.get(
                str(item.get("weatherCode")),
                "󰖐",
            ),
            "temp": str(item.get("tempC", "--")),
        })

    days = []

    for i, day in enumerate(weather_days[:5]):
        if not isinstance(day, dict):
            continue
        day_title = get_day_label(str(day.get("date") or ""), i)

        day_hourly = day.get("hourly") if isinstance(day.get("hourly"), list) else []
        hourly_data = {
            item.get("time"): item
            for item in day_hourly
            if isinstance(item, dict) and item.get("time") is not None
        }

        morning_icon, morning_temp = get_period(hourly_data, "900")
        afternoon_icon, afternoon_temp = get_period(hourly_data, "1200")
        night_icon, night_temp = get_period(hourly_data, "1800")
        dawn_icon, dawn_temp = get_period(hourly_data, "2100")

        tooltip_lines.extend([
            f"<b>{_esc(day_title)}</b>",
            (
                f"Manhã {_esc(morning_icon)} {_esc(morning_temp)}   "
                f"Tarde {_esc(afternoon_icon)} {_esc(afternoon_temp)}"
            ),
            (
                f"Noite {_esc(night_icon)} {_esc(night_temp)}   "
                f"Madruga {_esc(dawn_icon)} {_esc(dawn_temp)}"
            ),
            "",
        ])

        days.append({
            "label": day_title,
            "date": day.get("date", ""),
            "maxtemp": day.get("maxtempC", "--"),
            "mintemp": day.get("mintempC", "--"),
            "periods": [
                {"label": "Manhã", "icon": morning_icon, "temp": morning_temp},
                {"label": "Tarde", "icon": afternoon_icon, "temp": afternoon_temp},
                {"label": "Noite", "icon": night_icon, "temp": night_temp},
                {"label": "Madruga", "icon": dawn_icon, "temp": dawn_temp},
            ],
        })

    updated_at = cache.get("updated_at", "")
    if updated_at:
        try:
            updated = datetime.datetime.fromisoformat(str(updated_at))
            tooltip_lines.extend([
                f"<i>Atualizado: {_esc(f'{updated:%d/%m às %H:%M}')}</i>",
            ])
        except ValueError:
            pass

    if stale:
        tooltip_lines.extend([
            "<i>Sem conexão: exibindo última previsão válida.</i>",
        ])

    tooltip_text = "<tt>" + "\n".join(tooltip_lines).strip() + "</tt>"

    return {
        "text": f"{current_icon} {temp_c}°C",
        "tooltip": tooltip_text,
        "class": "weather stale" if stale else "weather",
        "city": city_name,
        "city_id": cache.get("city_id", "auto"),
        "description": weather_desc,
        "icon": current_icon,
        "temperature": str(temp_c),
        "feels_like": str(feels_like),
        "humidity": str(humidity),
        "wind": str(wind),
        "hours": hours,
        "days": days,
        "updated_at": cache.get("updated_at", ""),
        "stale": stale,
    }


def main() -> None:
    updated_successfully = False
    error_message = ""
    attempted_at = datetime.datetime.now().isoformat(timespec="seconds")

    try:
        city_name, city_id, data = fetch_weather()
        save_cache(city_name, city_id, data)
        updated_successfully = True
    except requests.RequestException as exc:
        error_message = f"Falha de localização: {exc.__class__.__name__}"
    except (subprocess.SubprocessError, RuntimeError) as exc:
        detail = str(exc).strip()
        if len(detail) > 90:
            detail = detail[:87] + "..."
        error_message = "Falha ao consultar Open-Meteo" + (f": {detail}" if detail else "")
    except (json.JSONDecodeError, ValueError, KeyError, IndexError, TypeError, AttributeError) as exc:
        error_message = f"Resposta inválida: {exc.__class__.__name__}"

    cache = load_cache()

    # Nunca reaproveita previsão de outra cidade depois de uma troca.
    # Ex.: cidade A estava em cache, usuário muda para cidade B sem rede.
    selected_id = str(load_city_state().get("selected", "auto"))
    if cache is not None and str(cache.get("city_id", "auto")) != selected_id:
        cache = None
        if not error_message:
            error_message = "Sem previsão em cache para a cidade selecionada"

    # Só mostra "--°C" se não há cache válido para a cidade atual.
    if cache is None:
        output = {
            "text": "󰖐 --°C",
            "tooltip": "Previsão indisponível — aguardando primeira atualização.",
            "class": "weather offline",
            "city": "Localização automática",
            "city_id": "auto",
            "description": "Previsão indisponível",
            "icon": "󰖐",
            "temperature": "--",
            "feels_like": "--",
            "humidity": "--",
            "wind": "--",
            "hours": [],
            "days": [],
            "updated_at": "",
            "attempted_at": attempted_at,
            "stale": True,
            "error": error_message or "Nenhum dado válido recebido",
        }
    else:
        output = build_output(cache, stale=not updated_successfully)
        output["attempted_at"] = attempted_at
        output["error"] = error_message

    print(json.dumps(output, ensure_ascii=False))


if __name__ == "__main__":
    main()
