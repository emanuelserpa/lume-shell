#!/usr/bin/env bash
# Consulta atualizações do AUR sem depender do cliente HTTP do yay,
# que pode travar em redes com IPv6 anunciado mas não roteável.
# Usa o RPC oficial sobre IPv4 e compara versões com vercmp.
set -u

emit_json() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/update_status_json.py" "$@"
}

for bin in curl pacman vercmp python3; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    emit_json error "" $'AUR\n\n'"'$bin' não encontrado" 0
    exit 0
  fi
done

foreign="$(pacman -Qm 2>/dev/null || true)"
if [[ -z "${foreign//[[:space:]]/}" ]]; then
  emit_json ok "" $'AUR\n\nNenhum pacote estrangeiro.' 0
  exit 0
fi

updates="$(FOREIGN="$foreign" python3 - <<'PY'
import json, os, subprocess
import sys
import urllib.parse

local = {}
for line in os.environ["FOREIGN"].splitlines():
    parts = line.split()
    if len(parts) >= 2:
        local[parts[0]] = " ".join(parts[1:])

names = list(local)
out = []
for offset in range(0, len(names), 100):
    batch = names[offset:offset + 100]
    query = urllib.parse.urlencode([("v", "5"), *[("arg[]", n) for n in batch]])
    try:
        response = subprocess.run(
            ["curl", "-4", "--fail", "--silent", "--show-error",
             "--connect-timeout", "8", "--max-time", "25",
             "--user-agent", "LumeShell AUR update checker",
             f"https://aur.archlinux.org/rpc/v5/info?{query}"],
            check=True, capture_output=True, text=True, timeout=30,
        )
        data = json.loads(response.stdout)
        if data.get("type") != "multiinfo" or not isinstance(data.get("results"), list):
            raise ValueError("unexpected AUR RPC response")
    except Exception as exc:
        print(f"AUR RPC error: {exc}", file=sys.stderr)
        raise SystemExit(2)
    for item in data["results"]:
        name = item.get("Name")
        remote = item.get("Version")
        if not name or not remote or name not in local:
            continue
        cmp = subprocess.run(
            ["vercmp", local[name], remote],
            capture_output=True, text=True, timeout=5,
        )
        if cmp.returncode == 0 and cmp.stdout.strip().startswith("-"):
            out.append(f"{name} {local[name]} -> {remote}")
print("\n".join(out))
PY
)"

rpc_status=$?
if (( rpc_status != 0 )); then
  emit_json timeout "" $'AUR\n\nFalha ao consultar o AUR; tente novamente.' 0
  exit 0
fi

if [[ -z "${updates//[[:space:]]/}" ]]; then
  emit_json ok "" $'AUR\n\nTudo atualizado!' 0
  exit 0
fi

mapfile -t items < <(printf '%s\n' "$updates" | sed '/^[[:space:]]*$/d')
count="${#items[@]}"
tooltip="Atualizações do AUR:
$(printf '%s\n' "${items[@]:0:20}")"

emit_json updates "󰣇 $count" "$tooltip" "$count" "${items[@]}"
