#!/usr/bin/env python3
"""Read and control desktop power profiles, including the Ultra Eco composite mode."""
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from command_utils import run_command
from lume_paths import config_dir, migrate_file

VERSION = 1
EXTRA_LOW_POWER_ID = "extra-low-power"
EXTRA_LOW_POWER_CAP_KHZ = 1600000
PLATFORM_PROFILE = Path("/sys/firmware/acpi/platform_profile")
PLATFORM_CHOICES = Path("/sys/firmware/acpi/platform_profile_choices")
PRIVILEGED_HELPER = Path("/usr/lib/lumeshell/lumeshell-power-profile")

LABELS = {
    EXTRA_LOW_POWER_ID: "Ultra Eco",
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
    EXTRA_LOW_POWER_ID: ("low-power", "quiet"),
    "power-saver": ("low-power", "quiet"),
    "balanced": ("balanced", "balanced-performance"),
    "performance": ("performance",),
}


def emit(obj):
    print(json.dumps(obj, ensure_ascii=False))


def run(args, timeout=3.0):
    return run_command(args, timeout, error_code=127, timeout_code=None)


def state_file_path():
    return migrate_file(config_dir() / "power" / "power-profile.json")


def boost_preference_path():
    return migrate_file(config_dir() / "power" / "cpu-boost.json")


def read_boost_preference(path=None):
    target = Path(path) if path else boost_preference_path()
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if isinstance(data, dict) and data.get("version") == VERSION and isinstance(data.get("enabled"), bool):
        return data["enabled"]
    return None


def read_saved_state(path=None):
    target = Path(path) if path else state_file_path()
    try:
        data = json.loads(target.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict) or data.get("version") != VERSION:
        return {}
    return data


def write_saved_state(payload, path=None):
    target = Path(path) if path else state_file_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".power-profile-", dir=target.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump({"version": VERSION, **payload}, handle)
            handle.write("\n")
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


def read_int_file(path):
    try:
        return int(Path(path).read_text(encoding="ascii").strip())
    except (OSError, ValueError):
        return None


def cpufreq_policies(sys_root="/sys"):
    cpufreq_dir = Path(sys_root) / "devices/system/cpu/cpufreq"
    if not cpufreq_dir.is_dir():
        return []
    return sorted(p for p in cpufreq_dir.glob("policy*") if p.is_dir())


def cpufreq_cap_supported(sys_root="/sys"):
    for policy in cpufreq_policies(sys_root):
        if (policy / "scaling_max_freq").is_file() and (policy / "cpuinfo_max_freq").is_file():
            return True
    return False


def cpufreq_is_capped(sys_root="/sys", cap_khz=EXTRA_LOW_POWER_CAP_KHZ):
    policies = cpufreq_policies(sys_root)
    if not policies:
        return False
    saw_policy = False
    for policy in policies:
        cur_max = read_int_file(policy / "scaling_max_freq")
        hw_max = read_int_file(policy / "cpuinfo_max_freq")
        hw_min = read_int_file(policy / "cpuinfo_min_freq")
        if cur_max is None or hw_max is None:
            continue
        saw_policy = True
        effective_cap = max(hw_min or 0, min(cap_khz, hw_max))
        if effective_cap >= hw_max:
            return False
        if cur_max > effective_cap + 50000:
            return False
    return saw_policy


def read_hardware_boost(sys_root="/sys"):
    root = Path(sys_root)
    generic = root / "devices/system/cpu/cpufreq/boost"
    if generic.is_file():
        val = read_int_file(generic)
        return None if val is None else (val == 1)
    intel = root / "devices/system/cpu/intel_pstate/no_turbo"
    if intel.is_file():
        val = read_int_file(intel)
        return None if val is None else (val == 0)
    return None


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

    rc, active, _ = run([cmd, "get"])
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


def with_extra_low_power_profile(profiles):
    items = list(profiles or [])
    if any(p.get("id") == EXTRA_LOW_POWER_ID for p in items):
        return items
    return [{"id": EXTRA_LOW_POWER_ID, "label": LABELS[EXTRA_LOW_POWER_ID], "icon": "leaf"}] + items


