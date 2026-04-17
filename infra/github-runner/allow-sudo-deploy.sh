#!/usr/bin/env bash
# ينسخ سكربت النشر إلى مسار قابل للكتابة (افتراضي: /root/bin — TrueNAS يجعل /usr/local أحيانًا read-only).
# يضيف sudoers لـ githubrunner (NOPASSWD على هذا الملف فقط).
# شغّل مرة واحدة على TrueNAS كـ root من داخل الريبو:
#   bash infra/github-runner/allow-sudo-deploy.sh
#
set -euo pipefail

RUNNER_USER="${RUNNER_USER:-githubrunner}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/lawyer-gh-deploy.sh"
# TrueNAS: لا تستخدم /usr/local/sbin إن كان RO — عيّن DEST يدويًا إن لزم
DEST="${LAWYER_DEPLOY_SCRIPT:-/root/bin/lawyer-gh-deploy.sh}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "شغّل كـ root"
  exit 1
fi

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "خطأ: المستخدم غير موجود: $RUNNER_USER"
  exit 1
fi

if [[ ! -f "$SRC" ]]; then
  echo "خطأ: لم يُعثر على $SRC"
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
install -m 755 -o root -g root "$SRC" "$DEST"

f="/etc/sudoers.d/gh-runner-lawyer-deploy"
{
  echo "# GitHub Actions: NOPASSWD على سكربت النشر فقط"
  echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: ${DEST}"
} >"$f"
chmod 440 "$f"

if command -v visudo &>/dev/null; then
  visudo -c -f "$f" || { rm -f "$f"; exit 1; }
  # تحقق من الدمج الكامل — إن فشل، قد يكون #includedir مفقودًا من /etc/sudoers
  visudo -c 2>/dev/null || echo "تحذير: visudo -c للنظام كامل أبلغ عن خطأ — راجع /etc/sudoers"
fi

if ! grep -qE '^[[:space:]]*#includedir[[:space:]]+/etc/sudoers[.]d|@[[:space:]]*includedir[[:space:]]+/etc/sudoers[.]d' /etc/sudoers 2>/dev/null; then
  echo ""
  echo "تحذير: لم يُعثر على #includedir /etc/sudoers.d في /etc/sudoers — قواعد $f قد لا تُحمَّل."
  echo "  أضف سطرًا (بـ visudo): #includedir /etc/sudoers.d"
  echo "  أو تجاهل sudo واستخدم: bash infra/github-runner/grant-runner-repo-access.sh ثم أعد تشغيل خدمة الـ runner"
fi

echo "تم: $DEST و $f"
echo "اختبار (يشغّل نشرًا كاملًا): su - ${RUNNER_USER} -s /bin/bash -c 'sudo -n ${DEST}'"
echo "أو فقط التحقق من القاعدة: sudo -n -l -U ${RUNNER_USER}"
