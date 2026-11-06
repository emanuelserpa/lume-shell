#!/usr/bin/env python3
import datetime
import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "nightlight-manager.py"
SPEC = importlib.util.spec_from_file_location("nightlight_manager", SCRIPT_PATH)
nm = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(nm)


class TestNightLightManager(unittest.TestCase):
    def test_get_sun_times_coordinates(self):
        # Tururu, CE: lat -3.58083, lon -39.43722
        sunrise, sunset = nm.get_sun_times(-3.58083, -39.43722, datetime.date(2026, 9, 20))
        self.assertRegex(sunrise, r"^\d{2}:\d{2}$")
        self.assertRegex(sunset, r"^\d{2}:\d{2}$")
        sh, sm = map(int, sunrise.split(":"))
        eh, em = map(int, sunset.split(":"))
        self.assertTrue(4 <= sh <= 6)
        self.assertTrue(16 <= eh <= 19)

    def test_is_night_time_detection(self):
        # Sunrise 05:30, Sunset 17:30
        sunrise = "05:30"
        sunset = "17:30"
        self.assertTrue(nm.is_night_time(sunrise, sunset, datetime.time(2, 0)))    # deep night
        self.assertTrue(nm.is_night_time(sunrise, sunset, datetime.time(5, 29)))   # right before sunrise
        self.assertFalse(nm.is_night_time(sunrise, sunset, datetime.time(5, 30)))  # sunrise moment (day starts)
        self.assertFalse(nm.is_night_time(sunrise, sunset, datetime.time(12, 0)))  # midday
        self.assertFalse(nm.is_night_time(sunrise, sunset, datetime.time(17, 29))) # right before sunset
        self.assertTrue(nm.is_night_time(sunrise, sunset, datetime.time(17, 30)))  # sunset moment (night starts)
        self.assertTrue(nm.is_night_time(sunrise, sunset, datetime.time(23, 59)))  # midnight boundary

    def test_temperature_ramp(self):
        sunrise, sunset = "05:30", "17:30"
        self.assertEqual(nm.temperature_at_time(sunrise, sunset, datetime.time(17, 30)), 6500)
        self.assertEqual(nm.temperature_at_time(sunrise, sunset, datetime.time(18, 15)), 5250)
        self.assertEqual(nm.temperature_at_time(sunrise, sunset, datetime.time(19, 0)), 4000)
        self.assertEqual(nm.temperature_at_time(sunrise, sunset, datetime.time(23, 0)), 4000)
        self.assertEqual(nm.temperature_at_time(sunrise, sunset, datetime.time(4, 45)), 5250)
        self.assertEqual(nm.temperature_at_time(sunrise, sunset, datetime.time(5, 30)), 6500)

    def test_hyprsunset_profiles_have_five_minute_ramps(self):
        profiles = nm.build_hyprsunset_profiles("05:30", "17:30")
        indexed = dict(profiles)
        self.assertEqual(indexed["17:30"], 6500)
        self.assertEqual(indexed["19:00"], 4000)
        self.assertEqual(indexed["04:00"], 4000)
        self.assertIsNone(indexed["05:30"])
        self.assertEqual(len(profiles), 38)

    def test_get_weather_location_structure(self):
        loc = nm.get_weather_location()
        self.assertIn("city", loc)
        self.assertIn("latitude", loc)
        self.assertIn("longitude", loc)
        self.assertIsInstance(loc["latitude"], float)
        self.assertIsInstance(loc["longitude"], float)

    def test_status_contract(self):
        res = nm.get_status()
        self.assertTrue(res["ok"])
        self.assertIsNone(res["error"])
        self.assertIn("enabled", res)
        self.assertIn("active", res)
        self.assertIn("is_night", res)
        self.assertIn("backend", res)
        self.assertIn("city", res)
        self.assertIn("sunrise", res)
        self.assertIn("sunset", res)
        self.assertIn("current_temp", res)

    def test_detect_backend(self):
        backend = nm.detect_backend()
        self.assertIn(backend, ["hyprsunset", "wlsunset", "none"])


if __name__ == "__main__":
    unittest.main()
