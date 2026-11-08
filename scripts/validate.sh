#!/usr/bin/env bash
set -uo pipefail

export PYTHONDONTWRITEBYTECODE=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

LIVE_CHECKS=false
SPOTLIGHT_LATENCY=false
for arg in "$@"; do
    case "$arg" in
        --offline) ;;
        --live) LIVE_CHECKS=true ;;
        --spotlight-latency) SPOTLIGHT_LATENCY=true ;;
        --visual) exec "$REPO_ROOT/scripts/visual-check.sh" ;;
        --help|-h)
            cat <<'HELP'
Uso: scripts/validate.sh [--offline] [--live] [--spotlight-latency] [--visual]

Sem opções (ou com --offline), executa verificações locais sem sondar hardware,
rede ou IPC do shell. --live habilita sondagens reais dos helpers. A medição
--spotlight-latency alterna o Spotlight da sessão e exige autorização explícita.
--visual encaminha para o checklist visual interativo.
HELP
            exit 0
            ;;
        *) echo "Opção desconhecida: $arg" >&2; exit 2 ;;
    esac
done

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

record_ok() {
    local msg="$1"
    echo -e "[OK] $msg"
    OK_COUNT=$((OK_COUNT + 1))
}

record_warn() {
    local msg="$1"
    echo -e "[WARN] $msg"
    WARN_COUNT=$((WARN_COUNT + 1))
}

