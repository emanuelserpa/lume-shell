#!/usr/bin/env python3
"""Read and control the Linux CPU frequency boost setting."""
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from command_utils import run_command

VERSION = 1
PRIVILEGED_HELPER = Path("/usr/local/libexec/quickshell-cpu-boost")
BACKENDS = (
    ("cpufreq", Path("devices/system/cpu/cpufreq/boost"), False),
    ("intel-pstate", Path("devices/system/cpu/intel_pstate/no_turbo"), True),
)


def preference_path():
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return config_home / "quickshell" / "power" / "cpu-boost.json"


def emit(result):
    print(json.dumps(result, ensure_ascii=False))


def detect_backend(sys_root="/sys"):
    root = Path(sys_root)
    for name, relative_path, inverted in BACKENDS:
        path = root / relative_path
        if path.is_file():
            return {"name": name, "path": path, "inverted": inverted}
    return None


def current_state(sys_root="/sys"):
    backend = detect_backend(sys_root)
    if backend is None:
        return {
            "ok": True, "version": VERSION, "available": False,
            "enabled": False, "requires_auth": False, "error": None,
        }

    try:
        raw = backend["path"].read_text(encoding="ascii").strip()
        if raw not in ("0", "1"):
            raise ValueError("valor sysfs inválido")
    except (OSError, ValueError) as exc:
        return {
            "ok": False, "version": VERSION, "available": True,
            "enabled": False, "requires_auth": False, "error": str(exc),
        }

    value = raw == "1"
    return {
        "ok": True,
        "version": VERSION,
        "available": True,
        "enabled": not value if backend["inverted"] else value,
        "requires_auth": not os.access(backend["path"], os.W_OK),
        "backend": backend["name"],
        "error": None,
    }


def write_preference(enabled, path=None):
    target = Path(path) if path else preference_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".cpu-boost-", dir=target.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as preference:
            json.dump({"version": VERSION, "enabled": bool(enabled)}, preference)
            preference.write("\n")
        os.replace(temporary, target)
    except Exception:
        try:
            os.close(descriptor)
        except OSError:
            pass
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def read_preference(path=None):
    target = Path(path) if path else preference_path()
    try:
        result = json.loads(target.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(result, dict):
        return None
    if result.get("version") != VERSION or not isinstance(result.get("enabled"), bool):
        return None
    return result["enabled"]


def initialize_default_preference(path=None):
    """Use boost-off as the first-install preference without overriding a choice."""
    current = read_preference(path)
    if current is not None:
        return {"ok": True, "version": VERSION, "saved": False,
                "enabled": current, "error": None}
    try:
        write_preference(False, path)
    except OSError as exc:
        return {"ok": False, "version": VERSION, "saved": False,
                "enabled": False, "error": str(exc)}
    return {"ok": True, "version": VERSION, "saved": True,
            "enabled": False, "error": None}


def set_state(enabled, sys_root="/sys", runner=run_command, which=shutil.which,
              helper_path=PRIVILEGED_HELPER, save_preference=True, preference=None):
    backend = detect_backend(sys_root)
    if backend is None:
        return False, "O controle de boost não está disponível neste sistema."

    raw_value = not enabled if backend["inverted"] else enabled
    value = "1" if raw_value else "0"
    try:
        backend["path"].write_text(value, encoding="ascii")
    except PermissionError:
        pkexec = which("pkexec")
        if not pkexec:
            return False, "É necessária autorização administrativa (pkexec não encontrado)."

        if Path(helper_path).is_file():
            command = [pkexec, str(helper_path), "on" if enabled else "off"]
        else:
            # Compatibility before the root-owned helper is installed. No user
            # input reaches the command string: the path and value are fixed here.
            command = [pkexec, "sh", "-c", f"printf '%s' '{value}' > {backend['path']}"]
        rc, _, error = runner(command, 60.0, error_code=127, timeout_code=None)
        if rc != 0:
            return False, error or "A alteração foi cancelada ou não autorizada."
    except OSError as exc:
        return False, str(exc)

    if save_preference:
        try:
            write_preference(enabled, preference)
        except OSError as exc:
            return False, f"Boost alterado, mas não foi possível salvar a preferência: {exc}"
    return True, ""


def restore_preference(runner=run_command, which=shutil.which,
                       helper_path=PRIVILEGED_HELPER, sys_root="/sys", path=None):
    enabled = read_preference(path)
    if enabled is None:
        return {"ok": True, "version": VERSION, "restored": False,
                "available": detect_backend(sys_root) is not None, "error": None}

    state = current_state(sys_root)
    if not state["available"] or not state["ok"]:
        state.update({"restored": False, "error": state.get("error")})
        return state
    if state["enabled"] == enabled:
        state.update({"restored": False, "error": None})
        return state
    if not Path(helper_path).is_file():
        return {"ok": False, "version": VERSION, "available": True,
                "restored": False,
                "error": "Helper administrativo ausente; instale a integração de boost."}

    pkexec = which("pkexec")
    if not pkexec:
        return {"ok": False, "version": VERSION, "available": True,
                "restored": False, "error": "pkexec não encontrado."}
    rc, _, error = runner(
        [pkexec, str(helper_path), "on" if enabled else "off"],
        60.0, error_code=127, timeout_code=None,
    )
    result = current_state(sys_root)
    restored = rc == 0 and result["ok"] and result["enabled"] == enabled
    result.update({
        "ok": restored,
        "version": VERSION,
        "restored": restored,
        "error": None if restored else (error or "Não foi possível restaurar o boost salvo."),
    })
    return result


def main(args=None):
    args = sys.argv[1:] if args is None else args
    if not args or args[0] == "status":
        emit(current_state())
        return 0

    if len(args) == 2 and args[0] == "set" and args[1] in ("on", "off"):
        ok, error = set_state(args[1] == "on")
        result = current_state()
        result.update({"ok": ok, "version": VERSION, "error": error or None})
        emit(result)
        return 0 if ok else 1

    if len(args) == 1 and args[0] == "restore":
        result = restore_preference()
        emit(result)
        return 0 if result["ok"] else 1

    if len(args) == 1 and args[0] == "initialize-default":
        result = initialize_default_preference()
        emit(result)
        return 0 if result["ok"] else 1

    emit({"ok": False, "version": VERSION, "error": "Use status ou set on|off."})
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
