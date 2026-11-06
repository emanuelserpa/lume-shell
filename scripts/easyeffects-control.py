#!/usr/bin/env python3
"""JSON adapter for EasyEffects' documented local socket."""
import argparse
import json
import os
import socket
import sys
from pathlib import Path


def request(command, expect_response=True):
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(2.0)
        client.connect(str(Path(runtime) / "EasyEffectsServer"))
        client.sendall((command + "\n").encode())
        if not expect_response:
            return ""
        return client.recv(65536).decode().strip()


def presets(pipeline):
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    folder = data_home / "easyeffects" / pipeline
    return sorted(p.stem for p in folder.glob("*.json") if p.is_file()) if folder.is_dir() else []


def run(args):
    if args.action == "status":
        bypass = request("get_global_bypass")
        if bypass not in ("1", "2"):
            raise RuntimeError("EasyEffects retornou estado de bypass inválido.")
        return {"ok": True, "available": True, "bypassed": bypass == "1",
                "output_preset": request("get_last_loaded_preset:output"),
                "input_preset": request("get_last_loaded_preset:input"),
                "output_presets": presets("output"), "input_presets": presets("input")}
    if args.action == "open":
        request("show_window", expect_response=False)
        return {"ok": True}
    if args.action == "bypass":
        request("global_bypass:" + ("1" if args.state == "on" else "0"), expect_response=False)
        return {"ok": True, "state": args.state}
    if args.action == "preset":
        if args.name not in presets(args.pipeline):
            raise ValueError("Preset não encontrado para esse tipo de áudio.")
        request(f"load_preset:{args.pipeline}:{args.name}", expect_response=False)
        return {"ok": True, "pipeline": args.pipeline, "preset": args.name}
    raise ValueError("Ação desconhecida.")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("status")
    sub.add_parser("open")
    bypass = sub.add_parser("bypass")
    bypass.add_argument("state", choices=("on", "off"))
    preset = sub.add_parser("preset")
    preset.add_argument("pipeline", choices=("input", "output"))
    preset.add_argument("name")
    args = parser.parse_args()
    try:
        result = run(args)
    except (OSError, RuntimeError, ValueError) as exc:
        result = {"ok": False, "available": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
