#!/usr/bin/env python3
"""Windows+P-style display projection modes for the active Hyprland session."""

from __future__ import annotations

import json
import os
import re
import subprocess
import ast
import sys
from pathlib import Path

VERSION = 1
MODES = ("computer", "duplicate", "extend", "external")
INTERNAL_NAME = re.compile(r"^(?:eDP|LVDS|DSI)", re.IGNORECASE)
MONITOR_BLOCK = re.compile(r"hl\.monitor\s*\(\s*\{(.*?)\}\s*\)", re.DOTALL)
LUA_FIELD = re.compile(
    r'\b(output|mode|position|scale|transform|vrr|bitdepth|icc)\s*=\s*([^,\n}]+)'
)


def success(data: dict) -> dict:
    return {"ok": True, "version": VERSION, "data": data, "error": None}


def failure(message: str) -> dict:
    return {"ok": False, "version": VERSION, "data": {}, "error": message}


def is_internal(monitor: dict) -> bool:
    name = str(monitor.get("name", ""))
    description = str(monitor.get("description", "")).lower()
    return bool(INTERNAL_NAME.match(name)) or any(
        phrase in description for phrase in ("internal panel", "built-in display", "built-in panel")
    )


def monitor_label(monitor: dict) -> str:
    description = str(monitor.get("description", "")).strip()
    name = str(monitor.get("name", "Monitor"))
    if description and name.lower() not in description.lower():
        return f"{description} ({name})"
    return name


def mode_options(monitors: list[dict], current_mode: str) -> list[dict]:
    internal = next((item for item in monitors if is_internal(item)), None)
    external = [item for item in monitors if not is_internal(item)]
    connected = len(monitors)
    options = []

    if internal:
        options.append({
            "id": "computer",
            "title": "Somente tela do computador",
            "subtitle": f"Usar {monitor_label(internal)}",
            "icon": "󰌢",
            "available": True,
        })

    if connected > 1:
        options.append({
            "id": "duplicate",
            "title": "Duplicar",
            "subtitle": "Mostrar a mesma imagem em todas as telas",
            "icon": "󰍹",
            "available": True,
        })

    options.append({
        "id": "extend",
        "title": "Estender",
        "subtitle": "Restaurar o layout configurado dos monitores",
        "icon": "󰍹",
        "available": True,
    })

    if external:
        target = external[0]
        options.append({
            "id": "external",
            "title": "Somente segunda tela",
            "subtitle": f"Usar {monitor_label(target)}",
            "icon": "󰹑",
            "available": True,
        })

    for option in options:
        option["selected"] = option["id"] == current_mode
    return options


def active_mode(monitors: list[dict]) -> str:
    # Hyprland reports the non-mirrored sentinel as the literal string
    # "none", which is truthy in Python. Only a real output name means the
    # monitor is currently mirrored.
    if any(
        str(item.get("mirrorOf", "")).strip().lower() not in ("", "none")
        for item in monitors
    ):
        return "duplicate"

    active = [item for item in monitors if not bool(item.get("disabled", False))]
    if len(active) == 1:
        return "computer" if is_internal(active[0]) else "external"
    if len(active) == len(monitors):
        return "extend"
    return "custom"


def display_mode(monitor: dict) -> str:
    width = int(monitor.get("width", 0) or 0)
    height = int(monitor.get("height", 0) or 0)
    refresh = float(monitor.get("refreshRate", 0) or 0)
    if width <= 0 or height <= 0:
        return "preferred"
    if refresh <= 0:
        return f"{width}x{height}"
    return f"{width}x{height}@{refresh:.2f}"


def monitor_config(
    monitor: dict,
    *,
    enabled: bool = True,
    configured: dict | None = None,
) -> dict:
    if not enabled:
        return {"output": str(monitor["name"]), "disabled": True}

    config = {
        "output": str(monitor["name"]),
        "mode": display_mode(monitor),
        "position": f"{int(monitor.get('x', 0) or 0)}x{int(monitor.get('y', 0) or 0)}",
        "scale": float(monitor.get("scale", 1) or 1),
    }
    for key in ("transform", "bitdepth"):
        if key in monitor and monitor[key] is not None:
            config[key] = monitor[key]
    if configured:
        for key in ("vrr", "icc"):
            if key in configured:
                config[key] = configured[key]
    return config


