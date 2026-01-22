#!/usr/bin/env bash
set -euo pipefail

DEPLOY_PATH="${1:-/var/www/html}"
BACKUP_PATH="${2:-/var/www/html-backup}"

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

echo "Rollback complete: $BACKUP_PATH -> $DEPLOY_PATH"
