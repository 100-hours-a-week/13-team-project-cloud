#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../init/init.sh"

require_root

DIST_DIR="${DIST_DIR:-}"
if [[ -z "${DIST_DIR}" ]]; then
  DIST_DIR="$(find "${SCRIPT_DIR}" -maxdepth 1 -type d -name "dist-*" | head -n 1 || true)"
fi

if [[ -z "${DIST_DIR}" || ! -d "${DIST_DIR}" ]]; then
  echo "Dist directory not found. Set DIST_DIR to your build output." >&2
  exit 1
fi

DEPLOY_PATH="${DEPLOY_PATH:-/var/www/html}"
BACKUP_PATH="${BACKUP_PATH:-/var/www/html-backup}"
NGINX_USER="${NGINX_USER:-www-data}"
NGINX_GROUP="${NGINX_GROUP:-www-data}"

if [[ -d "${DEPLOY_PATH}" && -n "$(ls -A "${DEPLOY_PATH}" 2>/dev/null)" ]]; then
  mkdir -p "${BACKUP_PATH}"
  rsync -az --delete "${DEPLOY_PATH}/" "${BACKUP_PATH}/"
fi

mkdir -p "${DEPLOY_PATH}"
rsync -az --delete \
  --chown="${NGINX_USER}:${NGINX_GROUP}" \
  --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  "${DIST_DIR}/" "${DEPLOY_PATH}/"

if systemctl is-active --quiet nginx; then
  systemctl reload nginx
fi

echo "Frontend test deployed: ${DIST_DIR} -> ${DEPLOY_PATH}"
