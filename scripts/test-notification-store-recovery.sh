#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS_BIN="$(command -v quickshell || true)"
DBUS_RUN_SESSION="$(command -v dbus-run-session || true)"
if [[ -z "$QS_BIN" || -z "$DBUS_RUN_SESSION" ]]; then
    echo "quickshell and dbus-run-session are required" >&2
    exit 2
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/lume-notification-store.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

printf 'module qs\n' >"$test_dir/qmldir"
mkdir "$test_dir/services"
printf 'module qs.services\nsingleton NotificationState 1.0 NotificationState.qml\n' \
    >"$test_dir/services/qmldir"
ln -s "$REPO_ROOT/services/NotificationState.qml" \
    "$test_dir/services/NotificationState.qml"
ln -s "$REPO_ROOT/services/NotificationContent.js" \
    "$test_dir/services/NotificationContent.js"
ln -s "$REPO_ROOT/services/NotificationStoreQueue.js" \
    "$test_dir/services/NotificationStoreQueue.js"
cp "$REPO_ROOT/tests/quickshell-notification-store/shell.qml" "$test_dir/shell.qml"
mkdir "$test_dir/scripts" "$test_dir/fixtures" "$test_dir/no-python"
cp "$REPO_ROOT/tests/quickshell-notification-store/fixtures/failing-store.py" \
    "$test_dir/scripts/notification_store.py"
ln -s "$REPO_ROOT/tests/quickshell-notification-store/fixtures" \
    "$test_dir/fixtures"

run_case() {
    local mode="$1"
    local log_file="$test_dir/$mode.log"
    local starts_file="$test_dir/$mode.starts"
    local child_path="${PATH:-/usr/bin:/bin}"

    if [[ "$mode" == "missing-python" || "$mode" == "overflow" ]]; then
        child_path="$test_dir/no-python"
    fi

    timeout 10s "$DBUS_RUN_SESSION" -- /usr/bin/env \
        PATH="$child_path" \
        QT_QPA_PLATFORM=offscreen \
        LUME_STORE_TEST_MODE="$mode" \
        LUME_STORE_STARTS_FILE="$starts_file" \
        "$QS_BIN" --path "$test_dir" >"$log_file" 2>&1 &
    local run_pid=$!
    local max_rss=0
    while kill -0 "$run_pid" 2>/dev/null; do
        local rss
        rss="$(ps -eo rss=,args= | awk -v config="$test_dir" \
            'index($0, config) && $0 ~ /quickshell --path/ { print $1; exit }')"
        if [[ "$rss" =~ ^[0-9]+$ ]] && ((rss > max_rss)); then
            max_rss="$rss"
        fi
        sleep 0.1
    done
    if ! wait "$run_pid"; then
        cat "$log_file" >&2
        return 1
    fi
    printf 'MAX_RSS_KB=%s\n' "$max_rss" >>"$log_file"

    if ! rg -q 'NOTIFICATION_STORE_SIMULATION_RESULT' "$log_file"; then
        cat "$log_file" >&2
        echo "$mode simulation did not finish" >&2
        return 1
    fi

    local starts=0 errors=0 rss="unknown"
    [[ -f "$starts_file" ]] && starts="$(wc -l <"$starts_file")"
    errors="$(rg -c 'notification_store:' "$log_file" || true)"
    rss="$(sed -n 's/^MAX_RSS_KB=//p' "$log_file" | tail -1)"
    echo "$mode: helper_starts=$starts helper_errors=$errors $rss"
    cat "$log_file" | rg 'NOTIFICATION_STORE_SIMULATION_RESULT'

    if [[ "$mode" == "failing-helper" && ( "$starts" -lt 2 || "$starts" -gt 3 ) ]]; then
        echo "expected bounded exponential retries, observed $starts starts in 4 seconds" >&2
        return 1
    fi
    if [[ "$mode" == "missing-python" ]] \
        && ! rg -q '"pending":3[5-9]|"pending":[4-9][0-9]' "$log_file"; then
        echo "expected pending queue growth during repeated start failures" >&2
        return 1
    fi
    if [[ "$mode" == "missing-python" ]] \
        && ! rg -q '"failures":[1-9]' "$log_file"; then
        echo "failed process starts were not reported" >&2
        return 1
    fi
    if [[ "$mode" == "missing-python" ]] \
        && ! rg -q '"warning":"Histórico indisponível' "$log_file"; then
        echo "store unavailability was not surfaced to the UI state" >&2
        return 1
    fi
    if [[ "$mode" == "overflow" ]] \
        && ! rg -q '"pending":500,"started":false,"failures":[1-9],"warning":"Histórico incompleto: [1-9]' "$log_file"; then
        echo "queue limit and dropped-request warning were not enforced" >&2
        return 1
    fi
}

run_case failing-helper
run_case missing-python
run_case overflow
