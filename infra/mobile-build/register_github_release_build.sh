#!/usr/bin/env bash
# بعد [build_white_label_apk.sh]: ينشئ إصدار GitHub، يرفع الـ APK، ويُسجّل الرابط في الباكند.
# متغيرات بيئة مطلوبة: GITHUB_REPOSITORY, GITHUB_RUN_ID, OFFICE_CODE,
# BACKEND_API_ROOT (مثل https://host/api), MOBILE_BUILD_WEBHOOK_TOKEN
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APK="${ROOT}/app/build/app/outputs/flutter-apk/app-release.apk"
test -f "$APK"

REPO="${GITHUB_REPOSITORY:?}"
VC="${GITHUB_RUN_ID:?}"
CODE="${OFFICE_CODE:?}"
BACKEND="${BACKEND_API_ROOT:?}"
TOKEN="${MOBILE_BUILD_WEBHOOK_TOKEN:?}"

TAG="mobile-${CODE}-${VC}"

gh release create "${TAG}" "${APK}" \
  --repo "${REPO}" \
  --title "Android ${CODE} build ${VC}" \
  --notes "White-label APK for office code ${CODE}. Automated build."

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/app-release.apk"
ROOT_JSON="${BACKEND%/}"

curl -fsS -X POST "${ROOT_JSON}/internal/office-mobile-builds" \
  -H "Content-Type: application/json" \
  -H "X-Mobile-Build-Token: ${TOKEN}" \
  -d "{\"office_code\":\"${CODE}\",\"version_code\":${VC},\"version_name\":\"1.0.${VC}\",\"download_url\":\"${DOWNLOAD_URL}\"}"

echo "Registered: ${DOWNLOAD_URL}"