def baseline_entry(monitor: dict, configured: dict | None = None) -> dict:
    if bool(monitor.get("disabled", False)):
        return {"output": str(monitor["name"]), "disabled": True}
    return monitor_config(monitor, configured=configured)


def lua_literal(value: str):
    value = value.strip()
    if value.startswith('"'):
        return ast.literal_eval(value)
    if value in ("true", "false"):
        return value == "true"
    try:
        return float(value) if "." in value else int(value)
    except ValueError:
        return None


def configured_monitor_properties(source: str) -> dict[str, dict]:
    """Read stable per-output properties from the simple hl.monitor tables."""
    configured = {}
    for block in MONITOR_BLOCK.findall(source):
        fields = {
            key: parsed
            for key, value in LUA_FIELD.findall(block)
            if (parsed := lua_literal(value)) is not None
        }
        output = fields.get("output")
        if output:
            configured[output] = fields
    return configured


def configured_monitors() -> dict[str, dict]:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    path = config_home / "hypr" / "hyprland.lua"
    try:
        return configured_monitor_properties(path.read_text(encoding="utf-8"))
    except OSError:
        return {}


def merge_configured_monitor(saved: dict, configured: dict | None) -> dict:
    result = dict(saved)
    # The live JSON field is VRR's active state, not hl.monitor's integer policy.
    result.pop("vrr", None)
    if configured:
        result.update(configured)
    return result


def build_plan(
    mode: str,
    monitors: list[dict],
    baseline: list[dict],
    configured: dict[str, dict] | None = None,
) -> list[dict]:
    if mode not in MODES:
        raise ValueError("Modo de projeção desconhecido.")
    if not monitors:
        raise ValueError("Nenhum monitor conectado foi encontrado.")

    by_name = {str(monitor.get("name", "")): monitor for monitor in monitors}
    configured = configured or {}
    baseline_by_name = {str(item.get("output", "")): item for item in baseline}
    if mode == "extend":
        return [dict(item) for item in baseline if str(item.get("output", "")) in by_name]

    internal = next((item for item in monitors if is_internal(item)), None)
    if mode == "computer":
        if internal is None:
            raise ValueError("Não foi possível identificar a tela interna.")
        chosen = internal
    elif mode == "external":
        chosen = next((item for item in monitors if not is_internal(item)), None)
        if chosen is None:
            raise ValueError("Nenhuma segunda tela conectada foi encontrada.")
    else:
        if len(monitors) < 2:
            raise ValueError("Duplicar exige pelo menos dois monitores conectados.")
        chosen = internal or next((item for item in monitors if item.get("focused")), monitors[0])

    if mode == "duplicate":
        chosen_name = str(chosen["name"])
        source_config = {**baseline_by_name.get(chosen_name, {}), **configured.get(chosen_name, {})}
        plan = [activation_config(chosen, source_config)]
        for monitor in monitors:
            if monitor is chosen:
                continue
            output_config = {**baseline_by_name.get(str(monitor["name"]), {}),
                             **configured.get(str(monitor["name"]), {})}
            plan.append({
                "output": str(monitor["name"]),
                "mode": "preferred",
                "scale": float(monitor.get("scale", 1) or 1),
                "mirror": str(chosen["name"]),
                **({"icc": output_config["icc"]} if output_config.get("icc") else {}),
            })
        return plan

    chosen_name = str(chosen["name"])
    source_config = {**baseline_by_name.get(chosen_name, {}), **configured.get(chosen_name, {})}
    plan = [activation_config(chosen, source_config)]
    plan.extend(
        {"output": str(monitor["name"]), "disabled": True}
        for monitor in monitors
        if monitor is not chosen
    )
    return plan


def activation_config(monitor: dict, saved: dict) -> dict:
    """Reactivate an output with its known-good mode, not disabled runtime data."""
    if saved and not saved.get("disabled") and saved.get("mode"):
        return {key: value for key, value in saved.items() if key != "disabled"}
    return monitor_config(monitor, configured=saved)


def lua_string(value: str) -> str:
    return json.dumps(str(value), ensure_ascii=False)


def lua_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (int, float)):
        return str(value)
    raise ValueError("Valor de configuração de monitor inválido.")


