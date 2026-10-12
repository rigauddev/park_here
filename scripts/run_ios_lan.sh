#!/usr/bin/env bash
set -euo pipefail

device_id="${1:?Informe o ID do iPhone: scripts/run_ios_lan.sh DEVICE_ID}"
host_ip="${API_HOST_IP:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)}"

if [[ -z "$host_ip" ]]; then
  echo 'Nao foi possivel descobrir o IP local do Mac. Use API_HOST_IP=192.168.x.x.' >&2
  exit 1
fi

curl --fail --silent --output /dev/null "http://${host_ip}:8000/docs" || {
  echo "A API nao esta acessivel em http://${host_ip}:8000. Inicie docker compose antes." >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/parkhere_user_app"
exec flutter run -d "$device_id" --dart-define="API_URL=http://${host_ip}:8000"