def current_state(sys_root="/sys", state_path=None):
    raw_state = ppd_state() or platform_state()
    if raw_state:
        state = dict(raw_state)
        saved = read_saved_state(state_path)
        has_cap_hw = cpufreq_cap_supported(sys_root)
        capped = cpufreq_is_capped(sys_root) if has_cap_hw else False

        extra_active = False
        if saved.get("extra_low_power"):
            if has_cap_hw and not capped:
                # Reboot or external cpufreq change cleared the cap; clear stale flag.
                try:
                    write_saved_state({"extra_low_power": False, "auto": False}, state_path)
                except OSError:
                    pass
            elif state.get("active") == "power-saver":
                extra_active = True
        elif capped and state.get("active") == "power-saver":
            extra_active = True

        state["profiles"] = with_extra_low_power_profile(state.get("profiles"))
        if extra_active:
            state["active"] = EXTRA_LOW_POWER_ID
            state["extra_low_power"] = True
            state["auto_activated"] = bool(saved.get("auto", False))
            state["previous_profile"] = str(saved.get("previous_profile") or "balanced")
        else:
            state["extra_low_power"] = False
            state["auto_activated"] = False
            state["previous_profile"] = ""

        state["ok"] = True
        state["version"] = VERSION
        state["error"] = None
        return state
    return {
        "ok": False,
        "version": VERSION,
        "available": False,
        "backend": "none",
        "backend_label": "Perfis indisponíveis",
        "active": "",
        "profiles": [],
        "extra_low_power": False,
        "auto_activated": False,
        "previous_profile": "",
        "requires_auth": False,
        "error": "Nenhum backend de perfil de energia disponível.",
    }


def set_ppd(profile, runner=run, which=shutil.which):
    cmd = which("powerprofilesctl")
    if not cmd:
        return False, "powerprofilesctl não encontrado."
    ppd_target = "power-saver" if profile == EXTRA_LOW_POWER_ID else profile
    rc, _, err = runner([cmd, "set", ppd_target], timeout=6.0)
    if rc == 0:
        return True, ""
    return False, err or "Não foi possível alterar o perfil."


def platform_target(profile, choices=None):
    if choices is None:
        choices = []
        try:
            choices = PLATFORM_CHOICES.read_text(encoding="utf-8").split()
        except Exception:
            pass

    for candidate in CANON_TO_PLATFORM_PREFS.get(profile, ()):
        if not choices or candidate in choices:
            return candidate
    return ""


def run_privileged_apply(platform_value, cap_mode, boost_mode, runner=run,
                         which=shutil.which, helper_path=PRIVILEGED_HELPER):
    if Path(helper_path).is_file():
        pkexec = which("pkexec")
        if not pkexec:
            return False, "É necessária autorização administrativa (pkexec não encontrado)."
        rc, _, err = runner(
            [pkexec, str(helper_path), "apply", platform_value, cap_mode, boost_mode],
            timeout=60.0,
        )
        if rc == 0:
            return True, ""
        return False, err or "A alteração foi cancelada ou não autorizada."

    # Compatibility fallback before the root-owned helper is installed.
    commands = []
    if platform_value != "skip":
        commands.append(f"printf '%s' '{platform_value}' > {PLATFORM_PROFILE}")
    if cap_mode == "cap-1600000":
        commands.append(
            "for p in /sys/devices/system/cpu/cpufreq/policy*; do "
            "[ -d \"$p\" ] || continue; "
            "min=$(cat \"$p/cpuinfo_min_freq\"); max=$(cat \"$p/cpuinfo_max_freq\"); "
            "t=1600000; [ \"$t\" -lt \"$min\" ] && t=$min; [ \"$t\" -gt \"$max\" ] && t=$max; "
            "printf '%s' \"$t\" > \"$p/scaling_max_freq\"; done"
        )
    elif cap_mode == "max":
        commands.append(
            "for p in /sys/devices/system/cpu/cpufreq/policy*; do "
            "[ -d \"$p\" ] || continue; "
            "cat \"$p/cpuinfo_max_freq\" > \"$p/scaling_max_freq\"; done"
        )
    if boost_mode == "boost-on":
        commands.append(
            "[ -f /sys/devices/system/cpu/cpufreq/boost ] && printf '1' > /sys/devices/system/cpu/cpufreq/boost || "
            "([ -f /sys/devices/system/cpu/intel_pstate/no_turbo ] && printf '0' > /sys/devices/system/cpu/intel_pstate/no_turbo || true)"
        )
    elif boost_mode == "boost-off":
        commands.append(
            "[ -f /sys/devices/system/cpu/cpufreq/boost ] && printf '0' > /sys/devices/system/cpu/cpufreq/boost || "
            "([ -f /sys/devices/system/cpu/intel_pstate/no_turbo ] && printf '1' > /sys/devices/system/cpu/intel_pstate/no_turbo || true)"
        )
    if not commands:
        return True, ""

    pkexec = which("pkexec")
    if not pkexec:
        return False, "É necessária autorização administrativa (pkexec não encontrado)."
    rc, _, err = runner([pkexec, "sh", "-c", " && ".join(commands)], timeout=60.0)
    if rc == 0:
        return True, ""
    return False, err or "A alteração foi cancelada ou não autorizada."


