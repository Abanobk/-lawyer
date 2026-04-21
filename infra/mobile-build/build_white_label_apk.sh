#!/usr/bin/env bash
# بناء APK لمكتب واحد (white-label). يُستدعى من CI أو يدويًا من جذر المستودع.
# الاستخدام: build_white_label_apk.sh [office_code] [api_base_url] [app_label] [build_number]
# بدون معاملات: يستخدم القيم الافتراضية أدناه (مكتب النمث على lawyer.easytecheg.net).
# تجاوز الافتراضي: مرّر المعاملات أو اضبط LAWYER_OFFICE_CODE / LAWYER_API_BASE_URL / LAWYER_BUILD_NUMBER.
# مثال:
#   ./infra/mobile-build/build_white_label_apk.sh
#   ./infra/mobile-build/build_white_label_apk.sh myoffice https://api.example.com/api "" 42
set -euo pipefail

# افتراضيات البناء المحلي — نفس المسار كما في الويب: /o/7ta4cz9ld7/...
: "${LAWYER_OFFICE_CODE:=7ta4cz9ld7}"
: "${LAWYER_API_BASE_URL:=https://lawyer.easytecheg.net/api}"
: "${LAWYER_BUILD_NUMBER:=1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/app"

OFFICE_CODE="${1:-$LAWYER_OFFICE_CODE}"
API_BASE_URL="${2:-$LAWYER_API_BASE_URL}"
APP_LABEL="${3:-}"
BUILD_NUM="${4:-$LAWYER_BUILD_NUMBER}"

# Pass gradle project properties via environment variables.
# Gradle automatically maps ORG_GRADLE_PROJECT_<key> to project properties, which
# avoids flutter CLI argument parsing issues and handles spaces safely.
export ORG_GRADLE_PROJECT_OFFICE_CODE="${OFFICE_CODE}"
if [[ -n "${APP_LABEL}" ]]; then
  export ORG_GRADLE_PROJECT_APP_LABEL="${APP_LABEL}"
fi

flutter pub get

# مع set -u، توسيع مصفوفة فارغة كـ "${arr[@]}" يفشل على bash القديم (مثل macOS).
flutter_args=(
  build apk --release
  "--build-number=${BUILD_NUM}"
  --dart-define="API_BASE_URL=${API_BASE_URL}"
  --dart-define="OFFICE_CODE=${OFFICE_CODE}"
)
if [[ -n "${GOOGLE_WEB_CLIENT_ID:-}" ]]; then
  flutter_args+=(--dart-define="GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}")
fi
flutter "${flutter_args[@]}"

echo "APK: ${ROOT}/app/build/app/outputs/flutter-apk/app-release.apk"
