#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path
from command_utils import run_command

PLATFORM_PROFILE = Path("/sys/firmware/acpi/platform_profile")
PLATFORM_CHOICES = Path("/sys/firmware/acpi/platform_profile_choices")

LABELS = {
    "power-saver": "Economia",
    "balanced": "Equilibrado",
    "performance": "Desempenho",
}

PPD_TO_CANON = {
    "power-saver": "power-saver",
    "balanced": "balanced",
    "performance": "performance",
}

PLATFORM_TO_CANON = {
    "low-power": "power-saver",
    "quiet": "power-saver",
    "balanced": "balanced",
    "balanced-performance": "balanced",
    "performance": "performance",
}

CANON_TO_PLATFORM_PREFS = {
    "power-saver": ("low-power", "quiet"),
    "balanced": ("balanced", "balanced-performance"),
    "performance": ("performance",),
}

def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))

def run(args, timeout=3.0):
    return run_command(args, timeout, error_code=127, timeout_code=None)

def service_active(name):
    systemctl = shutil.which("systemctl")
    if not systemctl:
        return False
    rc, out, _ = run([systemctl, "is-active", name], timeout=1.5)
    return rc == 0 and out == "active"

def ppd_state():
    cmd = shutil.which("powerprofilesctl")
    if not cmd:
        return None

    # Avoid using powerprofilesctl when its system service is inactive.
    if not service_active("power-profiles-daemon.service"):
        return None

    rc, active, err = run([cmd, "get"])
    if rc != 0 or active not in PPD_TO_CANON:
        return None

    rc, profiles_out, _ = run([cmd, "list"])
    available = []
    for name in ("power-saver", "balanced", "performance"):
        if name in profiles_out:
            available.append(name)

    if not available:
        available = ["power-saver", "balanced", "performance"]

    return {
        "available": True,
        "backend": "power-profiles-daemon",
        "backend_label": "Power Profiles",
        "active": PPD_TO_CANON[active],
        "profiles": [
            {"id": p, "label": LABELS[p]} for p in available
        ],
        "requires_auth": False,
    }

def platform_state():
    if not PLATFORM_PROFILE.exists():
        return None

    try:
        active_raw = PLATFORM_PROFILE.read_text(encoding="utf-8").strip()
    except Exception:
        return None

    active = PLATFORM_TO_CANON.get(active_raw, "balanced")

    choices = []
    try:
        choices = PLATFORM_CHOICES.read_text(encoding="utf-8").split()
    except Exception:
        choices = [active_raw] if active_raw else []

    available = []
    for canonical in ("power-saver", "balanced", "performance"):
        prefs = CANON_TO_PLATFORM_PREFS[canonical]
        if any(x in choices for x in prefs):
            available.append(canonical)

    if not available:
        available = [active]

    return {
        "available": True,
        "backend": "platform-profile",
        "backend_label": "Platform profile",
        "active": active,
        "active_raw": active_raw,
        "choices_raw": choices,
        "profiles": [
            {"id": p, "label": LABELS[p]} for p in available
        ],
        "requires_auth": not os.access(PLATFORM_PROFILE, os.W_OK),
    }

def current_state():
    state = ppd_state() or platform_state()
    if state:
        state["ok"] = True
        state["version"] = 1
        state["error"] = None
        return state
    return {
        "ok": False,
        "version": 1,
        "available": False,
        "backend": "none",
        "backend_label": "Perfis indisponíveis",
        "active": "",
        "profiles": [],
        "requires_auth": False,
        "error": "Nenhum backend de perfil de energia disponível.",
    }

def set_ppd(profile):
    cmd = shutil.which("powerprofilesctl")
    if not cmd:
        return False, "powerprofilesctl não encontrado."
    rc, _, err = run([cmd, "set", profile], timeout=6.0)
    return rc == 0, err or "Não foi possível alterar o perfil."

def platform_target(profile):
    choices = []
    try:
        choices = PLATFORM_CHOICES.read_text(encoding="utf-8").split()
    except Exception:
        pass

    for candidate in CANON_TO_PLATFORM_PREFS.get(profile, ()):
        if not choices or candidate in choices:
            return candidate
    return ""

def set_platform(profile):
    target = platform_target(profile)
    if not target:
        return False, "Este perfil não é suportado pelo firmware."

    try:
        PLATFORM_PROFILE.write_text(target, encoding="utf-8")
        return True, ""
    except PermissionError:
        pass
    except Exception as exc:
        return False, str(exc)

    pkexec = shutil.which("pkexec")
    if not pkexec:
        return False, "É necessária autorização administrativa (pkexec não encontrado)."

    # target comes from a fixed allow-list above, not user-controlled shell text.
    command = f"printf '%s' '{target}' > {PLATFORM_PROFILE}"
    rc, _, err = run([pkexec, "sh", "-c", command], timeout=60.0)
    return rc == 0, err or "A alteração foi cancelada ou não autorizada."

def main():
    args = sys.argv[1:]

    if not args or args[0] == "status":
        emit(current_state())
        return 0

    if args[0] == "set":
        if len(args) < 2 or args[1] not in LABELS:
            emit({"ok": False, "version": 1, "error": "Perfil inválido."})
            return 2

        profile = args[1]
        state = current_state()

        if state["backend"] == "power-profiles-daemon":
            ok, err = set_ppd(profile)
        elif state["backend"] == "platform-profile":
            ok, err = set_platform(profile)
        else:
            ok, err = False, "Nenhum backend de perfil de energia disponível."

        result = current_state()
        result.update({"ok": ok, "version": 1, "error": err or None})
        emit(result)
        return 0 if ok else 1

    emit({"ok": False, "version": 1, "error": "Comando desconhecido."})
    return 2

if __name__ == "__main__":
    raise SystemExit(main())
