#!/usr/bin/env python3
"""Etapa 0 do plano Raycast: o catálogo de ações declara exatamente uma
ação primária por kind, sem executar nada (teste estrutural do QML)."""
import re
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True

CATALOG = Path(__file__).resolve().parents[1] / "launcher" / "SpotlightActionCatalog.qml"
ACTION_SOURCE = Path(__file__).resolve().parents[1] / "launcher" / "SpotlightActions.qml"

# Tabela do plano (docs/spotlight-raycast-plan.md): kind -> id da primária.
EXPECTED_PRIMARY = {
    "app": "open",
    "file": "open",
    "window": "focus",
    "clipboard": "restore",
    "emoji": "insert",
    "calc": "copy-result",
    "command": "run",
    "url": "download-video",
}


def parse_cases(text):
    cases = {}
    for m in re.finditer(r'case "([^"]+)":\s*return \[(.*?)\n\s{12}\]', text, re.DOTALL):
        kind, body = m.group(1), m.group(2)
        actions = re.findall(r'\{\s*id:\s*"([^"]+)".*?primary:\s*(true|false)', body, re.DOTALL)
        cases[kind] = actions
    default_m = re.search(r'default:', text)
    default_actions = []
    if default_m:
        default_actions = re.findall(r'\{\s*id:\s*"([^"]+)".*?primary:\s*(true|false)',
                                     text[default_m.start():default_m.start() + 400], re.DOTALL)
    return cases, default_actions


class TestActionCatalog(unittest.TestCase):
    def test_screen_qr_scanner_is_searchable_action(self):
        text = ACTION_SOURCE.read_text(encoding="utf-8")
        capture_actions = re.search(
            r"function captureActions\(\)\s*\{(.*?)\n    \}",
            text,
            re.DOTALL,
        )
        self.assertIsNotNone(capture_actions)
        self.assertIn('title: "Ler QR code da tela"', capture_actions.group(1))
        self.assertIn('subtitle: "Selecionar uma região e copiar o código para a área de transferência"',
                      capture_actions.group(1))
        self.assertIn('Quickshell.shellDir + "/scripts/scan-qr.sh"', capture_actions.group(1))
        self.assertIn('title: "Captura de área"', capture_actions.group(1))
        self.assertIn('title: "Gravar tela com áudio"', capture_actions.group(1))

        session_actions = re.search(
            r"function sessionActions\(\)\s*\{(.*?)\n    \}", text, re.DOTALL
        )
        self.assertNotIn('title: "Captura de área"', session_actions.group(1))
        self.assertNotIn('title: "Gravar tela"', session_actions.group(1))

    def test_kinds_have_single_primary(self):
        text = CATALOG.read_text(encoding="utf-8")
        cases, _ = parse_cases(text)
        for kind, primary_id in EXPECTED_PRIMARY.items():
            if kind == "clipboard":
                # Text clipboard keeps Restore as its primary; image entries
                # expose a separate one-action "open image" catalog tested in QML.
                continue
            self.assertIn(kind, cases, f"kind sem entrada no catálogo: {kind}")
            primaries = [a for a, p in cases[kind] if p == "true"]
            self.assertEqual(len(primaries), 1, f"kind {kind} deve ter exatamente 1 primária")
            self.assertEqual(primaries[0], primary_id, f"primária de {kind}")

    def test_default_fallback_has_primary(self):
        text = CATALOG.read_text(encoding="utf-8")
        _, default_actions = parse_cases(text)
        primaries = [a for a, p in default_actions if p == "true"]
        self.assertEqual(len(primaries), 1, "fallback default precisa de 1 primária")

    def test_secondary_ids(self):
        # Etapa 1: secundárias conhecidas pelo runSecondary().
        text = CATALOG.read_text(encoding="utf-8")
        cases, _ = parse_cases(text)
        expected = {
            "app": "copy-command",
            "file": "copy-path",
            "window": "close",
            "clipboard": "copy",
            "emoji": "copy",
            "calc": "copy-expression",
            "command": "copy-command",
        }
        for kind, sid in expected.items():
            if kind == "clipboard":
                continue
            ids = [a for a, p in cases[kind] if p == "false"]
            self.assertIn(sid, ids, f"secundária de {kind}")

    def test_no_system_calls_in_catalog(self):
        text = CATALOG.read_text(encoding="utf-8")
        for forbidden in ("execDetached", "Process {", "hyprctl", "import Quickshell.Io"):
            self.assertNotIn(forbidden, text, f"catálogo puro não pode conter: {forbidden}")

    def test_action_groups_valid(self):
        import re
        text = CATALOG.read_text(encoding="utf-8")
        groups = set(re.findall(r'group:\s*"([^"]+)"', text))
        self.assertTrue(len(groups) > 0, "ações sem grupo")
        self.assertTrue(groups <= {"Principal", "Copiar", "Ações", "Gerenciar"},
                        f"grupos inválidos: {groups}")


if __name__ == "__main__":
    unittest.main()
