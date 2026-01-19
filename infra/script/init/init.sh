#!/usr/bin/env bash
set -euo pipefail

INIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run as root." >&2
    exit 1
  fi
}

apt_update() {
  apt-get update -y
}

install_all() {
  SKIP_APT_UPDATE=1 bash "${INIT_DIR}/install-nginx.sh"
  SKIP_APT_UPDATE=1 bash "${INIT_DIR}/install-postgresql.sh"
  SKIP_APT_UPDATE=1 bash "${INIT_DIR}/install-redis.sh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  require_root
  apt_update
  install_all
fi
