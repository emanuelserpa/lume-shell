#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export QML2_IMPORT_PATH="${repo_root}${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"
export QS_DISABLE_FILE_WATCHER=1

exec quickshell --path "${repo_root}/lockscreen.qml"
