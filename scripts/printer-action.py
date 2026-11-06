#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys

def out(ok, error=None):
    print(json.dumps({"ok": ok, "version": 1, "error": error}, ensure_ascii=False))

def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if not args:
        out(False, "Ação de impressora ausente.")
        return 1

    if args[0] == "cancel":
        if len(args) < 2:
            out(False, "ID do trabalho ausente.")
            return 1
        cancel = shutil.which("cancel")
        if not cancel:
            out(False, "Comando cancel não encontrado.")
            return 1
        cp = subprocess.run([cancel, args[1]], capture_output=True, text=True)
        if cp.returncode == 0:
            out(True)
        else:
            out(False, (cp.stderr or cp.stdout or "Falha ao cancelar trabalho.").strip())
        return cp.returncode

    out(False, "Ação desconhecida.")
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
