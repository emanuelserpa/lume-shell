#!/usr/bin/env bash
set -u

emit_json() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/update_status_json.py" "$@"
}

CHECKUPDATES="$(command -v checkupdates 2>/dev/null || true)"
if [[ -z "$CHECKUPDATES" && -x /usr/bin/checkupdates ]]; then
  CHECKUPDATES="/usr/bin/checkupdates"
fi

if [[ -z "$CHECKUPDATES" ]]; then
  emit_json error "⚠" "Atualizações do Arch\n\ncheckupdates não encontrado" 0
  exit 0
fi

package_list="$("$CHECKUPDATES" 2>/dev/null || true)"

if [[ -z "${package_list//[[:space:]]/}" ]]; then
  emit_json ok "" "Atualizações do Arch\n\nTudo atualizado!" 0
  exit 0
fi

mapfile -t items < <(printf '%s\n' "$package_list" | sed '/^[[:space:]]*$/d')
count="${#items[@]}"
tooltip="Atualizações do Arch:
$(printf '%s\n' "${items[@]:0:20}")"

emit_json updates " $count" "$tooltip" "$count" "${items[@]}"
