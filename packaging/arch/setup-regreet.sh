#!/usr/bin/env bash
set -euo pipefail

share_dir=/var/lib/lume-greeter
config_dir=/etc/greetd
backup_suffix=.before-lume-shell

usage() {
  cat <<'EOF'
Uso: lume-shell greeter install [--restart]

Instala a integração opcional do ReGreet. --restart reinicia o greetd agora e
encerra a sessão gráfica atual; sem essa opção, a configuração vale no próximo
início do greetd.
EOF
}

restart_now=false
case "${1:-install}" in
  -h|--help|help)
    usage
    exit 0
    ;;
  install)
    shift || true
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

while (($#)); do
  case "$1" in
    --restart) restart_now=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Opção desconhecida: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if ((EUID != 0)); then
  if ! command -v sudo >/dev/null 2>&1; then
    echo 'Este comando precisa de privilégios administrativos (instale sudo ou execute como root).' >&2
    exit 1
  fi
  if [[ "$restart_now" == true ]]; then
    exec sudo -- /usr/lib/lume-shell/setup-regreet.sh install --restart
  fi
  exec sudo -- /usr/lib/lume-shell/setup-regreet.sh install
fi

target_user=${SUDO_USER:-}
if [[ -z "$target_user" || "$target_user" == root ]]; then
  echo 'Execute como usuário da sessão: lume-shell greeter install (o comando pedirá sudo).' >&2
  exit 1
fi
if ! getent passwd "$target_user" >/dev/null; then
  printf 'Usuário não encontrado: %s\n' "$target_user" >&2
  exit 1
fi
if ! getent passwd greeter >/dev/null || ! getent group greeter >/dev/null; then
  echo 'O usuário/grupo greeter não existe. Instale greetd-regreet primeiro.' >&2
  exit 1
fi
for bin in regreet cage dbus-run-session runuser; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf 'Dependência ausente: %s (instale greetd-regreet e cage).\n' "$bin" >&2
    exit 1
  fi
done

repo_dir=/usr/share/lume-shell
if [[ ! -r "$repo_dir/greetd/config.toml" || ! -r "$repo_dir/scripts/theme-manager.py" ]]; then
  echo 'Arquivos do Lume ausentes; reinstale o pacote lume-shell.' >&2
  exit 1
fi
target_home=$(getent passwd "$target_user" | cut -d: -f6)
if [[ -z "$target_home" || ! -d "$target_home" ]]; then
  printf 'Home do usuário não encontrado: %s\n' "$target_user" >&2
  exit 1
fi

install -d -o "$target_user" -g greeter -m 2750 "$share_dir"
runuser -u "$target_user" -- env HOME="$target_home" \
  XDG_STATE_HOME="$target_home/.local/state" \
  python3 -B "$repo_dir/scripts/theme-manager.py" sync-regreet

if [[ ! -s "$share_dir/background.jpg" || ! -s "$share_dir/regreet.css" ]]; then
  echo 'Não foi possível gerar o wallpaper e o tema do ReGreet; configuração não alterada.' >&2
  exit 1
fi
runuser -u greeter -- test -r "$share_dir/background.jpg"
runuser -u greeter -- test -r "$share_dir/regreet.css"

install -d -m 0755 "$config_dir"
for name in config.toml regreet.toml; do
  current="$config_dir/$name"
  source="$repo_dir/greetd/$name"
  backup="$current$backup_suffix"
  if [[ -e "$current" && ! -e "$backup" ]]; then
    cp -a "$current" "$backup"
  fi
  install -o root -g root -m 0644 "$source" "$current"
done

if [[ "$restart_now" == true ]]; then
  systemctl restart greetd
else
  cat <<'EOF'
Integração instalada. A configuração será usada quando o greetd iniciar.
Para ativar agora, salve seu trabalho e execute: sudo systemctl restart greetd
Isso encerrará a sessão gráfica atual.
EOF
fi
