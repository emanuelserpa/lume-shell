#!/usr/bin/env python3
import sys
sys.dont_write_bytecode = True
import unittest
from unittest.mock import patch
from tests.helpers import import_script, read_fixture
from network_utils import prefer_ipv4_resolution

bt_mod = import_script("bluetooth_status", "bluetooth-status.py")
net_mod = import_script("network_status", "network-status.py")
lp_mod = import_script("printer_status", "printer-status.py")

class TestNetworkUtilities(unittest.TestCase):
    def test_ipv4_preference_forces_address_family(self):
        import socket

        with patch("network_utils.socket.getaddrinfo") as original:
            prefer_ipv4_resolution()
            socket.getaddrinfo("example", 443, socket.AF_UNSPEC)

        self.assertEqual(original.call_args.args[:3], ("example", 443, socket.AF_INET))

class TestBluetoothParsers(unittest.TestCase):
    def test_parse_bt_show_powered(self):
        text = read_fixture("bluetooth_show_powered.txt")
        res = bt_mod.parse_bt_show(text, rc=0)
        self.assertTrue(res["available"])
        self.assertTrue(res["powered"])
        self.assertEqual(res["controller"], "14:5A:FC:18:15:D2")
        self.assertEqual(res["controller_alias"], "t14")
        self.assertFalse(res["discoverable"])
        self.assertTrue(res["pairable"])

    def test_parse_bt_show_unpowered(self):
        text = read_fixture("bluetooth_show_unpowered.txt")
        res = bt_mod.parse_bt_show(text, rc=0)
        self.assertTrue(res["available"])
        self.assertFalse(res["powered"])
        self.assertEqual(res["controller"], "14:5A:FC:18:15:D2")

    def test_parse_device_info(self):
        text = read_fixture("bluetooth_info_device.txt")
        res = bt_mod.parse_device_info(text, "23:08:15:B3:C8:A3", "Fallback", rc=0)
        self.assertEqual(res["mac"], "23:08:15:B3:C8:A3")
        self.assertEqual(res["name"], "Moondrop Space Travel")
        self.assertEqual(res["alias"], "Moondrop Space Travel")
        self.assertTrue(res["paired"])
        self.assertTrue(res["connected"])
        self.assertTrue(res["trusted"])
        self.assertFalse(res["blocked"])
        self.assertEqual(res["icon"], "audio-headset")
        self.assertEqual(res["battery"], 80)

    def test_has_human_name(self):
        self.assertFalse(bt_mod.has_human_name(""))
        self.assertFalse(bt_mod.has_human_name("  "))
        self.assertFalse(bt_mod.has_human_name("23:08:15:B3:C8:A3"))
        self.assertFalse(bt_mod.has_human_name("23-08-15-B3-C8-A3"))
        self.assertFalse(bt_mod.has_human_name("12345678-1234-1234-1234-123456789abc"))
        self.assertTrue(bt_mod.has_human_name("Sony WH-1000XM4"))
        self.assertTrue(bt_mod.has_human_name("Keyboard K380"))

    def test_is_address_like(self):
        self.assertTrue(bt_mod.is_address_like("23:08:15:B3:C8:A3"))
        self.assertTrue(bt_mod.is_address_like("23-08-15-b3-c8-a3"))
        self.assertFalse(bt_mod.is_address_like("not-a-mac"))


class TestPrinterParsers(unittest.TestCase):
    # Real `lpq -P EPSON-L4150-Series` lines (pt-BR locale). Columns use
    # single spaces in places, so fixed 2-space splitting misaligned and
    # every title fell back to the job id.
    def test_parse_lpq_job_line(self):
        res = lp_mod.parse_lpq_line(
            "1st     emanuel 83      teste-nome-documento            1024 bytes")
        self.assertEqual(res, ("1st", "emanuel", "83", "teste-nome-documento"))

    def test_parse_lpq_active_line(self):
        res = lp_mod.parse_lpq_line(
            "active  emanuel 84      FICHA ACOMPANHAMENTO.pdf          500736 bytes")
        self.assertEqual(res, ("active", "emanuel", "84", "FICHA ACOMPANHAMENTO.pdf"))

    def test_parse_lpq_headers_rejected(self):
        self.assertIsNone(lp_mod.parse_lpq_line(
            "Ordem   Dono    Trab    Arquivo(s)                      Tamanho total"))
        self.assertIsNone(lp_mod.parse_lpq_line(
            "Rank   Owner   Job  File(s)                         Total size"))
        self.assertIsNone(lp_mod.parse_lpq_line(""))
        self.assertIsNone(lp_mod.parse_lpq_line("EPSON-L4150-Series está pronta"))


class TestNetworkParsers(unittest.TestCase):
    def test_parse_bool(self):
        for val in ("enabled", "yes", "true", "on", "YES", "True"):
            self.assertTrue(net_mod.parse_bool(val), f"Expected True for {val}")
        for val in ("disabled", "no", "false", "off", "0", ""):
            self.assertFalse(net_mod.parse_bool(val), f"Expected False for {val}")

    def test_wifi_icon_5level(self):
        self.assertEqual(net_mod.wifi_icon_5level(90), "󰤨")
        self.assertEqual(net_mod.wifi_icon_5level(75), "󰤥")
        self.assertEqual(net_mod.wifi_icon_5level(50), "󰤢")
        self.assertEqual(net_mod.wifi_icon_5level(25), "󰤟")
        self.assertEqual(net_mod.wifi_icon_5level(10), "󰤯")

    def test_parse_saved_connections(self):
        raw = read_fixture("network_connections.txt").splitlines()
        saved, vpns = net_mod.parse_saved_connections(raw)
        self.assertIn("PLIG_AP01_5G", saved)
        self.assertEqual(saved["PLIG_AP01_5G"]["type"], "802-11-wireless")
        self.assertEqual(len(vpns), 1)
        self.assertEqual(vpns[0]["name"], "MyVPN")

    def test_parse_active_connections(self):
        raw = read_fixture("network_active_wifi.txt").splitlines()
        active_uuids, active_info = net_mod.parse_active_connections(raw)
        self.assertIn("11111111-2222-3333-4444-555555555555", active_uuids)
        self.assertEqual(active_info["active_connection"], "PLIG_AP01_5G")
        self.assertEqual(active_info["active_device"], "wlp3s0")
        self.assertEqual(active_info["active_type"], "wifi")

if __name__ == "__main__":
    unittest.main()
