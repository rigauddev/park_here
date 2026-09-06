#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device_id="${1:?Informe o ID do aparelho: scripts/run_android_usb.sh DEVICE_ID}"
android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
adb_bin="$android_sdk/platform-tools/adb"
if command -v adb >/dev/null 2>&1; then
  adb_bin="$(command -v adb)"
fi
if [[ ! -x "$adb_bin" ]]; then
  echo 'ADB não encontrado. Configure ANDROID_HOME com o caminho do Android SDK.' >&2
  exit 1
fi

curl --fail --silent --output /dev/null http://127.0.0.1:8000/docs || {
  echo 'Inicie a API na porta 8000 antes de executar o app.' >&2
  exit 1
}
"$adb_bin" -s "$device_id" reverse tcp:8000 tcp:8000
cd "$repo_root/parkhere_user_app"
exec flutter run -d "$device_id" --dart-define=API_URL=http://127.0.0.1:8000
