#!/usr/bin/env python3
import unittest

from tests.helpers import import_script

update_status_json = import_script("update_status_json", "update_status_json.py")


class TestUpdateStatusJson(unittest.TestCase):
    def test_build_payload_keeps_unicode_items(self):
        payload = update_status_json.build_payload(
            ["updates", " 1", "Atualizações disponíveis", "1", "pacote-á"]
        )
        self.assertEqual(payload, {
            "status": "updates",
            "text": " 1",
            "tooltip": "Atualizações disponíveis",
            "count": 1,
            "items": ["pacote-á"],
        })


if __name__ == "__main__":
    unittest.main()
