import unittest
from unittest.mock import patch

from tests.helpers import import_script

network_ping = import_script("network_ping", "network-ping.py")


class NetworkPingTest(unittest.TestCase):
    def test_parse_ping_ms_handles_english_portuguese_and_rounding(self):
        self.assertEqual(
            network_ping.parse_ping_ms("64 bytes from 1.1.1.1: icmp_seq=1 ttl=58 time=14.6 ms"),
            15,
        )
        self.assertEqual(
            network_ping.parse_ping_ms("64 bytes de 1.1.1.1: icmp_seq=1 ttl=58 tempo=12.2 ms"),
            12,
        )
        self.assertEqual(
            network_ping.parse_ping_ms("64 bytes from 1.1.1.1: icmp_seq=1 ttl=64 time<1 ms"),
            1,
        )
        self.assertIsNone(network_ping.parse_ping_ms("100% packet loss"))

    def test_icmp_success_skips_nmcli_and_tcp(self):
        with patch.object(network_ping, "probe_icmp", return_value=18), \
             patch.object(network_ping, "nmcli_connectivity") as nmcli_mock, \
             patch.object(network_ping, "probe_tcp") as tcp_mock:
            res = network_ping.check_connectivity()

        self.assertEqual(res, {
            "ok": True,
            "version": 1,
            "ping": 18,
            "status": "online",
            "method": "icmp",
            "error": None,
        })
        nmcli_mock.assert_not_called()
        tcp_mock.assert_not_called()

    def test_blocked_icmp_uses_tcp_latency_when_nmcli_full(self):
        with patch.object(network_ping, "probe_icmp", return_value=None), \
             patch.object(network_ping, "nmcli_connectivity", return_value="full"), \
             patch.object(network_ping, "probe_tcp", return_value=24):
            res = network_ping.check_connectivity()

        self.assertEqual(res["ping"], 24)
        self.assertEqual(res["status"], "online")
        self.assertEqual(res["method"], "tcp")
        self.assertTrue(res["ok"])

    def test_blocked_icmp_and_tcp_still_reports_online_when_nmcli_full(self):
        with patch.object(network_ping, "probe_icmp", return_value=None), \
             patch.object(network_ping, "nmcli_connectivity", return_value="full"), \
             patch.object(network_ping, "probe_tcp", return_value=None):
            res = network_ping.check_connectivity()

        self.assertEqual(res["ping"], -1)
        self.assertEqual(res["status"], "online")
        self.assertEqual(res["method"], "nmcli")

    def test_portal_and_offline_short_circuit_tcp_probe(self):
        for nm_state, expected_status in (("portal", "portal"), ("none", "offline")):
            with self.subTest(nm_state=nm_state):
                with patch.object(network_ping, "probe_icmp", return_value=None), \
                     patch.object(network_ping, "nmcli_connectivity", return_value=nm_state), \
                     patch.object(network_ping, "probe_tcp") as tcp_mock:
                    res = network_ping.check_connectivity()
                self.assertEqual(res["ping"], -1)
                self.assertEqual(res["status"], expected_status)
                self.assertEqual(res["method"], "nmcli")
                tcp_mock.assert_not_called()

    def test_limited_falls_back_to_limited_when_tcp_blocked_or_online_when_tcp_works(self):
        with patch.object(network_ping, "probe_icmp", return_value=None), \
             patch.object(network_ping, "nmcli_connectivity", return_value="limited"), \
             patch.object(network_ping, "probe_tcp", return_value=None):
            res = network_ping.check_connectivity()
        self.assertEqual(res["status"], "limited")
        self.assertEqual(res["ping"], -1)

        with patch.object(network_ping, "probe_icmp", return_value=None), \
             patch.object(network_ping, "nmcli_connectivity", return_value="limited"), \
             patch.object(network_ping, "probe_tcp", return_value=31):
            res = network_ping.check_connectivity()
        self.assertEqual(res["status"], "online")
        self.assertEqual(res["ping"], 31)
        self.assertEqual(res["method"], "tcp")

    def test_unknown_nmcli_uses_default_route_when_tcp_fails(self):
        with patch.object(network_ping, "probe_icmp", return_value=None), \
             patch.object(network_ping, "nmcli_connectivity", return_value="unknown"), \
             patch.object(network_ping, "probe_tcp", return_value=None), \
             patch.object(network_ping, "has_default_route", return_value=False):
            res = network_ping.check_connectivity()
        self.assertEqual(res["status"], "offline")
        self.assertEqual(res["method"], "route")

        with patch.object(network_ping, "probe_icmp", return_value=None), \
             patch.object(network_ping, "nmcli_connectivity", return_value="unknown"), \
             patch.object(network_ping, "probe_tcp", return_value=None), \
             patch.object(network_ping, "has_default_route", return_value=True):
            res = network_ping.check_connectivity()
        self.assertEqual(res["status"], "unknown")
        self.assertEqual(res["method"], "none")

    def test_nmcli_connectivity_falls_back_to_general_status(self):
        with patch.object(
            network_ping,
            "run_c",
            side_effect=[(0, "unknown", ""), (0, "full\n", "")],
        ) as run_mock:
            self.assertEqual(network_ping.nmcli_connectivity(), "full")
        self.assertEqual(run_mock.call_count, 2)


if __name__ == "__main__":
    unittest.main()
