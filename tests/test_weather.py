#!/usr/bin/env python3
"""Offline regression tests for weather/geolocation hardening (Issue #21)."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS_DIR / filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


import weather_state_utils as wsu
weather_fetch = load_module("weather_fetch", "weather-fetch.py")
weather_cities = load_module("weather_cities", "weather-cities.py")
nightlight_mgr = load_module("nightlight_manager", "nightlight-manager.py")


class TestWeatherStateAndCoords(unittest.TestCase):
    def test_validate_coords_rejects_bad_types_nan_and_out_of_range(self):
        self.assertEqual(wsu.validate_coords(-3.580834, -39.437221), (-3.58083, -39.43722))
        self.assertEqual(wsu.validate_coords("-90", "180"), (-90.0, 180.0))
        for bad_lat, bad_lon in [
            (None, 0),
            (0, None),
            (True, 0),
            (0, False),
            (float("nan"), 0),
            (0, float("inf")),
            (-90.1, 0),
            (91, 0),
            (0, -180.1),
            (0, 180.1),
            ("abc", "def"),
        ]:
            self.assertIsNone(wsu.validate_coords(bad_lat, bad_lon), (bad_lat, bad_lon))

    def test_is_valid_city_id_rejects_traversal_auto_and_controls(self):
        self.assertTrue(wsu.is_valid_city_id("fortaleza-ceara-brasil--3.717--38.543"))
        for bad_id in ["", "auto", "../etc", "a/b", "bad id", "a\nb", None, 123]:
            self.assertFalse(wsu.is_valid_city_id(bad_id), repr(bad_id))

    def test_sanitize_weather_state_recovers_from_malformed_configs(self):
        # Completely wrong types
        self.assertEqual(
            wsu.sanitize_weather_state(["not", "a", "dict"]),
            {"selected": "auto", "cities": [], "auto_location": True},
        )
        # Mixed valid/corrupt cities + invalid selected fallback + disable_auto_location
        raw = {
            "selected": {"bad": "type"},
            "disable_auto_location": True,
            "cities": [
                "string-not-dict",
                {"id": "bad/id", "name": "X", "latitude": 0, "longitude": 0},
                {"id": "out-of-range", "name": "Mars", "latitude": 120, "longitude": 0},
                {"id": "nan-coord", "name": "NaN", "latitude": "nan", "longitude": 10},
                {"id": "empty-name", "name": "   ", "latitude": 10, "longitude": 10},
                {
                    "id": "valid-city-1.0-2.0",
                    "name": "Fortaleza",
                    "region": "Ceara",
                    "country": "Brasil",
                    "latitude": -3.717,
                    "longitude": -38.543,
                },
                # Duplicate ID should be ignored
                {
                    "id": "valid-city-1.0-2.0",
                    "name": "Dup",
                    "latitude": 1.0,
                    "longitude": 2.0,
                },
            ],
        }
        sanitized = wsu.sanitize_weather_state(raw)
        self.assertEqual(sanitized["selected"], "auto")
        self.assertFalse(sanitized["auto_location"])
        self.assertEqual(len(sanitized["cities"]), 1)
        self.assertEqual(sanitized["cities"][0]["name"], "Fortaleza")

        # Unknown selected ID falls back to auto
        raw_missing_selected = {
            "selected": "does-not-exist",
            "cities": [raw["cities"][5]],
        }
        self.assertEqual(wsu.sanitize_weather_state(raw_missing_selected)["selected"], "auto")

        # Corrupt JSON file recovers cleanly
        with tempfile.TemporaryDirectory() as tmp:
            bad_file = Path(tmp) / "weather.json"
            bad_file.write_text("{corrupt json", encoding="utf-8")
            self.assertEqual(
                wsu.load_sanitized_weather_state(bad_file),
                {"selected": "auto", "cities": [], "auto_location": True},
            )


class TestWeatherHttpsGeoAndTooltips(unittest.TestCase):
    def test_https_geolocation_rejects_invalid_coords_and_never_uses_http(self):
        seen_urls = []

        def fake_get(url, _timeout, _ua):
            seen_urls.append(url)
            if "ipwho.is" in url:
                return {"success": True, "city": "BadCoords", "latitude": 999, "longitude": 0}
            return {"city": "Fortaleza", "latitude": -3.717, "longitude": -38.543}

        result = wsu.fetch_https_geolocation(get_fn=fake_get)
        self.assertTrue(seen_urls)
        self.assertTrue(all(u.startswith("https://") for u in seen_urls))
        self.assertEqual(result, ("Fortaleza", -3.717, -38.543))

    def test_auto_location_can_be_disabled_without_network(self):
        with mock.patch.object(weather_fetch, "fetch_https_geolocation") as geo_mock:
            with mock.patch.dict(os.environ, {"LUME_WEATHER_DISABLE_AUTO_GEO": "1"}):
                city, query = weather_fetch.get_auto_location({"selected": "auto", "cities": []})
                self.assertEqual(query, "")
                self.assertEqual(city, "Localização automática")
            geo_mock.assert_not_called()

            city, query = weather_fetch.get_auto_location({"auto_location": False})
            self.assertEqual(query, "")
            geo_mock.assert_not_called()

    def test_nightlight_respects_disabled_auto_geo_and_falls_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            state_file = Path(tmp) / "weather.json"
            state_file.write_text(json.dumps({"selected": "auto", "auto_location": False}), encoding="utf-8")
            with mock.patch.object(nightlight_mgr, "WEATHER_STATE_FILE", state_file), \
                 mock.patch.object(nightlight_mgr, "fetch_https_geolocation") as geo_mock:
                loc = nightlight_mgr.get_weather_location()
                geo_mock.assert_not_called()
                self.assertEqual(loc["source"], "fallback")

    def test_tooltip_html_escapes_external_values(self):
        cache = {
            "city_name": '<script>alert("xss")</script> & Cia',
            "city_id": "test-1",
            "updated_at": "2026-11-24T10:00:00",
            "weather_data": {
                "current_time": "2026-11-24T10:00:00",
                "current_condition": [{
                    "temp_C": 28,
                    "FeelsLikeC": '30<b>"',
                    "humidity": 70,
                    "windspeedKmph": 12,
                    "weatherCode": "113",
                    "lang_pt": [{"value": "sol & <calor>"}],
                }],
                "weather": [{
                    "date": "2026-11-24",
                    "maxtempC": 31,
                    "mintempC": 24,
                    "hourly": [],
                }],
            },
        }
        out = weather_fetch.build_output(cache, stale=False)
        self.assertNotIn("<script>", out["tooltip"])
        self.assertIn("&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt; &amp; Cia", out["tooltip"])
        self.assertIn("&lt;calor&gt;", out["tooltip"])
        self.assertIn("30&lt;b&gt;&quot;", out["tooltip"])

    def test_malformed_cache_is_rejected_gracefully(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache_file = Path(tmp) / "weather-cache.json"
            cache_file.write_text(json.dumps({"weather_data": {"current_condition": []}}), encoding="utf-8")
            with mock.patch.object(weather_fetch, "CACHE_FILE", cache_file):
                self.assertIsNone(weather_fetch.load_cache())


class TestWeatherCitiesCliValidation(unittest.TestCase):
    def test_add_rejects_invalid_id_or_coords_and_auto_geo_persists(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, XDG_STATE_HOME=tmp)
            script = str(SCRIPTS_DIR / "weather-cities.py")

            bad_coord = subprocess.run(
                [sys.executable, "-B", script, "add", "--id", "c1", "--name", "Test", "--latitude", "95", "--longitude", "10"],
                env=env, capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(bad_coord.returncode, 0)
            self.assertFalse(json.loads(bad_coord.stdout)["ok"])

            bad_id = subprocess.run(
                [sys.executable, "-B", script, "add", "--id", "../evil", "--name", "Test", "--latitude", "10", "--longitude", "10"],
                env=env, capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(bad_id.returncode, 0)
            self.assertFalse(json.loads(bad_id.stdout)["ok"])

            off = subprocess.run(
                [sys.executable, "-B", script, "auto-geo", "off"],
                env=env, capture_output=True, text=True, check=False,
            )
            self.assertEqual(off.returncode, 0, off.stderr)
            self.assertFalse(json.loads(off.stdout)["auto_location"])


if __name__ == "__main__":
    unittest.main()
