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
