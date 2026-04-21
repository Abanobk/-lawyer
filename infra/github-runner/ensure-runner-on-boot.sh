#!/usr/bin/env bash
# بعد إعادة تشغيل السيرفر: تأكد أن وحدات systemd الخاصة بـ GitHub Actions runner
# مفعّلة وتعمل، وإلا تبقى الوظائف عالقة على «Waiting for a runner».
#
# شغّل مرة واحدة بعد كل ترقية للنظام، أو ضعها في cron @reboot إن لزم:
#   sudo bash infra/github-runner/ensure-runner-on-boot.sh
#
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "شغّل كـ root: sudo bash $0"
  exit 1
fi

# (مهم للـ deploy workflow) تأكد أن githubrunner يقدر يعمل sudo بدون كلمة مرور
# على سكربت النشر فقط. على TrueNAS، أحيانًا ملفات sudoers.d أو /root/bin
# تتعرض للتغيير/الضياع بعد restart/upgrade.
#
# يمكنك ضبط LAWYER_REPO_PATH لو الريبو على مسار ثابت مختلف.
DEFAULT_REPO_PATH="/mnt/marichia/files/app-data/lawyer/repo"
REPO_PATH="${LAWYER_REPO_PATH:-$DEFAULT_REPO_PATH}"
ALLOW_SUDO_SCRIPT="${REPO_PATH}/infra/github-runner/allow-sudo-deploy.sh"
if [[ -f "$ALLOW_SUDO_SCRIPT" ]]; then
  echo "→ ensure deploy sudoers (allow-sudo-deploy.sh)"
  bash "$ALLOW_SUDO_SCRIPT" || echo "تحذير: allow-sudo-deploy.sh فشل — راجع /etc/sudoers و /etc/sudoers.d"
else
  echo "→ skip deploy sudoers (not found): $ALLOW_SUDO_SCRIPT"
fi

mapfile -t units < <(systemctl list-unit-files --no-legend 2>/dev/null | awk '/^actions\.runner\./ && /\.service$/ {print $1}' || true)

if [[ ${#units[@]} -eq 0 ]]; then
  echo "لم يُعثر على خدمة actions.runner.* — ثبّت الـ runner أولاً:"
  echo "  sudo bash infra/github-runner/setup-durable-service.sh"
  exit 1
fi

for u in "${units[@]}"; do
  echo "→ enable --now $u"
  systemctl enable --now "$u" 2>/dev/null || systemctl start "$u" || true
done

echo ""
systemctl list-units 'actions.runner.*' --no-pager 2>/dev/null || true
echo ""
echo "للتحقق لاحقاً: systemctl status \"actions.runner.*\" --no-pager"
