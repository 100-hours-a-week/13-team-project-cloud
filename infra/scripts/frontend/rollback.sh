#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${1:-/var/www/html}"
BACKUP_PATH="${2:-/var/www/html-backup}"
NGINX_USER="${NGINX_USER:-www-data}"
NGINX_GROUP="${NGINX_GROUP:-www-data}"

if [ ! -d "$BACKUP_PATH" ]; then
  echo "Backup path not found: $BACKUP_PATH" >&2
  exit 1
fi

if [ -z "$(ls -A "$BACKUP_PATH")" ]; then
  echo "Backup path is empty: $BACKUP_PATH" >&2
  exit 1
fi

sudo mkdir -p "$DEPLOY_PATH"
sudo rsync -az --delete "$BACKUP_PATH"/ "$DEPLOY_PATH"/

sudo chown -R "${NGINX_USER}:${NGINX_GROUP}" "$DEPLOY_PATH"
sudo find "$DEPLOY_PATH" -type d -exec chmod 755 {} +
sudo find "$DEPLOY_PATH" -type f -exec chmod 644 {} +

echo "Rollback complete: $BACKUP_PATH -> $DEPLOY_PATH"
