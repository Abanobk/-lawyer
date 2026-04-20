#!/usr/bin/env bash
# يُنسَخ إلى /root/bin (أو LAWYER_DEPLOY_SCRIPT) بواسطة allow-sudo-deploy.sh — لا تعتمد على مسار الريبو للسكربت نفسه.
set -euo pipefail

# في GitHub Actions، الكود بيكون موجود بالفعل في GITHUB_WORKSPACE (actions/checkout).
# على TrueNAS محلياً، قد نعتمد على مسار ثابت تحت /mnt — لكن بعد restart ممكن الـ mount يتأخر/يتغير.
DEFAULT_REPO_PATH="/mnt/marichia/files/app-data/lawyer/repo"
REPO_PATH="${LAWYER_REPO_PATH:-$DEFAULT_REPO_PATH}"

if [[ -n "${GITHUB_WORKSPACE:-}" && -d "${GITHUB_WORKSPACE}/.git" ]]; then
  REPO_PATH="$GITHUB_WORKSPACE"
fi

if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "خطأ: المجلد ليس Git repo: $REPO_PATH"
  echo "جرّب ضبط LAWYER_REPO_PATH لمسار الريبو الصحيح على السيرفر، أو تأكد أن /mnt متاح."
  exit 1
fi

cd "$REPO_PATH"
git fetch origin main
git checkout main
git reset --hard origin/main
cd infra
docker compose down --remove-orphans || true
docker compose up -d --build --remove-orphans
