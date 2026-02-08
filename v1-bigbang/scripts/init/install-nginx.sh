#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/init.sh"

require_root
if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
  apt_update
fi
apt-get install -y nginx
systemctl enable --now nginx
