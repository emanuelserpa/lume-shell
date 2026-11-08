#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QS_BIN="$(command -v quickshell || true)"
if [[ -z "$QS_BIN" ]]; then
    echo "quickshell is required for the Process integration test" >&2
    exit 2
fi

test_dir="$(mktemp -d "${TMPDIR:-/tmp}/lume-process-integration.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

ln -s "$REPO_ROOT/qmldir" "$test_dir/qmldir"
ln -s "$REPO_ROOT/components" "$test_dir/components"
ln -s "$REPO_ROOT/services" "$test_dir/services"
cp "$REPO_ROOT/tests/quickshell-processes/shell.qml" "$test_dir/shell.qml"
ln -s "$REPO_ROOT/tests/quickshell-processes/fixtures" "$test_dir/fixtures"

log_file="$test_dir/output.log"
if ! timeout 12s "$QS_BIN" --path "$test_dir" >"$log_file" 2>&1; then
    cat "$log_file" >&2
    exit 1
fi

if [[ ! -f "$test_dir/pending-started" ]]; then
    cat "$log_file" >&2
    echo "pending helper did not start" >&2
    exit 1
fi

if ! rg -q 'QUICKSHELL_PROCESS_INTEGRATION_PASS' "$log_file"; then
    cat "$log_file" >&2
    echo "Process integration marker missing" >&2
    exit 1
fi

echo "Quickshell Process integration passed (success, nonzero exit, empty output, pending restart)."
