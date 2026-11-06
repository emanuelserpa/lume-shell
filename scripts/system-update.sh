#!/usr/bin/env bash
# Runs update backends without a terminal and streams JSON progress to Quickshell.
set -u

MODE="${1:-all}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/quickshell"
mkdir -p -- "$LOG_DIR" || true
LOG_FILE="$LOG_DIR/update.log"
: > "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/quickshell-update-${UID:-unknown}.log"

FAILED=()
STEP=0
TOTAL=1

emit_stage() {
  STEP=$((STEP + 1))
  printf '{"type":"stage","step":%d,"total":%d,"text":"%s"}\n' "$STEP" "$TOTAL" "$1"
  printf 'Etapa %d/%d: %s\n' "$STEP" "$TOTAL" "$1" >>"$LOG_FILE"
}

run_stage() {
  local label="$1"
  shift
  emit_stage "$label"
  if "$@" >>"$LOG_FILE" 2>&1; then
    printf '%s: concluído\n' "$label" >>"$LOG_FILE"
  else
    local rc=$?
    FAILED+=("$label")
    printf '%s: falhou (código %d)\n' "$label" "$rc" >>"$LOG_FILE"
  fi
}

run_flatpak_stage() {
  emit_stage "Flatpak"
  set -o pipefail
  flatpak update -y 2>&1 \
    | tr '\r' '\n' \
    | while IFS= read -r line; do
        printf '%s\n' "$line" >>"$LOG_FILE"
        if [[ "$line" =~ (Updating|Atualizando)[[:space:]]+([0-9]+)/([0-9]+).*[^0-9]([0-9]{1,3})% ]]; then
          printf '{"type":"progress","percent":%d,"item":%d,"items":%d}\n' \
            "${BASH_REMATCH[4]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
          printf 'Flatpak: %s/%s · %s%%\n' \
            "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" >>"$LOG_FILE"
        fi
      done
  local rc=${PIPESTATUS[0]}
  set +o pipefail
  if (( rc != 0 )); then
    FAILED+=("Flatpak")
    printf 'Flatpak: falhou (código %d)\n' "$rc" >>"$LOG_FILE"
  else
    printf 'Flatpak: concluído\n' >>"$LOG_FILE"
  fi
}

run_repo() {
  if ! command -v pkexec >/dev/null 2>&1; then
    FAILED+=("Repositórios (pkexec ausente)")
    emit_stage "Polkit não encontrado para atualizar os repositórios"
    return
  fi
  run_stage "Repositórios oficiais" pkexec /usr/bin/pacman -Syu --noconfirm
}

run_aur() {
  if ! command -v yay >/dev/null 2>&1; then
    FAILED+=("AUR (yay ausente)")
    emit_stage "yay não encontrado; etapa AUR ignorada"
    return
  fi
  run_stage "Pacotes AUR" yay -Syu --aur --noconfirm \
    --answerdiff None --answeredit None --answerclean None \
    --sudo "$SCRIPT_DIR/yay-pkexec.sh"
}

run_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    emit_stage "Flatpak não instalado; etapa ignorada"
    return
  fi
  run_flatpak_stage
  if [[ ${#FAILED[@]} -eq 0 || "${FAILED[-1]}" != "Flatpak" ]]; then
    flatpak uninstall --unused -y >>"$LOG_FILE" 2>&1 || true
  fi
}

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return
  fi
  for candidate in \
    /opt/brew/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew \
    /usr/local/bin/brew \
    /opt/homebrew/bin/brew
  do
    [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
  done
}

run_brew() {
  local brew_bin
  brew_bin="$(find_brew || true)"
  if [[ -z "$brew_bin" ]]; then
    emit_stage "Homebrew não instalado; etapa ignorada"
    return
  fi
  run_stage "Homebrew" run_brew_updates "$brew_bin"
}

run_brew_updates() {
  local brew_bin="$1"
  "$brew_bin" update && "$brew_bin" upgrade || return $?
  "$brew_bin" cleanup || true
}

run_appimage() {
  if ! command -v flatpak >/dev/null 2>&1 \
      || ! flatpak info it.mijorus.gearlever >>"$LOG_FILE" 2>&1; then
    emit_stage "Gear Lever não instalado; etapa AppImage ignorada"
    return
  fi
  run_stage "AppImages (Gear Lever)" flatpak run it.mijorus.gearlever --update --all --yes
}

case "$MODE" in
  repo|aur|flatpak|brew|appimage) TOTAL=1 ;;
  all) TOTAL=5 ;;
  *) printf '{"type":"done","ok":false,"text":"Modo de atualização inválido."}\n'; exit 2 ;;
esac

case "$MODE" in
  repo) run_repo ;;
  aur) run_aur ;;
  flatpak) run_flatpak ;;
  brew) run_brew ;;
  appimage) run_appimage ;;
  all)
    run_repo
    run_aur
    run_flatpak
    run_brew
    run_appimage
    ;;
esac

if (( ${#FAILED[@]} == 0 )); then
  summary="Atualização concluída."
  ok=true
else
  summary="Concluída com ${#FAILED[@]} falha(s): ${FAILED[*]}"
  ok=false
fi
printf '{"type":"done","ok":%s,"text":"%s"}\n' "$ok" "$summary"
printf '%s\n' "$summary" >>"$LOG_FILE"
