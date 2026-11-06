#!/usr/bin/env python3
"""Small JSON interface for starting and stopping a wf-recorder session."""

import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
sys.dont_write_bytecode = True
import time
import uuid



GEOMETRY = re.compile(r"^-?\d+,-?\d+ \d+x\d+$")


def is_hyprland():
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower().split(":")
    return not os.environ.get("LABWC_PID") and "hyprland" in desktop


def runtime_dir():
    base = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/quickshell-{os.getuid()}")
    path = base / "quickshell-recording"
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return path


def state_path():
    return runtime_dir() / "state.json"


def read_state():
    try:
        return json.loads(state_path().read_text())
    except (OSError, ValueError):
        return None


def write_state(data):
    path = state_path()
    temporary = path.with_suffix(".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(data, stream)
    os.replace(temporary, path)


def alive(state):
    if not state:
        return False
    try:
        pid = int(state["pid"])
        proc = Path(f"/proc/{pid}")
        if proc.joinpath("stat").read_text().rsplit(")", 1)[1].split()[0] == "Z":
            return False
        command = proc.joinpath("cmdline").read_bytes().split(b"\0")
        return any(Path(part.decode(errors="replace")).name == "wf-recorder" for part in command if part) \
            and str(state["path"]).encode() in command
    except (OSError, ValueError, KeyError, IndexError):
        return False


def status():
    state = read_state()
    if not alive(state):
        if state:
            cleanup_audio_modules(state.get("audio_modules", []))
            state_path().unlink(missing_ok=True)
        return {"ok": True, "version": 1, "active": False}
    return {
        "ok": True,
        "version": 1,
        "active": True,
        "mode": state["mode"],
        "path": state["path"],
        "audio": bool(state.get("audio", False)),
        "audio_mode": state.get("audio_mode", "microphone" if state.get("audio") else "none"),
        "elapsed": max(0, int(time.time() - state["started_at"])),
    }


def pactl(*args):
    result = subprocess.run(["pactl", *args], capture_output=True, text=True, timeout=5)
    if result.returncode:
        detail = result.stderr.strip()
        raise RuntimeError(detail or "Não foi possível configurar o áudio da gravação.")
    return result.stdout.strip()


def default_audio_source():
    source = pactl("get-default-source")
    if not source:
        raise RuntimeError("Nenhum microfone padrão foi encontrado.")
    return source


def default_system_monitor():
    sink = pactl("get-default-sink")
    if not sink:
        raise RuntimeError("Nenhuma saída de áudio padrão foi encontrada.")
    monitor = sink + ".monitor"
    sources = {line.split("\t", 2)[1] for line in pactl("list", "short", "sources").splitlines() if len(line.split("\t")) > 1}
    if monitor not in sources:
        raise RuntimeError("Não foi possível encontrar a captura da saída de áudio atual.")
    return monitor


def create_audio_mix():
    name = "qs_recording_" + uuid.uuid4().hex[:10]
    modules = []
    try:
        modules.append(pactl("load-module", "module-null-sink", f"sink_name={name}", "sink_properties=device.description=Quickshell-Recording-Mix"))
        modules.append(pactl("load-module", "module-loopback", f"source={default_audio_source()}", f"sink={name}"))
        modules.append(pactl("load-module", "module-loopback", f"source={default_system_monitor()}", f"sink={name}"))
        return name + ".monitor", modules
    except Exception:
        cleanup_audio_modules(modules)
        raise


def cleanup_audio_modules(modules):
    for module in reversed(modules or []):
        try:
            subprocess.run(["pactl", "unload-module", str(module)], capture_output=True, text=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            pass



def hypr_json(name):
    result = subprocess.run(["hyprctl", name, "-j"], capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise RuntimeError("Não foi possível consultar as janelas do Hyprland.")
    return json.loads(result.stdout)


def visible_window_boxes(clients, monitors):
    workspaces = {m.get("activeWorkspace", {}).get("id") for m in monitors}
    boxes = []
    for client in clients:
        if (client.get("workspace", {}).get("id") not in workspaces
                or client.get("hidden") or client.get("mapped") is False
                or client.get("visible") is False):
            continue
        at, size = client.get("at", []), client.get("size", [])
        if len(at) != 2 or len(size) != 2 or min(size) <= 0:
            continue
        boxes.append(f"{int(at[0])},{int(at[1])} {int(size[0])}x{int(size[1])}")
    return boxes


def choose_geometry(mode):
    if mode == "screen" and is_hyprland():
        monitors = hypr_json("monitors")
        monitor = next((m for m in monitors if m.get("focused")), None)
        if monitor is None:
            raise RuntimeError("Nenhuma tela ativa foi encontrada.")
        return ["-o", str(monitor["name"])]

    if not shutil.which("slurp"):
        raise RuntimeError("Instale o slurp para selecionar janelas ou regiões.")
    if mode == "screen":
        args, choices = ["slurp", "-o"], None
    elif mode == "window" and is_hyprland():
        boxes = visible_window_boxes(hypr_json("clients"), hypr_json("monitors"))
        if not boxes:
            raise RuntimeError("Nenhuma janela visível foi encontrada.")
        args, choices = ["slurp", "-r"], "\n".join(boxes) + "\n"
    else:
        args, choices = ["slurp"], None
    try:
        if choices is None:
            # Quickshell leaves the helper's stdin open. slurp reads stdin for
            # predefined boxes and waits forever unless it sees EOF.
            result = subprocess.run(
                args, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120
            )
        else:
            result = subprocess.run(
                args, input=choices, capture_output=True, text=True, timeout=120
            )
    except subprocess.TimeoutExpired:
        raise RuntimeError("A seleção demorou demais. Tente novamente.") from None
    if result.returncode:
        raise RuntimeError("Seleção cancelada.")
    geometry = result.stdout.strip()
    if not GEOMETRY.fullmatch(geometry):
        raise RuntimeError("A seleção retornou uma área inválida.")
    return ["-g", geometry]


def video_directory():
    if shutil.which("xdg-user-dir"):
        result = subprocess.run(["xdg-user-dir", "VIDEOS"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and result.stdout.strip():
            return Path(result.stdout.strip())
    home = Path.home()
    return home / ("Vídeos" if (home / "Vídeos").is_dir() else "Videos")


def start(mode, capture, audio_mode="none"):
    if mode not in ("screen", "window", "selection"):
        raise RuntimeError("Modo de gravação inválido.")
    if isinstance(audio_mode, bool):
        audio_mode = "microphone" if audio_mode else "none"
    if audio_mode not in ("none", "microphone", "system", "both"):
        raise RuntimeError("Modo de áudio inválido.")
    if status()["active"]:
        raise RuntimeError("Já existe uma gravação em andamento.")
    if not shutil.which("wf-recorder"):
        raise RuntimeError("Instale o wf-recorder para gravar a tela.")
    folder = video_directory() / "Gravações de tela"
    folder.mkdir(parents=True, exist_ok=True)
    filename = dt.datetime.now().strftime("Gravação_%Y-%m-%d_%H-%M-%S_%f.mp4")
    path = folder / filename
    log = runtime_dir() / "recorder.log"
    cmd = ["wf-recorder"]
    modules = []
    if audio_mode == "microphone":
        cmd.append(f"--audio={default_audio_source()}")
    elif audio_mode == "system":
        cmd.append(f"--audio={default_system_monitor()}")
    elif audio_mode == "both":
        source, modules = create_audio_mix()
        cmd.append(f"--audio={source}")
    cmd.extend(capture)
    cmd.extend(["-f", str(path)])
    with log.open("wb") as errors:
        try:
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=errors,
                start_new_session=True,
            )
        except Exception:
            cleanup_audio_modules(modules)
            raise
    time.sleep(0.7)
    if process.poll() is not None:
        cleanup_audio_modules(modules)
        detail = log.read_text(errors="replace").strip().splitlines()
        raise RuntimeError(detail[-1] if detail else "A gravação não pôde iniciar.")
    write_state({
        "pid": process.pid,
        "path": str(path),
        "mode": mode,
        "audio": audio_mode != "none",
        "audio_mode": audio_mode,
        "audio_modules": modules,
        "started_at": time.time(),
    })
    return status()


def stop():
    state = read_state()
    if not alive(state):
        return status()
    os.kill(int(state["pid"]), signal.SIGINT)
    for _ in range(80):
        if not alive(state):
            cleanup_audio_modules(state.get("audio_modules", []))
            state_path().unlink(missing_ok=True)
            return {"ok": True, "version": 1, "active": False, "path": state["path"]}
        time.sleep(0.1)
    return {"ok": True, "version": 1, "active": True, "stopping": True, "path": state["path"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("status", "start", "stop"))
    parser.add_argument("mode", nargs="?")
    parser.add_argument("-a", "--audio", action="store_true", help="Compatibilidade: gravar pelo microfone")
    parser.add_argument("--audio-mode", choices=("none", "microphone", "system", "both"))
    args = parser.parse_args()
    try:
        capture = None
        if args.action == "start":
            if args.mode not in ("screen", "window", "selection"):
                raise RuntimeError("Modo de gravação inválido.")
            if status()["active"]:
                raise RuntimeError("Já existe uma gravação em andamento.")
            if not shutil.which("wf-recorder"):
                raise RuntimeError("Instale o wf-recorder para gravar a tela.")
            # The picker can wait for the user; never hold the state lock here.
            capture = choose_geometry(args.mode)
        lock_path = runtime_dir() / "control.lock"
        with lock_path.open("a+b") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if args.action == "status":
                result = status()
            elif args.action == "start":
                audio_mode = args.audio_mode or ("microphone" if args.audio else "none")
                result = start(args.mode, capture, audio_mode=audio_mode)
            else:
                result = stop()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        result = {"ok": False, "version": 1, "error": str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
