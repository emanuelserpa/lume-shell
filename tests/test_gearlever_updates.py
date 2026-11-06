#!/usr/bin/env python3
import json
import unittest
from unittest.mock import patch

from tests.helpers import import_script

gearlever = import_script("gearlever_updates", "gearlever-updates.py")


class TestGearLeverUpdates(unittest.TestCase):
    def test_builds_update_status_from_versioned_json(self):
        payload = gearlever.payload_for_updates(json.dumps({
            "schema_version": 1,
            "updates": [
                {"name": "Example App", "path": "/home/user/Applications/example.AppImage"},
                {"name": "Editor", "path": "/home/user/Applications/editor.AppImage"},
            ],
        }))

        self.assertEqual(payload["status"], "updates")
        self.assertEqual(payload["count"], 2)
        self.assertEqual(payload["items"], ["Example App", "Editor"])
        self.assertEqual(payload["text"], "󰏗 2")

    def test_empty_update_list_is_success(self):
        payload = gearlever.payload_for_updates('{"schema_version": 1, "updates": []}')

        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["count"], 0)
        self.assertIn("Tudo atualizado", payload["tooltip"])

    def test_invalid_json_contract_is_reported(self):
        payload = gearlever.payload_for_updates("not json")

        self.assertEqual(payload["status"], "error")
        self.assertIn("JSON inválida", payload["tooltip"])

    def test_nonzero_result_preserves_timeout_state(self):
        payload = gearlever.payload_for_updates("", returncode=124, stderr="Consulta expirou")

        self.assertEqual(payload["status"], "timeout")
        self.assertEqual(payload["count"], 0)
        self.assertIn("Consulta expirou", payload["tooltip"])

    @patch.object(gearlever, "run_command", return_value=(0, '{"schema_version": 1, "updates": []}', ""))
    def test_queries_gear_lever_cli(self, run_command):
        result = gearlever.query_updates("/usr/bin/flatpak")

        self.assertEqual(result["status"], "ok")
        run_command.assert_called_once_with(
            ["/usr/bin/flatpak", "run", gearlever.APP_ID, "--list-updates", "--json"],
            timeout=120,
            timeout_code=124,
            timeout_message="A consulta do Gear Lever expirou.",
        )


if __name__ == "__main__":
    unittest.main()