def set_platform(profile, cap_mode="keep", boost_mode="keep", runner=run,
                 which=shutil.which, helper_path=PRIVILEGED_HELPER):
    target = platform_target(profile)
    if not target:
        return False, "Este perfil não é suportado pelo firmware."

    if cap_mode == "keep" and boost_mode == "keep":
        try:
            PLATFORM_PROFILE.write_text(target, encoding="utf-8")
            return True, ""
        except PermissionError:
            pass
        except Exception as exc:
            return False, str(exc)

    return run_privileged_apply(target, cap_mode, boost_mode, runner=runner,
                                which=which, helper_path=helper_path)


def apply_profile(profile, auto=False, sys_root="/sys", state_path=None, boost_pref_path=None,
                  runner=run, which=shutil.which, helper_path=PRIVILEGED_HELPER):
    state = current_state(sys_root=sys_root, state_path=state_path)
    backend = state.get("backend", "none")
    if backend == "none":
        return False, "Nenhum backend de perfil de energia disponível."

    saved = read_saved_state(state_path)
    was_extra = bool(state.get("extra_low_power"))

    if profile == EXTRA_LOW_POWER_ID:
        if was_extra:
            prev_profile = str(saved.get("previous_profile") or "balanced")
            prev_boost = saved.get("previous_boost")
        else:
            current_active = str(state.get("active") or "balanced")
            prev_profile = current_active if current_active in PPD_TO_CANON else "balanced"
            pref_boost = read_boost_preference(boost_pref_path)
            prev_boost = pref_boost if pref_boost is not None else read_hardware_boost(sys_root)

        if backend == "power-profiles-daemon":
            ok, err = set_ppd(EXTRA_LOW_POWER_ID, runner=runner, which=which)
            if ok:
                ok, err = run_privileged_apply(
                    "skip", "cap-1600000", "boost-off",
                    runner=runner, which=which, helper_path=helper_path,
                )
        else:
            ok, err = set_platform(
                EXTRA_LOW_POWER_ID, cap_mode="cap-1600000", boost_mode="boost-off",
                runner=runner, which=which, helper_path=helper_path,
            )

        if ok:
            try:
                write_saved_state({
                    "extra_low_power": True,
                    "auto": bool(auto),
                    "previous_profile": prev_profile,
                    "previous_boost": prev_boost,
                }, state_path)
            except OSError as exc:
                return False, f"Perfil alterado, mas não foi possível salvar o estado: {exc}"
        return ok, err

    # Leaving extra-low-power (or switching among normal profiles).
    cap_mode = "max" if was_extra else "keep"
    boost_mode = "keep"
    if was_extra:
        restore_boost = read_boost_preference(boost_pref_path)
        if restore_boost is None:
            restore_boost = saved.get("previous_boost")
        if isinstance(restore_boost, bool):
            boost_mode = "boost-on" if restore_boost else "boost-off"

    if backend == "power-profiles-daemon":
        ok, err = set_ppd(profile, runner=runner, which=which)
        if ok and was_extra:
            ok, err = run_privileged_apply(
                "skip", cap_mode, boost_mode,
                runner=runner, which=which, helper_path=helper_path,
            )
    else:
        ok, err = set_platform(
            profile, cap_mode=cap_mode, boost_mode=boost_mode,
            runner=runner, which=which, helper_path=helper_path,
        )

    if ok and was_extra:
        try:
            write_saved_state({"extra_low_power": False, "auto": False}, state_path)
        except OSError:
            pass
    return ok, err


def main(args=None):
    args = sys.argv[1:] if args is None else args

    if not args or args[0] == "status":
        emit(current_state())
        return 0

    if args[0] == "set":
        if len(args) < 2 or args[1] not in LABELS:
            emit({"ok": False, "version": VERSION, "error": "Perfil inválido."})
            return 2

        profile = args[1]
        auto = "--auto" in args[2:]
        ok, err = apply_profile(profile, auto=auto)
        result = current_state()
        result.update({"ok": ok, "version": VERSION, "error": err or None})
        emit(result)
        return 0 if ok else 1

    emit({"ok": False, "version": VERSION, "error": "Comando desconhecido."})
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
