import io
import subprocess
import unittest
from unittest.mock import patch

from tests.helpers import import_script

network_action = import_script("network_action_qr", "network-action.py")


class WifiQrTest(unittest.TestCase):
    def test_vpn_command_uses_requested_enabled_state(self):
        uuid = "vpn-profile-uuid"
        self.assertEqual(
            network_action.vpn_nmcli_command(uuid, True),
            ["nmcli", "connection", "up", "uuid", uuid],
        )
        self.assertEqual(
            network_action.vpn_nmcli_command(uuid, False),
            ["nmcli", "connection", "down", "uuid", uuid],
        )

    def test_vpn_set_request_dispatches_to_requested_nmcli_state(self):
        uuid = "vpn-profile-uuid"
        for requested_state, action, operation in (
            ("on", "vpn-up", "up"),
            ("off", "vpn-down", "down"),
        ):
            with self.subTest(requested_state=requested_state):
                with patch.object(
                    network_action.sys,
                    "argv",
                    ["network-action.py", "vpn-set", uuid, requested_state],
                ), patch.object(network_action, "run_nmcli", return_value=0) as run_nmcli:
                    self.assertEqual(network_action.main(), 0)
                run_nmcli.assert_called_once_with(
                    action,
                    ["nmcli", "connection", operation, "uuid", uuid],
                )

    def test_vpn_already_in_requested_state_is_success(self):
        active = subprocess.CompletedProcess(
            ["nmcli"], 10, stdout="", stderr="Connection 'EmanuelPC' is already activated."
        )
        inactive = subprocess.CompletedProcess(
            ["nmcli"], 10, stdout="", stderr="Connection is not an active connection."
        )
        with patch.object(network_action.subprocess, "run", side_effect=[active, inactive]):
            with patch.object(network_action.sys, "argv", ["network-action.py", "vpn-up", "uuid"]):
                self.assertEqual(network_action.run_nmcli(
                    "vpn-up", ["nmcli", "connection", "up", "uuid", "uuid"]
                ), 0)
            with patch.object(network_action.sys, "argv", ["network-action.py", "vpn-down", "uuid"]):
                self.assertEqual(network_action.run_nmcli(
                    "vpn-down", ["nmcli", "connection", "down", "uuid", "uuid"]
                ), 0)

    def test_nmcli_terse_parser_unescapes_separators(self):
        self.assertEqual(
            network_action.parse_nmcli_terse_line(r"profile\:name:802-11-wireless"),
            ["profile:name", "802-11-wireless"],
        )
        self.assertEqual(
            network_action.parse_nmcli_terse_line(r"a\\b:c"),
            [r"a\b", "c"],
        )

    def test_qr_fields_escape_reserved_characters(self):
        self.assertEqual(
            network_action.escape_wifi_qr_field('a\\b;c,d:e"f'),
            'a\\\\b\\;c\\,d\\:e\\"f',
        )

    def test_uses_connection_uuid_and_actual_ssid(self):
        with patch.object(network_action, "nmcli_query", side_effect=[
            "1234-uuid:802-11-wireless\n",
            r"Real\: Wi-Fi;SSID" + "\n",
            r"pa\:ss;word\\" + "\n",
        ]) as query:
            ssid, psk, payload = network_action.wifi_qr_details()

        self.assertEqual(ssid, "Real: Wi-Fi;SSID")
        self.assertEqual(psk, "pa:ss;word\\")
        self.assertEqual(
            payload,
            'WIFI:T:WPA;S:Real\\: Wi-Fi\\;SSID;P:pa\\:ss\\;word\\\\;;',
        )
        query.assert_any_call(
            "-g", "802-11-wireless.ssid", "connection", "show", "uuid",
            "1234-uuid", show_secrets=False,
        )
        query.assert_any_call(
            "-g", "802-11-wireless-security.psk", "connection", "show", "uuid",
            "1234-uuid", show_secrets=True,
        )

    def test_open_network_is_distinguished_from_secret_read_failure(self):
        with patch.object(network_action, "nmcli_query", side_effect=[
            "open-uuid:802-11-wireless\n",
            "Open Network\n",
            "\n",
            "\n",
        ]):
            _, _, payload = network_action.wifi_qr_details()
        self.assertEqual(payload, "WIFI:T:nopass;S:Open Network;P:;;")

        with patch.object(network_action, "nmcli_query", side_effect=[
            "wep-uuid:802-11-wireless\n",
            "Legacy Network\n",
            "\n",
            "none\n",
            "legacy-key\n",
        ]):
            _, psk, payload = network_action.wifi_qr_details()
        self.assertEqual(psk, "legacy-key")
        self.assertEqual(payload, "WIFI:T:WEP;S:Legacy Network;P:legacy-key;;")

        with patch.object(network_action, "nmcli_query", side_effect=[
            "secured-uuid:802-11-wireless\n",
            "Secured Network\n",
            "\n",
            "wpa-psk\n",
        ]):
            with self.assertRaises(network_action.WifiQrError):
                network_action.wifi_qr_details()

    def test_rejects_unsupported_security_and_nmcli_timeout(self):
        with patch.object(network_action, "nmcli_query", side_effect=[
            "enterprise-uuid:802-11-wireless\n",
            "Enterprise Network\n",
            "\n",
            "wpa-eap\n",
        ]):
            with self.assertRaisesRegex(network_action.WifiQrError, "autenticação"):
                network_action.wifi_qr_details()

        with patch.object(
            network_action.subprocess,
            "run",
            side_effect=subprocess.TimeoutExpired("nmcli", 5),
        ):
            with self.assertRaisesRegex(network_action.WifiQrError, "expirou"):
                network_action.nmcli_query("-f", "UUID,TYPE", "connection", "show", "--active")

    def test_nmcli_nonzero_exit_is_not_interpreted_as_open_wifi(self):
        failed = subprocess.CompletedProcess(["nmcli"], 10, stdout="", stderr="denied")
        with patch.object(network_action.subprocess, "run", return_value=failed):
            with self.assertRaisesRegex(network_action.WifiQrError, "Não foi possível ler"):
                network_action.active_wifi_profile()


    def test_password_for_saved_profile_clears_stale_secret_first(self):
        calls = []

        def fake_run(action, args, input_data=None):
            calls.append((args, input_data))
            return 0

        with patch.object(network_action, "connection_value", return_value="wpa-psk"), \
             patch.object(network_action, "run_nmcli", side_effect=fake_run), \
             patch.object(network_action.sys, "argv",
                          ["network-action.py", "connect-password", "Cafe SSID", "saved-uuid"]), \
             patch.object(network_action.sys, "stdin", io.StringIO("nova-senha\n")):
            self.assertEqual(network_action.main(), 0)

        self.assertEqual(
            calls,
            [
                (["nmcli", "connection", "modify", "saved-uuid", "wifi-sec.psk", ""], None),
                (["nmcli", "--ask", "connection", "up", "uuid", "saved-uuid"], "nova-senha\n"),
            ],
        )

    def test_password_for_open_saved_profile_uses_plain_connect(self):
        calls = []

        def fake_run(action, args, input_data=None):
            calls.append((args, input_data))
            return 0

        with patch.object(network_action, "connection_value", return_value="none"), \
             patch.object(network_action, "run_nmcli", side_effect=fake_run), \
             patch.object(network_action.sys, "argv",
                          ["network-action.py", "connect-password", "Open Net", "open-uuid"]), \
             patch.object(network_action.sys, "stdin", io.StringIO("x\n")):
            self.assertEqual(network_action.main(), 0)

        self.assertEqual(
            calls,
            [(["nmcli", "--ask", "device", "wifi", "connect", "Open Net"], "x\n")],
        )

    def test_password_without_uuid_keeps_legacy_connect(self):
        calls = []

        def fake_run(action, args, input_data=None):
            calls.append((args, input_data))
            return 0

        with patch.object(network_action, "run_nmcli", side_effect=fake_run), \
             patch.object(network_action.sys, "argv",
                          ["network-action.py", "connect-password", "New Net"]), \
             patch.object(network_action.sys, "stdin", io.StringIO("s3cret\n")):
            self.assertEqual(network_action.main(), 0)

        self.assertEqual(
            calls,
            [(["nmcli", "--ask", "device", "wifi", "connect", "New Net"], "s3cret\n")],
        )

    def test_unknown_saved_profile_falls_back_to_plain_connect(self):
        calls = []

        def fake_run(action, args, input_data=None):
            calls.append((args, input_data))
            return 0

        def boom(*args, **kwargs):
            raise network_action.WifiQrError("sem perfil")

        with patch.object(network_action, "connection_value", side_effect=boom), \
             patch.object(network_action, "run_nmcli", side_effect=fake_run), \
             patch.object(network_action.sys, "argv",
                          ["network-action.py", "connect-password", "Gone Net", "gone-uuid"]), \
             patch.object(network_action.sys, "stdin", io.StringIO("s3cret\n")):
            self.assertEqual(network_action.main(), 0)

        self.assertEqual(
            calls,
            [(["nmcli", "--ask", "device", "wifi", "connect", "Gone Net"], "s3cret\n")],
        )

    def test_modify_failure_aborts_before_connect(self):
        with patch.object(network_action, "connection_value", return_value="wpa-psk"), \
             patch.object(network_action, "run_nmcli", return_value=1) as run_nmcli, \
             patch.object(network_action.sys, "argv",
                          ["network-action.py", "connect-password", "Cafe", "saved-uuid"]), \
             patch.object(network_action.sys, "stdin", io.StringIO("pw\n")):
            self.assertEqual(network_action.main(), 1)
        run_nmcli.assert_called_once_with(
            "connect-password",
            ["nmcli", "connection", "modify", "saved-uuid", "wifi-sec.psk", ""],
        )


if __name__ == "__main__":
    unittest.main()
