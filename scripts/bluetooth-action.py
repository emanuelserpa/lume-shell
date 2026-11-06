#!/usr/bin/env python3
import json
import sys

from bt_ctl import run_bt

VERSION = 1

def result(ok, action, error=None):
    print(json.dumps({
        "ok": bool(ok),
        "version": VERSION,
        "action": action,
        "error": error or None,
    }, ensure_ascii=False))
    return 0 if ok else 1

def run(action, args, timeout=25):
    rc, out, err = run_bt(args, timeout=timeout)

    if rc == 0:
        return result(True, action)

    if rc == 124:
        return result(False, action, "A operação Bluetooth expirou.")

    raw = (err or out or "").strip()
    low = raw.lower()

    if "not available" in low:
        msg = "Dispositivo não disponível."
    elif "not ready" in low:
        msg = "Bluetooth não está pronto."
    elif "authentication" in low or "authenticationfailed" in low:
        msg = "Falha de autenticação."
    elif "connection attempt failed" in low or "failed to connect" in low:
        msg = "Não foi possível conectar."
    elif "org.bluez.error.failed" in low:
        msg = "A operação foi recusada pelo BlueZ."
    elif raw:
        msg = raw.splitlines()[0][:180]
    else:
        msg = "A operação Bluetooth falhou."

    return result(False, action, msg)

def main():
    if len(sys.argv) < 2:
        return result(False, "", "Ação inválida.")

    action = sys.argv[1]

    if action == "power-on":
        return run(action, ["bluetoothctl", "power", "on"])
    if action == "power-off":
        return run(action, ["bluetoothctl", "power", "off"])

    if action == "scan-on":
        return run(action, ["bluetoothctl", "scan", "on"], timeout=8)
    if action == "scan-off":
        return run(action, ["bluetoothctl", "scan", "off"], timeout=8)

    if len(sys.argv) < 3:
        return result(False, action, "Dispositivo inválido.")

    mac = sys.argv[2]

    if action == "connect":
        run_bt(["bluetoothctl", "power", "on"], timeout=4)
        run_bt(["bluetoothctl", "trust", mac], timeout=4)
        return run(action, ["bluetoothctl", "connect", mac], timeout=20)

    if action == "disconnect":
        return run(action, ["bluetoothctl", "disconnect", mac], timeout=10)

    if action == "trust":
        return run(action, ["bluetoothctl", "trust", mac])

    if action == "remove":
        run_bt(["bluetoothctl", "disconnect", mac], timeout=4)
        return run(action, ["bluetoothctl", "remove", mac], timeout=8)

    if action == "pair":
        # Works directly for devices that do not require an interactive
        # passkey exchange. Advanced cases can still use Blueberry.
        rc = run(action, ["bluetoothctl", "pair", mac], timeout=35)
        if rc != 0:
            return rc

        # Best-effort trust + connect after successful pairing.
        run_bt(["bluetoothctl", "trust", mac], timeout=8)
        run_bt(["bluetoothctl", "connect", mac], timeout=15)
        return 0

    return result(False, action, "Ação Bluetooth desconhecida.")

if __name__ == "__main__":
    raise SystemExit(main())
