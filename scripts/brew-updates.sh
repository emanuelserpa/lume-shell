#!/usr/bin/env bash
set -u

BREW="$(command -v brew 2>/dev/null || true)"
if [[ -z "$BREW" ]]; then
  for candidate in \
    /opt/brew/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew \
    /usr/local/bin/brew \
    /opt/homebrew/bin/brew
  do
    if [[ -x "$candidate" ]]; then
      BREW="$candidate"
      break
    fi
  done
fi

emit_json() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/update_status_json.py" "$@"
}

if [[ -z "$BREW" || ! -x "$BREW" ]]; then
  emit_json error "" "Homebrew não encontrado" 0
  exit 0
fi

outdated="$(HOMEBREW_NO_COLOR=1 "$BREW" outdated 2>/dev/null || true)"

if [[ -z "${outdated//[[:space:]]/}" ]]; then
  emit_json ok "" "Tudo atualizado!" 0
  exit 0
fi

mapfile -t items < <(printf '%s\n' "$outdated" | sed '/^[[:space:]]*$/d')
count="${#items[@]}"
tooltip="Atualizações do Brew:
$(printf '%s\n' "${items[@]:0:20}")"

emit_json updates " $count" "$tooltip" "$count" "${items[@]}"
