#!/usr/bin/env bash
# إعداد السيرفر الجديد من الصفر (شغّله على السيرفر كـ root أو بـ sudo).
#
# مثال:
#   export REPO_URL=https://github.com/Abanobk/-lawyer.git
#   export REPO_PATH=/opt/lawyer/repo
#   sudo bash scripts/bootstrap-new-server.sh
#
# بعد النجاح: اربط lawyer.easytecheg.net في Cloudflare بـ IP السيرفر
# ووجّه المنفذ 80/443 على الهوست إلى http://127.0.0.1:8091 (انظر README في الأسفل).

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Abanobk/-lawyer.git}"
REPO_PATH="${REPO_PATH:-/opt/lawyer/repo}"
BRANCH="${BRANCH:-main}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "مطلوب: $1 — ثبّته ثم أعد تشغيل السكربت."
    exit 1
  }
}

echo "==> التحقق من Docker..."
need_cmd docker
docker compose version >/dev/null 2>&1 || need_cmd "docker-compose"

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon غير شغّال. شغّل الخدمة ثم أعد المحاولة."
  exit 1
fi

echo "==> جلب الكود إلى $REPO_PATH"
mkdir -p "$(dirname "$REPO_PATH")"
if [[ -d "$REPO_PATH/.git" ]]; then
  cd "$REPO_PATH"
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  git clone --branch "$BRANCH" "$REPO_URL" "$REPO_PATH"
  cd "$REPO_PATH"
fi

ENV_FILE="$REPO_PATH/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "==> إنشاء $ENV_FILE (عدّل القيم قبل الإنتاج)"
  cat >"$ENV_FILE" <<'EOF'
APP_BASE_URL=https://lawyer.easytecheg.net
JWT_SECRET=غيّر-هذا-لسر-قوي
SUPER_ADMIN_EMAIL=admin@example.com
SUPER_ADMIN_PASSWORD=غيّر-كلمة-المرور
TRIAL_DAYS_DEFAULT=30
MOBILE_BUILD_WEBHOOK_TOKEN=
# GOOGLE_WEB_CLIENT_ID=
EOF
  echo "تم إنشاء .env — راجعه: $ENV_FILE"
else
  echo "==> موجود: $ENV_FILE"
fi

echo "==> بناء وتشغيل الحاويات (قد يستغرق عدة دقائق أول مرة)..."
cd "$REPO_PATH/infra"
docker compose down --remove-orphans || true
docker compose up -d --build --remove-orphans

echo "==> انتظار جاهزية الخدمة..."
ok=0
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:8091/health" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 3
done

if [[ "$ok" -ne 1 ]]; then
  echo "فشل health check على http://127.0.0.1:8091/health"
  echo "راجع: docker compose -f $REPO_PATH/infra/docker-compose.yml logs --tail=80"
  exit 1
fi

echo ""
echo "✓ التطبيق يعمل محلياً على المنفذ 8091"
curl -fsS "http://127.0.0.1:8091/health" && echo ""
echo ""
echo "الخطوات التالية (خارج Docker):"
echo "  1) Cloudflare → DNS: A record لـ lawyer.easytecheg.net → IP السيرفر الجديد (Proxied)"
echo "  2) على السيرفر: reverse proxy من :80 و :443 إلى http://127.0.0.1:8091"
echo "     (Cloudflare يتصل بالمنفذ 80/443 — التطبيق 8091 فقط بدون proxy = 502)"
echo "  3) SSL في Cloudflare: Full أو Full (strict) إن كان عندك شهادة على الهوست"
echo "  4) (اختياري) GitHub self-hosted runner: infra/github-runner/*.sh"
echo "  5) (اختياري) استعادة البيانات: volumes db_data و backend_uploads من السيرفر القديم"
