#!/usr/bin/env bash
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SHELL_UNIT="lume-shell.service"
if [[ ! -e /usr/lib/systemd/user/lume-shell.service && ! -e "$CONFIG_HOME/systemd/user/lume-shell.service" ]]; then
    SHELL_UNIT="quickshell.service"
fi
SKIP_VALIDATE=false
OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

case "${1:-}" in
    "") ;;
    --skip-validate) SKIP_VALIDATE=true ;;
    --help|-h)
        cat <<'EOF'
Uso: scripts/doctor.sh [--skip-validate]

Confere dependências do shell, configurações do usuário, integração da sessão
ativa, serviço/log do Quickshell e a configuração do boost. Por padrão, também
roda scripts/validate.sh. Não altera configurações nem reinicia serviços.
EOF
        exit 0
        ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
esac

ok() { printf '[OK]   %s\n' "$1"; OK_COUNT=$((OK_COUNT + 1)); }
warn() { printf '[WARN] %s\n' "$1"; WARN_COUNT=$((WARN_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

need_command() {
    local name="$1" purpose="$2"
    if command -v "$name" >/dev/null 2>&1; then
        ok "$name disponível ($purpose)"
    else
        fail "$name ausente; necessário para $purpose"
    fi
}

feature_command() {
    local name="$1" purpose="$2"
    if command -v "$name" >/dev/null 2>&1; then
        ok "$name disponível ($purpose)"
    else
        warn "$name ausente; recurso indisponível: $purpose"
    fi
}

feature_any_command() {
    local purpose="$1"
    shift
    local name found=""
    for name in "$@"; do
        if command -v "$name" >/dev/null 2>&1; then
            found+="${found:+, }$name"
        fi
    done
    if [[ -n "$found" ]]; then
        ok "$found disponível ($purpose)"
    else
        warn "Nenhum de ($*) disponível; recurso indisponível: $purpose"
    fi
}

check_dependency_manifest() {
    local manifest="$REPO_ROOT/data/dependencies.json"
    if ! command -v python3 >/dev/null 2>&1; then
        fail "python3 ausente; necessário para ler o manifesto de dependências"
        return
    fi
    if [[ ! -s "$manifest" ]]; then
        fail "Manifesto de dependências ausente: $manifest"
        return
    fi
    if ! python3 - "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
assert data.get("schema_version") == 1
assert isinstance(data.get("requirements"), list)
assert isinstance(data.get("alternatives"), list)
assert isinstance(data.get("python_modules"), list)
assert isinstance(data.get("qml_modules"), list)
assert isinstance(data.get("profiles"), dict)
assert isinstance(data.get("services"), list)
for item in data["requirements"]:
    assert item.get("level") in {"required", "feature"}
    assert item.get("command") and item.get("purpose")
    assert "arch_package" in item and item.get("arch_source")
    assert item["arch_package"] or item["arch_source"] == "external"
for item in data["alternatives"]:
    assert item.get("commands") and item.get("purpose")
    assert item.get("arch_packages") and item.get("arch_source")
for item in data["python_modules"]:
    assert item.get("module") and item.get("purpose") and item.get("arch_package")
    assert item.get("level") in {"required", "feature"}
for item in data["qml_modules"]:
    assert item.get("import") and item.get("arch_package")
for profile, requirements in data["profiles"].items():
    assert profile in {"hyprland", "labwc", "mango"}
    assert isinstance(requirements, list)
    for item in requirements:
        assert item.get("command") and item.get("purpose")
        assert item.get("level") in {"required", "feature"}
        assert item.get("arch_package") and item.get("arch_source")
for item in data["services"]:
    assert item.get("unit") and item.get("feature") and item.get("arch_package")
PY
    then
        fail "Manifesto de dependências inválido: $manifest"
        return
    fi
    ok "Manifesto de dependências válido (schema 1)"

    while IFS=$'\t' read -r level command purpose; do
        [[ -n "$command" ]] || continue
        [[ "$level" == "alternative" ]] && continue
        if [[ "$level" == "required" ]]; then
            need_command "$command" "$purpose"
        else
            feature_command "$command" "$purpose"
        fi
    done < <(python3 - "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
for item in data["requirements"]:
    print(f'{item["level"]}\t{item["command"]}\t{item["purpose"]}')
for item in data["alternatives"]:
    print(f'alternative\t{",".join(item["commands"])}\t{item["purpose"]}')
PY
    )

    while IFS=$'\t' read -r level module purpose; do
        [[ -n "$module" ]] || continue
        if python3 - "$module" <<'PY'
import importlib.util
import sys
sys.exit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
        then
            ok "Módulo Python disponível: $module ($purpose)"
        elif [[ "$level" == "required" ]]; then
            fail "Módulo Python ausente: $module ($purpose)"
        else
            warn "Módulo Python ausente; recurso indisponível: $module ($purpose)"
        fi
    done < <(python3 - "$manifest" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
for item in data["python_modules"]:
    print(f'{item["level"]}\t{item["module"]}\t{item["purpose"]}')
PY
    )

    while IFS=$'\t' read -r _ commands purpose; do
        [[ -n "$commands" ]] || continue
        IFS=, read -r -a alternatives <<< "$commands"
        feature_any_command "$purpose" "${alternatives[@]}"
    done < <(python3 - "$manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
for item in data["alternatives"]:
    print(f'alternative\t{",".join(item["commands"])}\t{item["purpose"]}')
PY
    )
}

required_file() {
    local path="$1" purpose="$2"
    if [[ -s "$path" ]]; then
        ok "Arquivo presente: $path ($purpose)"
    else
        fail "Arquivo ausente ou vazio: $path ($purpose)"
    fi
}

optional_file() {
    local path="$1" purpose="$2"
    if [[ -s "$path" ]]; then
        ok "Arquivo presente: $path ($purpose)"
    else
        warn "Arquivo não encontrado: $path ($purpose)"
    fi
}

check_hyprlock_profile() {
    local session="$1"
    need_command hyprlock "bloqueio de tela no perfil $session"
    required_file "$CONFIG_HOME/hypr/hyprlock.conf" "perfil Hyprlock"
    required_file "$CONFIG_HOME/hypr/scripts/hyprlock-battery.sh" "rótulo de bateria do Hyprlock"
    optional_file "$HOME/.cache/hypr/hyprlock_colors.conf" "paleta inicial do Hyprlock"
}

check_profile_manifest() {
    local profile="$1" manifest="$REPO_ROOT/data/dependencies.json"
    while IFS=$'\t' read -r level command purpose; do
        [[ -n "$command" ]] || continue
        if [[ "$level" == "required" ]]; then
            need_command "$command" "$purpose"
        else
            feature_command "$command" "$purpose"
        fi
    done < <(python3 - "$manifest" "$profile" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    data = json.load(stream)
for item in data["profiles"].get(sys.argv[2], []):
    print(f'{item["level"]}\t{item["command"]}\t{item["purpose"]}')
PY
    )
}

printf 'Diagnóstico Lume / Quickshell — %s\n\n' "$REPO_ROOT"

# Base process and shell requirements.
check_dependency_manifest
required_file "$REPO_ROOT/shell.qml" "raiz da configuração Quickshell"
required_file "$REPO_ROOT/Theme.qml" "tema compartilhado"
if [[ -e "/usr/lib/systemd/user/$SHELL_UNIT" || -e "$CONFIG_HOME/systemd/user/$SHELL_UNIT" ]]; then
    ok "Unidade de sessão encontrada: $SHELL_UNIT"
else
    warn "Unidade de sessão não instalada; habilite $SHELL_UNIT ou configure uma unidade de desenvolvimento"
fi
if [[ -s "$CONFIG_HOME/kitty/kitty.conf" ]]; then
    ok "Configuração do Kitty disponível"
else
    warn "Configuração do Kitty ausente; atalhos do terminal podem precisar de ajuste"
fi

for font in "Noto Sans" "Nerd Font"; do
    if fc-list : family 2>/dev/null | grep -Fqi "$font"; then
        ok "Fonte instalada: $font"
    else
        warn "Fonte ausente: $font"
    fi
done

# Check the config for the currently selected compositor, not unused configs
# belonging to other sessions installed on the same machine.
desktop="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-}"
desktop="${desktop,,}"
if [[ "$desktop" == *hyprland* ]]; then
    check_profile_manifest hyprland
    check_hyprlock_profile "Hyprland"
    required_file "$CONFIG_HOME/hypr/hyprland.lua" "configuração Hyprland ativa"
    optional_file "$CONFIG_HOME/hypr/monitors.lua" "layouts de monitor Hyprland"
    if command -v hyprctl >/dev/null 2>&1; then
        hypr_errors="$(hyprctl configerrors 2>&1)"
        if [[ -z "${hypr_errors//[[:space:]]/}" ]]; then
            ok "Hyprland não reporta erros na configuração carregada"
        elif [[ "$hypr_errors" == *"Couldn't connect"* \
            || "$hypr_errors" == *"Couldn't set socket timeout"* \
            || "$hypr_errors" == *"HYPRLAND_INSTANCE_SIGNATURE"* ]]; then
            warn "Não foi possível consultar os erros da sessão Hyprland: $hypr_errors"
        else
            fail "Hyprland reporta erros de configuração: $hypr_errors"
        fi
    fi
elif [[ "$desktop" == *labwc* ]]; then
    check_profile_manifest labwc
    check_hyprlock_profile "labwc"
    rc_xml="$CONFIG_HOME/labwc/rc.xml"
    required_file "$rc_xml" "atalhos e regras da sessão labwc"
    if [[ -s "$rc_xml" ]] && python3 - "$rc_xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY
    then
        ok "labwc rc.xml é XML válido"
    else
        fail "labwc rc.xml não pode ser interpretado como XML"
    fi
    optional_file "$CONFIG_HOME/labwc/autostart" "programas iniciados pelo labwc"
elif [[ "$desktop" == *mango* ]]; then
    check_profile_manifest mango
    required_file "$CONFIG_HOME/mango/config.conf" "configuração Mango"
else
    warn "Compositor ativo não identificado (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-vazio}); verificações específicas ignoradas"
fi

# Verify CPU boost persistence integration added by scripts/install-cpu-boost-system.sh.
if [[ -x /usr/local/libexec/quickshell-cpu-boost \
    && -s "$CONFIG_HOME/systemd/user/cpu-boost-restore.service" ]]; then
    if [[ -r /etc/polkit-1/rules.d/50-quickshell-cpu-boost.rules ]]; then
        if grep -Fq "subject.user === \"${USER:-}\"" \
            /etc/polkit-1/rules.d/50-quickshell-cpu-boost.rules \
            && grep -Fq '"/usr/local/libexec/quickshell-cpu-boost"' \
                /etc/polkit-1/rules.d/50-quickshell-cpu-boost.rules; then
            ok "Helper, regra polkit desta conta e unidade de restauração instalados"
        else
            fail "Regra polkit não está restrita a esta conta e ao helper esperado"
        fi
    else
        warn "Helper e unidade de boost existem, mas este contexto não pode ler a regra polkit"
    fi
    if [[ -e /sys/devices/system/cpu/cpufreq/boost \
        || -e /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
        ok "Kernel expõe controle de boost de CPU"
    else
        warn "Kernel não expõe uma interface compatível de boost de CPU"
    fi
    if [[ -f "$CONFIG_HOME/quickshell/power/cpu-boost.json" ]]; then
        if python3 - "$CONFIG_HOME/quickshell/power/cpu-boost.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as stream:
    value = json.load(stream)
assert value.get("version") == 1 and isinstance(value.get("enabled"), bool)
PY
        then
            ok "Preferência de boost salva e válida"
        else
            fail "Preferência de boost existe, mas está inválida"
        fi
    else
        warn "Nenhuma preferência de boost salva ainda"
    fi
else
    warn "Persistência de boost não instalada (opcional); consulte docs/power-controls.md"
fi

# User systemd can be inaccessible in containers/sandboxed diagnostics. Report
# that as unknown instead of claiming the service is broken.
bus="$RUNTIME_DIR/bus"
if [[ -S "$bus" ]] && command -v systemctl >/dev/null 2>&1; then
    service_state="$(systemctl --user is-active "$SHELL_UNIT" 2>&1)"
    if [[ "$service_state" == active ]]; then
        ok "$SHELL_UNIT está ativo"
    elif [[ "$service_state" == *"Operation not permitted"* || "$service_state" == *"Failed to connect to user scope bus"* ]]; then
        warn "Não foi possível consultar systemd --user neste contexto: $service_state"
    else
        fail "$SHELL_UNIT não está ativo ($service_state)"
    fi

    enabled_state="$(systemctl --user is-enabled "$SHELL_UNIT" 2>&1)"
    if [[ "$enabled_state" == enabled || "$enabled_state" == enabled-runtime ]]; then
        ok "$SHELL_UNIT habilitado no login"
    elif [[ "$enabled_state" == *"Operation not permitted"* || "$enabled_state" == *"Failed to connect to user scope bus"* ]]; then
        warn "Não foi possível consultar se quickshell.service está habilitado"
    else
        warn "$SHELL_UNIT não está habilitado ($enabled_state)"
    fi

    if [[ -s "$CONFIG_HOME/systemd/user/cpu-boost-restore.service" ]]; then
        boost_unit_state="$(systemctl --user is-enabled cpu-boost-restore.service 2>&1)"
        if [[ "$boost_unit_state" == enabled || "$boost_unit_state" == enabled-runtime ]]; then
            ok "cpu-boost-restore.service habilitado no login"
        elif [[ "$boost_unit_state" == *"Operation not permitted"* \
            || "$boost_unit_state" == *"Failed to connect to user scope bus"* ]]; then
            warn "Não foi possível consultar se cpu-boost-restore.service está habilitado"
        else
            warn "cpu-boost-restore.service não está habilitado ($boost_unit_state)"
        fi
    fi
else
    warn "Barramento systemd do usuário indisponível; estado do serviço ignorado"
fi

# Check only errors since the most recent successful config load, so an old
# recovered reload failure in the persistent log does not produce a false alarm.
log_root="$RUNTIME_DIR/quickshell/by-id"
latest_log=""
if [[ -d "$log_root" ]]; then
    latest_log="$(find "$log_root" -mindepth 2 -maxdepth 2 -type f -name log.log \
        -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)"
fi
if [[ -n "$latest_log" ]]; then
    log_state="$(awk '
        /Configuration Loaded/ { loaded=1; issues=""; next }
        loaded && /ERROR:|Failed to load configuration|Type .* unavailable/ { issues=issues $0 "\n" }
        END {
            if (!loaded) { print "NO_LOAD"; exit 2 }
            if (issues != "") { printf "%s", issues; exit 1 }
            print "CLEAN"
        }
    ' "$latest_log")"
    if [[ "$log_state" == CLEAN ]]; then
        ok "Log da instância mais recente sem erros após Configuration Loaded"
    elif [[ "$log_state" == NO_LOAD ]]; then
        fail "O log mais recente não registra Configuration Loaded: $latest_log"
    else
        fail "Erros QML após a última carga em $latest_log: $log_state"
    fi
else
    warn "Log ativo do Quickshell não encontrado em $log_root"
fi

if [[ "$SKIP_VALIDATE" == false ]]; then
    printf '\nValidação estrutural e testes do projeto:\n'
    if "$REPO_ROOT/scripts/validate.sh"; then
        ok "validate.sh e testes do projeto"
    else
        fail "validate.sh reportou falhas"
    fi
fi

printf '\nResumo: %d OK, %d avisos, %d falha(s)\n' "$OK_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
    exit 1
fi
