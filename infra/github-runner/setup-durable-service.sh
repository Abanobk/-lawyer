#!/usr/bin/env bash
# تثبيت GitHub Actions self-hosted runner كخدمة systemd (تشغيل دائم بعد إعادة التشغيل).
#
# على TrueNAS: مجلد /home غالبًا معلّم noexec، لذلك ضع الحزمة تحت /var (انظر RUNNER_DIR).
#
# قبل التشغيل:
#   1) من GitHub: Repo → Settings → Actions → Runners → New self-hosted runner
#   2) نزّل الحزمة وافكها في RUNNER_DIR (أو انسخها من /home/githubrunner إن وُجدت)
#   3) كمستخدم RUNNER_USER (ليس لازم root):  ./config.sh --url ... --token ...
#
# ثم نفّذ هذا السكربت كـ root:
#   sudo bash infra/github-runner/setup-durable-service.sh
#
set -euo pipefail

RUNNER_USER="${RUNNER_USER:-githubrunner}"
RUNNER_DIR="${RUNNER_DIR:-/var/githubrunner/actions-runner}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "شغّل كـ root: sudo bash $0"
  exit 1
fi

if command -v findmnt >/dev/null 2>&1; then
  opts="$(findmnt -n -o OPTIONS -T "$RUNNER_DIR" 2>/dev/null || true)"
  if [[ "$opts" == *noexec* ]]; then
    echo "خطأ: $RUNNER_DIR على filesystem بخيار noexec. انقل الـ runner إلى مسار آخر (مثل /var/githubrunner)."
    exit 1
  fi
fi

if [[ ! -d "$RUNNER_DIR" ]]; then
  echo "خطأ: المجلد غير موجود: $RUNNER_DIR"
  exit 1
fi

if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  echo "خطأ: الـ runner غير مُهيأ. نفّذ ./config.sh من GitHub أولًا داخل $RUNNER_DIR كمستخدم $RUNNER_USER"
  exit 1
fi

if ! id "$RUNNER_USER" &>/dev/null; then
  echo "خطأ: المستخدم غير موجود: $RUNNER_USER (أنشئه وامنحه ملكية المجلد)"
  exit 1
fi

if [[ -f "$RUNNER_DIR/svc.sh" ]]; then
  chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
  cd "$RUNNER_DIR"
  # توثيق GitHub الرسمي: install ثم start، والوسيط الأول اسم المستخدم الذي يشغّل الـ runner
  ./svc.sh install "$RUNNER_USER"
  ./svc.sh start
  echo ""
  echo "تم. للتحقق: systemctl status \"actions.runner.*\" --no-pager"
  systemctl list-units 'actions.runner.*' --no-pager 2>/dev/null || true
  echo ""
  echo "بعد أي إعادة تشغيل للسيرفر يجب أن يعود الـ runner تلقائياً."
  echo "إن بقي الوضع «Waiting for a runner» في GitHub: sudo bash infra/github-runner/ensure-runner-on-boot.sh"
else
  echo "لا يوجد svc.sh في $RUNNER_DIR — حدّث حزمة actions-runner من GitHub."
  exit 1
fi
