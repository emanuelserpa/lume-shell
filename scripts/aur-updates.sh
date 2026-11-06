#!/usr/bin/env bash
# Consulta atualizações do AUR sem depender do cliente HTTP do yay,
# que trava em redes com IPv6 anunciado mas não roteável. Usa o RPC
# do AUR diretamente sobre IPv4 e compara versões com vercmp.
set -u

emit_json() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/update_status_json.py" "$@"
}

for bin in curl pacman vercmp python3; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    emit_json error "" "AUR\n\n'$bin' não encontrado" 0
    exit 0
  fi
done

foreign="$(pacman -Qm 2>/dev/null || true)"
if [[ -z "${foreign//[[:space:]]/}" ]]; then
  emit_json ok "" "AUR\n\nNenhum pacote estrangeiro." 0
  exit 0
fi

# Monta arg[]=nome&arg[]=nome... (lote único; ~dozens de pacotes típicos).
query=""
while read -r name ver; do
  [[ -z "$name" ]] && continue
  if [[ -z "$query" ]]; then
    query="arg[]=$name"
  else
    query="$query&arg[]=$name"
  fi
done <<< "$foreign"

rpc="$(curl -4 -s --connect-timeout 8 --max-time 25 \
  --get --data-urlencode "v=5" \
  "https://aur.archlinux.org/rpc/v5/info?$query" 2>/dev/null || true)"

if [[ -z "$rpc" ]]; then
  emit_json timeout "" "AUR\n\nConsulta expirou; tente novamente." 0
  exit 0
fi

updates="$(FOREIGN="$foreign" RPC="$rpc" python3 - <<'PY'
import json, os, subprocess

try:
    data = json.loads(os.environ["RPC"])
except Exception:
    print("")
    raise SystemExit

local = {}
for line in os.environ["FOREIGN"].splitlines():
    parts = line.split()
    if len(parts) >= 2:
        local[parts[0]] = " ".join(parts[1:])

out = []
for item in data.get("results") or []:
    name = item.get("Name") or item.get("name")
    remote = item.get("Version")
    if not name or not remote or name not in local:
        continue
    try:
        cmp = subprocess.run(
            ["vercmp", local[name], remote],
            capture_output=True, text=True, timeout=5,
        )
        if cmp.stdout.strip().startswith("-"):
            out.append(f"{name} {local[name]} -> {remote}")
    except Exception:
        continue
print("\n".join(out))
PY
)"

if [[ -z "${updates//[[:space:]]/}" ]]; then
  emit_json ok "" "AUR\n\nTudo atualizado!" 0
  exit 0
fi

mapfile -t items < <(printf '%s\n' "$updates" | sed '/^[[:space:]]*$/d')
count="${#items[@]}"
tooltip="Atualizações do AUR:
$(printf '%s\n' "${items[@]:0:20}")"

emit_json updates "󰣇 $count" "$tooltip" "$count" "${items[@]}"
