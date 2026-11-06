#!/usr/bin/env python3
"""KDE Connect actions for the Quickshell phone module.

Usage:
  kdeconnect-action.py refresh
  kdeconnect-action.py ping <id>
  kdeconnect-action.py ring <id>
  kdeconnect-action.py pair <id>
  kdeconnect-action.py unpair <id>
  kdeconnect-action.py share-text <id> <text...>
  kdeconnect-action.py share <id> <path-or-url...>

Always prints {"ok", "action", "error"} JSON. Exit 0 on success, 1 on error.
"""
import os
import shutil
import sys
from command_utils import run_command as run


def result(ok, action, error=None):
    import json
    print(json.dumps({
        "ok": bool(ok),
        "version": 1,
        "action": action,
        "error": error or None,
    }, ensure_ascii=False))
    return 0 if ok else 1


def need_cli(action):
    if shutil.which("kdeconnect-cli") is None:
        return result(False, action, "kdeconnect-cli não instalado (pacote kdeconnect).")
    return None


def fail(action, rc, out, err, fallback):
    if rc == 124:
        return result(False, action, "A operação expirou.")
    raw = (err or out or "").strip()
    if not raw:
        return result(False, action, fallback)
    low = raw.lower()
    if "couldn't find device" in low or "couldnt find device" in low:
        return result(False, action, "Aparelho não encontrado. Atualize a lista.")
    if "no device" in low:
        return result(False, action, "Informe o aparelho.")
    return result(False, action, raw.splitlines()[0][:180])


def main():
    if len(sys.argv) < 2:
        return result(False, "", "Ação inválida.")
    action = sys.argv[1]

    if action == "refresh":
        denied = need_cli(action)
        if denied is not None:
            return denied
        rc, out, err = run(["kdeconnect-cli", "--refresh"], timeout=15)
        if rc == 0:
            return result(True, action)
        return fail(action, rc, out, err, "Falha ao atualizar.")

    if len(sys.argv) < 3 or not sys.argv[2].strip():
        return result(False, action, "Aparelho inválido.")
    dev = sys.argv[2].strip()

    if action in ("ping", "ring", "pair", "unpair"):
        denied = need_cli(action)
        if denied is not None:
            return denied
        flag = {"ping": "--ping", "ring": "--ring",
                "pair": "--pair", "unpair": "--unpair"}[action]
        rc, out, err = run(["kdeconnect-cli", flag, "-d", dev],
                           timeout=30 if action == "pair" else 15)
        if rc == 0:
            return result(True, action)
        return fail(action, rc, out, err, "A operação falhou.")

    if action == "share-text":
        denied = need_cli(action)
        if denied is not None:
            return denied
        text = " ".join(sys.argv[3:]).strip()
        if not text:
            return result(False, action, "Texto vazio.")
        if len(text) > 4000:
            return result(False, action, "Texto muito longo (máx. 4000).")
        rc, out, err = run(["kdeconnect-cli", "--share-text", text, "-d", dev], timeout=20)
        if rc == 0:
            return result(True, action)
        return fail(action, rc, out, err, "Falha ao compartilhar texto.")

    if action == "share":
        denied = need_cli(action)
        if denied is not None:
            return denied
        targets = [a for a in sys.argv[3:] if a.strip()]
        if not targets:
            return result(False, action, "Nenhum arquivo ou link.")
        if len(targets) > 5:
            return result(False, action, "Máximo de 5 itens por vez.")
        for t in targets:
            low = t.lower()
            is_url = low.startswith(("http://", "https://"))
            if not is_url and not os.path.exists(t):
                return result(False, action, "Arquivo não encontrado: %s" % t[:80])
        for t in targets:
            rc, out, err = run(["kdeconnect-cli", "--share", t, "-d", dev], timeout=60)
            if rc != 0:
                return fail(action, rc, out, err, "Falha ao compartilhar.")
        return result(True, action)

    return result(False, action, "Ação desconhecida.")


if __name__ == "__main__":
    raise SystemExit(main())
