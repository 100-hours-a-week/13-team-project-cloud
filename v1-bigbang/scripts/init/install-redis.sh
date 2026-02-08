#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/init.sh"

require_root
if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
  apt_update
fi

REDIS_PKG="${REDIS_PKG:-redis-server}"
apt-get install -y "$REDIS_PKG"
systemctl enable --now redis-server

# 비밀번호 설정 (초기 세팅)
# sudoedit /etc/redis/redis.conf → requirepass <password>
# sudo systemctl restart redis-server
# redis-cli -a '<password>' ping
