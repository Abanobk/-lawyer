#!/usr/bin/env bash
# يضيف لـ githubrunner صلاحية تشغيل bash كـ root بدون كلمة مرور (لخطوة النشر في GitHub Actions فقط).
# شغّل مرة واحدة على TrueNAS كـ root:
#   bash infra/github-runner/allow-sudo-deploy.sh
#
set -euo pipefail

RUNNER_USER="${RUNNER_USER:-githubrunner}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "شغّل كـ root"
  exit 1
fi

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "خطأ: المستخدم غير موجود: $RUNNER_USER"
  exit 1
fi

f="/etc/sudoers.d/gh-runner-lawyer-deploy"
{
  echo "# GitHub Actions self-hosted: deploy job يستخدم sudo bash -c"
  echo "${RUNNER_USER} ALL=(root) NOPASSWD: /bin/bash"
  echo "${RUNNER_USER} ALL=(root) NOPASSWD: /usr/bin/bash"
} >"$f"
chmod 440 "$f"

if command -v visudo &>/dev/null; then
  visudo -c -f "$f" || { rm -f "$f"; exit 1; }
fi

echo "تم إنشاء $f"
echo "اختبر: su - ${RUNNER_USER} -s /bin/bash -c 'sudo -n /usr/bin/bash -c \"echo ok\"'"
