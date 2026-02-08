#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  sudo infra/scripts/database/migrate-postgres-data-dir.sh <device> [data_dir]

Examples:
  sudo infra/scripts/database/migrate-postgres-data-dir.sh /dev/nvme1n1
  sudo infra/scripts/database/migrate-postgres-data-dir.sh /dev/nvme1n1 /var/lib/postgresql/16/main

Environment:
  AUTO_FORMAT=1   Format the device if no filesystem is detected.
  FS_TYPE=ext4    Filesystem type to use when formatting (default: ext4).
  PG_SERVICE=postgresql  Systemd service name (default: postgresql).
  TMP_MOUNT=/mnt/db      Temporary mount point (default: /mnt/db).
USAGE
}

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

DEVICE="${1:-}"
DATA_DIR="${2:-}"

if [[ -z "$DEVICE" ]]; then
  usage
  exit 1
fi

if [[ ! -b "$DEVICE" ]]; then
  echo "Device not found or not a block device: $DEVICE" >&2
  exit 1
fi

if findmnt -n -S "$DEVICE" >/dev/null 2>&1; then
  echo "Device is already mounted: $DEVICE" >&2
  exit 1
fi

if [[ -z "$DATA_DIR" ]]; then
  if command -v psql >/dev/null 2>&1; then
    DATA_DIR="$(sudo -u postgres psql -tAc "show data_directory;" 2>/dev/null | xargs || true)"
  fi
  if [[ -z "$DATA_DIR" ]]; then
    DATA_DIR="/var/lib/postgresql/16/main"
  fi
fi

if [[ ! -d "$DATA_DIR" ]]; then
  echo "PostgreSQL data directory not found: $DATA_DIR" >&2
  exit 1
fi

if findmnt -n "$DATA_DIR" >/dev/null 2>&1; then
  echo "Data directory is already a mount point: $DATA_DIR" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but not installed." >&2
  exit 1
fi

FS_TYPE="${FS_TYPE:-ext4}"
PG_SERVICE="${PG_SERVICE:-postgresql}"
TMP_MOUNT="${TMP_MOUNT:-/mnt/db}"

fs_type_detected="$(lsblk -no FSTYPE "$DEVICE" | head -n 1 || true)"
if [[ -z "$fs_type_detected" ]]; then
  if [[ "${AUTO_FORMAT:-0}" -ne 1 ]]; then
    echo "No filesystem detected on $DEVICE. Set AUTO_FORMAT=1 to format." >&2
    exit 1
  fi
  mkfs -t "$FS_TYPE" "$DEVICE"
  fs_type_detected="$FS_TYPE"
fi

systemctl stop "$PG_SERVICE"

if [[ -e "$DATA_DIR/postmaster.pid" ]]; then
  rm -f "$DATA_DIR/postmaster.pid"
fi

mkdir -p "$TMP_MOUNT"
mount "$DEVICE" "$TMP_MOUNT"

set +e
rsync -a --exclude=postmaster.pid "${DATA_DIR%/}/" "${TMP_MOUNT%/}/"
rsync_status=$?
set -e
if [[ $rsync_status -ne 0 && $rsync_status -ne 24 ]]; then
  exit $rsync_status
fi
chown -R postgres:postgres "$TMP_MOUNT"
chmod 700 "$TMP_MOUNT"

umount "$TMP_MOUNT"

backup_dir="${DATA_DIR}.bak.$(date +%Y%m%d%H%M%S)"
mv "$DATA_DIR" "$backup_dir"
mkdir -p "$DATA_DIR"

mount "$DEVICE" "$DATA_DIR"
chown -R postgres:postgres "$DATA_DIR"
chmod 700 "$DATA_DIR"

uuid="$(blkid -s UUID -o value "$DEVICE")"
if [[ -n "$uuid" ]]; then
  fstab_line="UUID=${uuid} ${DATA_DIR} ${fs_type_detected} defaults,nofail 0 2"
  if ! grep -q "UUID=${uuid}" /etc/fstab && ! grep -q " ${DATA_DIR} " /etc/fstab; then
    echo "$fstab_line" >> /etc/fstab
  fi
fi

systemctl start "$PG_SERVICE"

echo "Done."
echo "Backup directory: $backup_dir"
echo "Verify PostgreSQL, then remove the backup when safe."