record_fail() {
    local msg="$1"
    echo -e "[FAIL] $msg"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# -----------------------------------------------------------------------------
# A. Python Syntax Check
# -----------------------------------------------------------------------------
py_syntax_ok=true
py_count=0
while IFS= read -r py_file; do
    py_count=$((py_count + 1))
    if ! python3 -B -c 'import pathlib, sys; p = pathlib.Path(sys.argv[1]); compile(p.read_bytes(), str(p), "exec")' "$py_file" 2>/dev/null; then
        record_fail "Python syntax error in: $py_file"
        py_syntax_ok=false
    fi
done < <(find scripts tests -type f -name "*.py" | sort)

if [ "$py_syntax_ok" = true ]; then
    record_ok "Python syntax ($py_count files compiled)"
fi

# -----------------------------------------------------------------------------
# A2. QML Static Check (qmllint)
# -----------------------------------------------------------------------------
# Catches whole-shell breakers (unknown types, syntax errors) that would
# otherwise only surface as "Failed to load configuration" on hot-reload.
# Only hard errors fail; style warnings are ignored.
qmllint_bin=""
for cand in /usr/lib/qt6/bin/qmllint "$(command -v qmllint 2>/dev/null || true)"; do
    [ -n "$cand" ] && [ -x "$cand" ] && { qmllint_bin="$cand"; break; }
done

if [ -z "$qmllint_bin" ]; then
    if [[ "${CI:-}" == "true" ]]; then
        record_fail "qmllint is required in CI"
    else
        record_warn "qmllint not found (skipping static QML check)"
    fi
else
    qml_import_args=(-I "$REPO_ROOT" -I /usr/lib/qt6/qml)
    while IFS= read -r qmldir; do
        qml_import_args+=(-i "$REPO_ROOT/${qmldir#./}")
    done < <(find . -not -path './.*' -name qmldir | sort)

    qml_lint_fail=""
    qml_lint_count=0
    while IFS= read -r qml_file; do
        qml_lint_count=$((qml_lint_count + 1))
        lint_out="$("$qmllint_bin" "${qml_import_args[@]}" "$qml_file" 2>&1)"
        lint_rc=$?
        if [ "$lint_rc" -ne 0 ] || echo "$lint_out" | grep -qE "^Error"; then
            record_fail "qmllint error in: $qml_file"$'\n'"$lint_out"
            qml_lint_fail=true
        fi
    done < <(find . -not -path './.*' -name "*.qml" | sort)
    if [ -z "$qml_lint_fail" ]; then
        record_ok "qmllint static check ($qml_lint_count files, errors only)"
    fi

    qml_files=()
    while IFS= read -r -d '' qml_file; do
        qml_files+=("$qml_file")
    done < <(find . -not -path './.*' -name "*.qml" -print0 | sort -z)

    qml_policy_out="$($qmllint_bin \
        "${qml_import_args[@]}" \
        -W 0 \
        --only-explicit-categories \
        --assignment-in-condition error \
        --comma error \
        --confusing-expression-statement error \
        --deprecated error \
        --duplicate-import error \
        --eval error \
        --read-only-property error \
        --redundant-optional-chaining error \
        --stale-property-read error \
        --unreachable-code error \
        --unqualified error \
        --var-used-before-declaration error \
        --with error \
        "${qml_files[@]}" 2>&1)"
    qml_policy_rc=$?
    if [ "$qml_policy_rc" -eq 0 ]; then
        record_ok "qmllint strict check (zero warnings, 13 quality rules, ${#qml_files[@]} files)"
    else
        record_fail "qmllint quality rules failed:"$'\n'"$(echo "$qml_policy_out" | tail -n 30)"
    fi

    notification_test="$REPO_ROOT/tests/qml/tst_notification_content.qml"
    if [ -f "$notification_test" ]; then
        notification_lint_out="$($qmllint_bin -W 0 "${qml_import_args[@]}" "$notification_test" 2>&1)"
        notification_lint_rc=$?
        if [ "$notification_lint_rc" -eq 0 ]; then
            record_ok "qmllint strict check (notification QML tests, no warnings)"
        else
            record_fail "qmllint strict check failed for notification QML tests:"$'\n'"$notification_lint_out"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# A2b. Shared UI Component Guard (new QML files)
# -----------------------------------------------------------------------------
# New popup surfaces should start from the shared header/row/empty-state
# components. The core abstractions themselves are the only built-in
# allowlist; intentional bespoke delegates must carry a reason marker.
ui_guard_files=()
while IFS= read -r qml_file; do
    [ -n "$qml_file" ] && ui_guard_files+=("$qml_file")
done < <({
    ui_guard_base="$(tr -d '[:space:]' < "$REPO_ROOT/docs/shared-ui-guard-baseline.txt" 2>/dev/null || true)"
    if [ -n "$ui_guard_base" ] && git rev-parse --verify "$ui_guard_base^{commit}" >/dev/null 2>&1; then
        git diff --diff-filter=A --name-only "$ui_guard_base" -- '*.qml' 2>/dev/null || true
    else
        git diff --diff-filter=A --name-only HEAD -- '*.qml' 2>/dev/null || true
        git diff-tree --no-commit-id --diff-filter=A --name-only -r HEAD -- '*.qml' 2>/dev/null || true
    fi
    git ls-files --others --exclude-standard -- '*.qml' 2>/dev/null || true
} | sort -u)

ui_guard_findings=()
for qml_file in "${ui_guard_files[@]}"; do
    [ -f "$qml_file" ] || continue
    case "$qml_file" in
        components/PopupHeader.qml|components/PopupListRow.qml|components/EmptyState.qml|components/ScrollableList.qml|components/SettingToggleRow.qml)
            continue
            ;;
    esac
    if grep -qF "shared-ui-guard: allow" "$qml_file"; then
        continue
    fi

    has_header_component=false
    has_row_component=false
    has_empty_component=false
    grep -qE '(^|[[:space:]])PopupHeader[[:space:]]*\{' "$qml_file" && has_header_component=true
    grep -qE '(^|[[:space:]])PopupListRow[[:space:]]*\{' "$qml_file" && has_row_component=true
    grep -qE '(^|[[:space:]])EmptyState[[:space:]]*\{' "$qml_file" && has_empty_component=true

    if grep -qE 'id:[[:space:]]*(headerRow|popupHeaderRow|manualHeader)' "$qml_file" && [ "$has_header_component" = false ]; then
        ui_guard_findings+=("$qml_file: hand-built popup header marker; use PopupHeader")
    fi
    if grep -qE 'delegate:[[:space:]]*(Rectangle|Item)[[:space:]]*\{' "$qml_file" \
        && grep -qE 'HoverHandler|containsMouse' "$qml_file" \
        && [ "$has_row_component" = false ]; then
        ui_guard_findings+=("$qml_file: interactive hand-built delegate; use PopupListRow or add a reason marker")
    fi
    if grep -qE 'text:[[:space:]]*"(Sem|Nenhum|Nenhuma)([[:space:]]|")' "$qml_file" \
        && [ "$has_empty_component" = false ]; then
        ui_guard_findings+=("$qml_file: hand-built empty-state text; use EmptyState")
    fi
