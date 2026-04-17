#!/usr/bin/env bash
# يمنح مستخدم الـ runner (افتراضي: githubrunner) صلاحية الدخول لمسار الريبو وتشغيل النشر.
# يُشغَّل مرة واحدة على TrueNAS كـ root بعد تثبيت الـ runner، أو عند ظهور:
#   cd: ... Permission denied
#
#   sudo bash infra/github-runner/grant-runner-repo-access.sh
#
set -euo pipefail

RUNNER_USER="${RUNNER_USER:-githubrunner}"
REPO="${REPO:-/mnt/marichia/files/app-data/lawyer/repo}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "شغّل كـ root: sudo bash $0"
  exit 1
fi

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "خطأ: المستخدم غير موجود: $RUNNER_USER"
  exit 1
fi

if [[ ! -d "$REPO" ]]; then
  echo "خطأ: مجلد الريبو غير موجود: $REPO"
  exit 1
fi

# السماح بالمرور (execute) على كل مستوى من المسار حتى يستطيع RUNNER_USER عمل cd
_p="$REPO"
while [[ "$_p" != "/" && -n "$_p" ]]; do
  if [[ -d "$_p" ]]; then
    chmod a+rx "$_p" 2>/dev/null || chmod o+rx "$_p" 2>/dev/null || true
  fi
  _p="$(dirname "$_p")"
done

chown -R "$RUNNER_USER:$RUNNER_USER" "$REPO"

# docker compose غالبًا يحتاج عضوية مجموعة docker على السيرفر
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker "$RUNNER_USER" 2>/dev/null || true
  echo "تمت إضافة $RUNNER_USER لمجموعة docker (قد تحتاج إعادة تشغيل خدمة الـ runner)."
fi

echo "تم. جرّب من جلسة $RUNNER_USER: cd $REPO && pwd"
echo "ثم أعد تشغيل الـ runner: systemctl restart \"actions.runner.*\""
