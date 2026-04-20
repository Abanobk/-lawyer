#!/usr/bin/env bash
# بناء APK لمكتب واحد (white-label). يُستدعى من CI أو يدويًا من جذر المستودع.
# الاستخدام: build_white_label_apk.sh <office_code> <api_base_url> [app_label] <build_number>
# مثال:
#   ./infra/mobile-build/build_white_label_apk.sh myoffice https://api.example.com/api "" 42
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/app"

OFFICE_CODE="${1:?office_code required}"
API_BASE_URL="${2:?api_base_url required}"
APP_LABEL="${3:-}"
BUILD_NUM="${4:?build_number required}"

GRADLE_ARGS=( "-POFFICE_CODE=${OFFICE_CODE}" )
if [[ -n "${APP_LABEL}" ]]; then
  GRADLE_ARGS+=( "-PAPP_LABEL=${APP_LABEL}" )
fi

flutter pub get
flutter build apk --release \
  "--build-number=${BUILD_NUM}" \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="OFFICE_CODE=${OFFICE_CODE}" \
  -- "${GRADLE_ARGS[@]}"

echo "APK: ${ROOT}/app/build/app/outputs/flutter-apk/app-release.apk"