def lua_monitor_command(config: dict) -> str:
    fields = ", ".join(
        f"{key} = {lua_value(value)}" for key, value in config.items()
    )
    return f"hl.monitor({{ {fields} }})"


def monitor_command_succeeded(result: subprocess.CompletedProcess) -> bool:
    return result.returncode == 0 and result.stdout.strip() == "ok"


def run_json_command(args: list[str]) -> list[dict]:
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(f"Não foi possível consultar o Hyprland: {error}") from error
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "Hyprland recusou o comando."
        raise RuntimeError(message)
    try:
        monitors = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("O Hyprland retornou uma lista de monitores inválida.") from error
    if not isinstance(monitors, list):
        raise RuntimeError("A resposta do Hyprland não contém uma lista de monitores.")
    return [item for item in monitors if isinstance(item, dict) and item.get("name")]


def state_file() -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    return state_home / "quickshell" / "display-projection.json"


def instance_signature() -> str:
    return os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")


def read_baseline(monitors: list[dict]) -> list[dict]:
    path = state_file()
    signature = instance_signature()
    cached = None
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
        if stored.get("signature") == signature and isinstance(stored.get("monitors"), list):
            cached = stored["monitors"]
    except (OSError, json.JSONDecodeError, AttributeError):
        pass

    by_name = {
        str(item.get("output", "")): dict(item)
        for item in (cached or [])
        if isinstance(item, dict) and item.get("output")
    }
    configured = configured_monitors()
    for monitor in monitors:
        name = str(monitor["name"])
        if name not in by_name:
            by_name[name] = baseline_entry(monitor, configured.get(name))
        else:
            by_name[name] = merge_configured_monitor(by_name[name], configured.get(name))

    baseline = list(by_name.values())
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps({
        "signature": signature,
        "monitors": baseline,
    }, ensure_ascii=False), encoding="utf-8")
    temporary.replace(path)
    return baseline


def status() -> dict:
    monitors = run_json_command(["hyprctl", "-j", "monitors", "all"])
    if not monitors:
        return failure("Nenhum monitor conectado foi encontrado.")

    baseline = read_baseline(monitors)
    current = active_mode(monitors)
    return success({
        "currentMode": current,
        "monitors": [{
            "name": str(item["name"]),
            "label": monitor_label(item),
            "internal": is_internal(item),
            "disabled": bool(item.get("disabled", False)),
            "mirrorOf": str(item.get("mirrorOf", "")),
        } for item in monitors],
        "options": mode_options(monitors, current),
        "baselineCount": len(baseline),
    })


def apply(mode: str) -> dict:
    monitors = run_json_command(["hyprctl", "-j", "monitors", "all"])
    baseline = read_baseline(monitors)
    plan = build_plan(mode, monitors, baseline, configured_monitors())

    for config in plan:
        try:
            result = subprocess.run(
                ["hyprctl", "eval", lua_monitor_command(config)],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise RuntimeError(f"Falha ao aplicar o modo de tela: {error}") from error
        if not monitor_command_succeeded(result):
            message = result.stderr.strip() or result.stdout.strip() or "Hyprland recusou a configuração."
            rollback_ok = True
            try:
                for original in baseline:
                    rollback = subprocess.run(
                        ["hyprctl", "eval", lua_monitor_command(original)],
                        capture_output=True,
                        text=True,
                        timeout=5,
                        check=False,
                    )
                    if not monitor_command_succeeded(rollback):
                        rollback_ok = False
            except (OSError, subprocess.TimeoutExpired):
                rollback_ok = False
            suffix = "Layout anterior restaurado." if rollback_ok else "Não foi possível restaurar o layout anterior automaticamente."
            raise RuntimeError(f"{message} {suffix}")

    return success({"appliedMode": mode, "monitorCount": len(plan)})


def main(argv: list[str]) -> int:
    if len(argv) == 1 and argv[0] == "status":
        action = status
    elif len(argv) == 2 and argv[0] == "apply":
        action = lambda: apply(argv[1])
    else:
        print(json.dumps(failure("Uso: display-projection.py status | apply <mode>")))
        return 2

    try:
        response = action()
    except (RuntimeError, ValueError) as error:
        response = failure(str(error))
    print(json.dumps(response, ensure_ascii=False))
    return 0 if response["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
