#!/usr/bin/env bash
# يُنسَخ إلى /root/bin (أو LAWYER_DEPLOY_SCRIPT) بواسطة allow-sudo-deploy.sh — لا تعتمد على مسار الريبو للسكربت نفسه.
set -euo pipefail
cd "/mnt/marichia/files/app-data/lawyer/repo"
git fetch origin main
git checkout main
git reset --hard origin/main
cd infra
docker compose down --remove-orphans || true
docker compose up -d --build --remove-orphans
