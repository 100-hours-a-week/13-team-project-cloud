#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/init.sh"

require_root
if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
  apt_update
fi

POSTGRES_PKG="${POSTGRES_PKG:-postgresql}"
apt-get install -y "$POSTGRES_PKG"
systemctl enable --now postgresql

# 비밀번호 설정 (초기 세팅)
# sudo -u postgres psql -c "ALTER USER postgres PASSWORD '<password>';"
# sudoedit /etc/postgresql/*/main/pg_hba.conf → md5 인증 설정
# sudo systemctl restart postgresql
