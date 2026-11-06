#!/usr/bin/env bash
set -u

emit_json() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/update_status_json.py" "$@"
}

FLATPAK="$(command -v flatpak 2>/dev/null || true)"
if [[ -z "$FLATPAK" && -x /usr/bin/flatpak ]]; then
  FLATPAK="/usr/bin/flatpak"
fi

if [[ -z "$FLATPAK" ]]; then
  emit_json error "⚠" "Atualizações do Flatpak\n\nFlatpak não encontrado" 0
  exit 0
fi

package_list="$("$FLATPAK" remote-ls --updates --columns=name 2>/dev/null || true)"

if [[ -z "${package_list//[[:space:]]/}" ]]; then
  emit_json ok "" "Atualizações do Flatpak\n\nTudo atualizado!" 0
  exit 0
fi

mapfile -t items < <(printf '%s\n' "$package_list" | sed '/^[[:space:]]*$/d')
count="${#items[@]}"
tooltip="Atualizações do Flatpak:
$(printf '%s\n' "${items[@]:0:20}")"

emit_json updates " $count" "$tooltip" "$count" "${items[@]}"