done

if [ "${#ui_guard_findings[@]}" -eq 0 ]; then
    record_ok "Shared UI component guard (${#ui_guard_files[@]} new QML files checked)"
else
    record_fail "New QML files reimplement shared UI patterns:"$'\n'"$(printf '%s\n' "${ui_guard_findings[@]}")"
fi

# Docs-vs-code: shared components must actually be shared. Fails when docs
# claim a component is (intentionally) unused while code uses it, or when a
# documented shared component ends up with zero consumers.
docs_drift_findings=()
for shared_component in PopupHeader PopupListRow EmptyState SearchField SettingToggleRow ScrollableList MaterialSwitch CommandJson CommandAction GalleryNav WallpaperState; do
    consumers="$(grep -rlE "(^|[[:space:]])${shared_component}[[:space:]]*(\{|$)" \
        bar launcher notifications osd services controlcenter --include='*.qml' 2>/dev/null || true)"
    # JS singletons are consumed as bare identifiers (GalleryNav.gridMove).
    if [ -z "$consumers" ]; then
        consumers="$(grep -rlE "(^|[^[:alnum:]_])${shared_component}\." \
            bar launcher notifications osd services controlcenter --include='*.qml' \
            --include='*.js' 2>/dev/null | grep -v "components/${shared_component}\|services/${shared_component}\|launcher/${shared_component}" || true)"
    fi
    if [ -z "$consumers" ]; then
        docs_drift_findings+=("$shared_component: documented as shared but has no consumers (remove it or document as intentionally local)")
        continue
    fi
    if grep -rE -B2 -A2 "${shared_component}[^[:alnum:]_]" docs/ 2>/dev/null \
        | grep -qiE "not used|unused|no longer used"; then
        docs_drift_findings+=("$shared_component: docs say unused but code uses it")
    fi
done

if [ "${#docs_drift_findings[@]}" -eq 0 ]; then
    record_ok "Docs-vs-code shared component consistency"
else
    record_fail "Docs/code drift in shared components:"$'\n'"$(printf '%s\n' "${docs_drift_findings[@]}")"
fi

# Keep component colors bound to the active theme. Hex palette values,
# numeric Qt.rgba/Qt.rgb/Qt.hsla literals belong in Theme.qml and ThemeState.qml,
# the centralized theme definitions.
hardcoded_qml_colors="$(grep -RInE --include='*.qml' \
    --exclude='Theme.qml' --exclude='ThemeState.qml' --exclude-dir='tests' \
    '(#[[:xdigit:]]{3,8}\b|Qt\.(rgba|rgb|hsla|hsva)\s*\(\s*[0-9])' \
    "$REPO_ROOT" 2>/dev/null || true)"
if [ -z "$hardcoded_qml_colors" ]; then
    record_ok "QML component colors use centralized theme tokens"
else
    color_count=$(printf "%s\n" "$hardcoded_qml_colors" | wc -l)
    record_fail "Hardcoded QML colors found outside theme definitions ($color_count occurrences):"$'\n'"$hardcoded_qml_colors"
fi

# -----------------------------------------------------------------------------
# B. Executable Bits Check
# -----------------------------------------------------------------------------
exec_ok=true
exec_count=0
for script in scripts/*; do
    [ -f "$script" ] || continue
    # Check if first line has a shebang
    first_line="$(head -n 1 "$script" 2>/dev/null || true)"
    if [[ "$first_line" =~ ^#! ]]; then
        exec_count=$((exec_count + 1))
        if [ ! -x "$script" ]; then
            record_fail "Script has shebang but is not executable: $script"
            exec_ok=false
        fi
    fi
done

if [ "$exec_ok" = true ]; then
    record_ok "Executable scripts ($exec_count checked)"
fi

if bash -n "$REPO_ROOT/scripts/install-cpu-boost-system.sh" \
    && bash -n "$REPO_ROOT/scripts/doctor.sh" \
    && sh -n "$REPO_ROOT/system/cpu-boost-privileged"; then
    record_ok "System integration and doctor shell syntax"
else
    record_fail "System integration or doctor shell syntax"
fi

# -----------------------------------------------------------------------------
# C. QML Module & qmldir Sanity
# -----------------------------------------------------------------------------
qml_sanity_ok=true
qmldir_count=0

while IFS= read -r qmldir_path; do
    qmldir_count=$((qmldir_count + 1))
    qml_dir="$(dirname "$qmldir_path")"
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim whitespace
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$line" ] && continue
        [[ "$line" =~ ^# ]] && continue
        [[ "$line" =~ ^module[[:space:]] ]] && continue

        # Extract the last token which should be the .qml filename
        target_file="$(echo "$line" | awk '{print $NF}')"
        if [[ "$target_file" =~ \.qml$ ]]; then
            if [ ! -f "$qml_dir/$target_file" ]; then
                record_fail "qmldir in $qml_dir references missing file: $target_file"
                qml_sanity_ok=false
            fi
        fi
    done < "$qmldir_path"
done < <(find . -name "qmldir" | sort)

# Verify standard local modules exist
for mod in bar components launcher notifications osd services; do
    if [ ! -d "$REPO_ROOT/$mod" ]; then
        record_fail "Expected QML module directory missing: $mod"
        qml_sanity_ok=false
    fi
done

# Reverse direction: every .qml file must be registered in its dir's qmldir.
# An unregistered component fails at runtime ("X is not a type") while
# passing every other check, and can crash the shell on startup.
# Exception: shell.qml is the root entry point, not a module type.
while IFS= read -r qmldir_path; do
    qml_dir="$(dirname "$qmldir_path")"
    registered="$(awk '!/^#/ && !/^module[[:space:]]/ && NF {print $NF}' "$qmldir_path" | grep '\.qml$' || true)"
    while IFS= read -r qml_file; do
        base="$(basename "$qml_file")"
        [ "$base" = "shell.qml" ] && continue
        if ! grep -qxF "$base" <<< "$registered"; then
            record_fail "QML file not registered in $qml_dir/qmldir: $base"
            qml_sanity_ok=false
        fi
    done < <(find "$qml_dir" -maxdepth 1 -type f -name "*.qml" | sort)
done < <(find . -name "qmldir" | sort)

if [ "$qml_sanity_ok" = true ]; then
    record_ok "QML module files & singletons ($qmldir_count qmldir checked)"
fi

# -----------------------------------------------------------------------------
# D. shell.qml Baseline Sanity
# -----------------------------------------------------------------------------
shell_baseline_ok=true
if [ ! -f "$REPO_ROOT/shell.qml" ]; then
    record_fail "Missing root shell.qml"
    shell_baseline_ok=false
fi

if [ ! -f "$REPO_ROOT/Theme.qml" ]; then
    record_fail "Missing root Theme.qml"
    shell_baseline_ok=false
fi

# Essential components instantiated in shell.qml
for comp in \
    "services/ClipboardService.qml" \
    "launcher/Spotlight.qml" \
    "bar/Bar.qml" \
    "osd/Osd.qml" \
    "notifications/NotificationToasts.qml"; do
    if [ ! -f "$REPO_ROOT/$comp" ]; then
        record_fail "shell.qml baseline component missing: $comp"
        shell_baseline_ok=false
    fi
done

if [ "$shell_baseline_ok" = true ]; then
    record_ok "shell.qml baseline & root components"
fi

# -----------------------------------------------------------------------------
# E. JSON Helpers Execution (Safe Non-Destructive Helpers)
# -----------------------------------------------------------------------------
run_json_helper() {
    local name="$1"
    shift
    local cmd=("$@")

    local stdout_file
    stdout_file="$(mktemp)"
    local stderr_file
    stderr_file="$(mktemp)"

    local rc=0
    python3 -B "${cmd[@]}" >"$stdout_file" 2>"$stderr_file" || rc=$?

    # Verify JSON validity via python
    local json_check
    json_check="$(python3 -c "
import json, sys
try:
    with open('$stdout_file', 'r', encoding='utf-8') as f:
        data = json.load(f)
    available = data.get('available', True)
    status = data.get('status', 'ok')
    err = data.get('error', '')
    if status == 'error' or available is False:
        print('WARN:' + (str(err) or 'service unavailable'))
    else:
        print('OK')
except Exception as e:
    print('FAIL:' + str(e))
" 2>/dev/null || echo "FAIL:parser crash")"

    rm -f "$stdout_file" "$stderr_file"

    if [ "$rc" -ne 0 ]; then
        record_fail "JSON helper: $name exited with status $rc"
        return
    fi

    if [[ "$json_check" =~ ^OK ]]; then
        record_ok "JSON helper: $name"
    elif [[ "$json_check" =~ ^WARN:(.*) ]]; then
        local reason="${BASH_REMATCH[1]}"
        record_warn "$name: $reason"
    else
        record_fail "JSON helper: $name returned invalid output ($json_check)"
    fi
}

if [ "$LIVE_CHECKS" = true ]; then
    run_json_helper "network-status" scripts/network-status.py
    run_json_helper "bluetooth-status" scripts/bluetooth-status.py
    run_json_helper "kdeconnect-status" scripts/kdeconnect-status.py
    run_json_helper "printer-status" scripts/printer-status.py
    run_json_helper "brightness-status" scripts/brightness-status.py
    run_json_helper "energy-profile" scripts/energy-profile.py status
    run_json_helper "cpu-boost" scripts/cpu-boost.py status
    run_json_helper "battery-health" scripts/battery-health.py
    run_json_helper "hardware-sensors" scripts/hardware-sensors.py
    run_json_helper "nightlight-status" scripts/nightlight-manager.py status
    run_json_helper "weather" scripts/weather-fetch.py
    run_json_helper "ytdlp-download" scripts/ytdlp-download.py recent
else
    record_ok "Live network and hardware probes skipped (use --live to run)"
fi

# -----------------------------------------------------------------------------
# F. Undesirable Files Check
# -----------------------------------------------------------------------------
unwanted_files=()
while IFS= read -r f; do
    [ -n "$f" ] && unwanted_files+=("$f")
done < <(find . -not -path '*/.*' \( -name "*.tmp" -o -name "*~" -o -name "*.swp" \) 2>/dev/null)

if [ ${#unwanted_files[@]} -gt 0 ]; then
    record_fail "Unwanted files/directories found: ${unwanted_files[*]}"
else
    record_ok "No temporary files"
fi

# -----------------------------------------------------------------------------
# H. Unit Tests Execution
# -----------------------------------------------------------------------------
test_out_file="$(mktemp)"
test_rc=0
python3 -B -m unittest discover -s "$REPO_ROOT/tests" -p "test_*.py" >"$test_out_file" 2>&1 || test_rc=$?

test_summary="$(tail -n 3 "$test_out_file" | tr '\n' ' ')"

if [ "$test_rc" -eq 0 ]; then
    # Extract test count if possible
    if [[ "$test_summary" =~ Ran\ ([0-9]+)\ test ]]; then
        record_ok "Unit tests (${BASH_REMATCH[1]} tests passed)"
    else
        record_ok "Unit tests (all passed)"
    fi
else
    record_fail "Unit tests failed: $test_summary"
    echo "--- Full unittest output (for CI diagnosis) ---" >&2
    cat "$test_out_file" >&2
fi
rm -f "$test_out_file"

qmltestrunner_bin=""
for cand in /usr/lib/qt6/bin/qmltestrunner "$(command -v qmltestrunner 2>/dev/null || true)"; do
    [ -n "$cand" ] && [ -x "$cand" ] && { qmltestrunner_bin="$cand"; break; }
done

if [ -z "$qmltestrunner_bin" ]; then
    if [[ "${CI:-}" == "true" ]]; then
        record_fail "qmltestrunner is required in CI"
    else
        record_warn "qmltestrunner not found (skipping QML behavior tests)"
    fi
else
    qml_test_out="$(mktemp)"
    if QT_QPA_PLATFORM=offscreen "$qmltestrunner_bin" -input "$REPO_ROOT/tests/qml" -o "$qml_test_out",txt; then
        qml_test_summary="$(tail -n 2 "$qml_test_out" | tr '\n' ' ')"
        record_ok "QML behavior tests ($qml_test_summary)"
    else
        qml_test_summary="$(tail -n 8 "$qml_test_out" | tr '\n' ' ')"
        record_fail "QML behavior tests failed: $qml_test_summary"
    fi
    rm -f "$qml_test_out"
fi

# -----------------------------------------------------------------------------
# I. Compositor Agnosticism & Leakage Check
# -----------------------------------------------------------------------------
agnostic_ok=true

# Check for hyprctl leakage in QML
hyprctl_qml_leaks="$(grep -Rnl "hyprctl" --include="*.qml" "$REPO_ROOT" 2>/dev/null || true)"
if [ -n "$hyprctl_qml_leaks" ]; then
    record_fail "Compositor leakage: direct hyprctl calls found in QML files (use scripts/compositor-dispatch.sh):\n$hyprctl_qml_leaks"
    agnostic_ok=false
fi

# Check for Lua dispatcher syntax in QML
lua_qml_leaks="$(grep -Rnl "hl\.dsp" --include="*.qml" "$REPO_ROOT" 2>/dev/null || true)"
if [ -n "$lua_qml_leaks" ]; then
    record_fail "Compositor leakage: Lua dispatcher syntax (hl.dsp) found in QML files:\n$lua_qml_leaks"
    agnostic_ok=false
fi

# Check compositor-dispatch.sh existence and executable bit
if [ ! -x "$REPO_ROOT/scripts/compositor-dispatch.sh" ]; then
    record_fail "Missing or non-executable scripts/compositor-dispatch.sh"
    agnostic_ok=false
fi

if [ "$agnostic_ok" = true ]; then
    record_ok "Compositor agnosticism (no hyprctl/Lua leakage in UI QML)"
fi

# -----------------------------------------------------------------------------
# H. Spotlight Open-Latency Budget (150ms, explicit opt-in)
# -----------------------------------------------------------------------------
# Measures app-side open latency via the Spotlight probe (openRequestedAt ->
# onVisibleChanged). Needs a live quickshell session; skipped otherwise.
if [ "$SPOTLIGHT_LATENCY" = true ]; then
    if command -v quickshell >/dev/null 2>&1 \
        && quickshell ipc call spotlight toggle >/dev/null 2>&1; then
        sleep 2
        quickshell ipc call spotlight toggle >/dev/null 2>&1 || true
        sleep 1
        latest_log="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/quickshell/by-id/*/log.qslog 2>/dev/null | head -n1)"
        latency_ms="$(grep -a -o -E 'Spotlight open latency: [0-9]+ms' "$latest_log" 2>/dev/null | tail -n1 | grep -a -o -E '[0-9]+' || true)"
        if [ -z "$latency_ms" ]; then
            record_warn "Spotlight latency probe produced no reading (session busy?)"
        elif [ "$latency_ms" -gt 150 ]; then
            record_warn "Spotlight open latency ${latency_ms}ms exceeds 150ms budget"
        else
            record_ok "Spotlight open latency ${latency_ms}ms (budget 150ms)"
        fi
    else
        record_warn "Spotlight latency probe requested but no live quickshell IPC is available"
    fi
else
    record_ok "Spotlight IPC left untouched (use --spotlight-latency to measure)"
fi

# -----------------------------------------------------------------------------
# Final Summary
# -----------------------------------------------------------------------------
echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "Validation passed: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
    exit 0
else
    echo "Validation failed: $OK_COUNT OK, $WARN_COUNT WARN, $FAIL_COUNT FAIL"
    exit 1
fi
