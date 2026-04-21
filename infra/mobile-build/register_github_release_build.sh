#!/usr/bin/env bash
# بعد [build_white_label_apk.sh]: ينشئ إصدار GitHub، يرفع الـ APK، ويُسجّل الرابط في الباكند.
# متغيرات بيئة مطلوبة: GITHUB_REPOSITORY, GITHUB_RUN_ID, GITHUB_RUN_ATTEMPT, ANDROID_VERSION_CODE, OFFICE_CODE,
# BACKEND_API_ROOT (مثل https://host/api), MOBILE_BUILD_WEBHOOK_TOKEN
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APK="${ROOT}/app/build/app/outputs/flutter-apk/app-release.apk"
test -f "$APK"

REPO="${GITHUB_REPOSITORY:?}"
RUN_ID="${GITHUB_RUN_ID:?}"
ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
VC="${ANDROID_VERSION_CODE:?}"
CODE="${OFFICE_CODE:?}"
BACKEND="${BACKEND_API_ROOT:?}"
TOKEN="${MOBILE_BUILD_WEBHOOK_TOKEN:?}"

TAG="mobile-${CODE}-${RUN_ID}-${ATTEMPT}"

if gh release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
  gh release upload "${TAG}" "${APK}" --repo "${REPO}" --clobber
else
  gh release create "${TAG}" "${APK}" \
    --repo "${REPO}" \
    --title "Android ${CODE} build ${VC} (run ${RUN_ID}.${ATTEMPT})" \
    --notes "White-label APK for office code ${CODE}. Automated build."
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/app-release.apk"
ROOT_JSON="${BACKEND%/}"

export DOWNLOAD_URL
export ANDROID_VERSION_CODE="${VC}"

payload="$(mktemp)"
python3 - <<PY >"$payload"
import json
import os

payload = {
  "office_code": os.environ["OFFICE_CODE"],
  "version_code": int(os.environ["ANDROID_VERSION_CODE"]),
  "version_name": f"1.0.{os.environ['ANDROID_VERSION_CODE']}",
  "download_url": os.environ["DOWNLOAD_URL"],
}
print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
PY
echo "Register payload (${#CODE} code chars, ${#DOWNLOAD_URL} url chars, VC=${VC}):"
bytes="$(wc -c <"$payload" | tr -d ' ')"
echo "payload_bytes=${bytes}"
if [[ "${bytes}" -lt 2 ]]; then
  echo "Payload file is empty; aborting."
  exit 23
fi

# Expose payload path for URL-encoding step.
export PAYLOAD_PATH="$payload"

# Validate JSON locally before sending (helps catch hidden chars / truncation).
python3 - "$payload" <<'PY'
import json, sys
with open(sys.argv[1], "rb") as f:
    raw = f.read()
json.loads(raw.decode("utf-8"))
print("payload_json_ok=1")
PY

resp="$(mktemp)"
json_body="$(cat "$payload")"
qs="$(python3 - <<'PY'
import json, os, urllib.parse
payload = json.loads(open(os.environ["PAYLOAD_PATH"], "r", encoding="utf-8").read())
print(urllib.parse.urlencode(payload))
PY
)"

trace="$(mktemp)"
http="$(curl -sS \
  --http1.1 \
  -v \
  -o "$resp" \
  -w "%{http_code}" \
  -X POST "${ROOT_JSON}/internal/office-mobile-builds?${qs}" \
  -H "X-Mobile-Build-Token: ${TOKEN}" \
  2>"$trace" || true)"

if [[ "$http" != "200" && "$http" != "201" ]]; then
  echo "Backend register failed. HTTP=$http"
  echo "Curl trace (first 120 lines):"
  sed -n '1,120p' "$trace" || true
  echo ""
  echo "Response:"
  cat "$resp" || true
  echo ""
  echo "Payload (first 300 chars):"
  head -c 300 "$payload" || true
  echo ""
  exit 22
fi

echo "Registered: ${DOWNLOAD_URL}"
