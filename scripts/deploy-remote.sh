#!/usr/bin/env bash
# نشر يدوي من جهازك إلى السيرفر (بعد ضبط المتغيرات أو تصديرها في البيئة).
#
# مثال (يفضّل DEPLOY_HOST = اسم نطاق يتحل عندك — Tailscale أو DNS — بدل 192.168.x.x لو مش على نفس LAN):
#   export DEPLOY_HOST=nas.easytecheg.net
#   export DEPLOY_USER=root
#   export DEPLOY_REPO_PATH=/mnt/marichia/files/app-data/lawyer/repo
#   ./scripts/deploy-remote.sh
#
# مفتاح SSH (اختياري): export DEPLOY_SSH_KEY=$HOME/.ssh/id_ed25519

set -euo pipefail

: "${DEPLOY_HOST:?ضبط DEPLOY_HOST}"
: "${DEPLOY_USER:?ضبط DEPLOY_USER}"
: "${DEPLOY_REPO_PATH:?ضبط DEPLOY_REPO_PATH إلى مجلد الريبو على السيرفر}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
if [[ -n "${DEPLOY_SSH_KEY:-}" ]]; then
  SSH_OPTS+=(-i "$DEPLOY_SSH_KEY")
fi

ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" bash -s <<EOF
set -e
cd "${DEPLOY_REPO_PATH}"
git fetch origin main
git checkout main
git pull origin main
cd infra
docker compose up -d --build
EOF

echo "تم النشر. اختبر الصحة من السيرفر أو عبر النفق: .../api/health"
