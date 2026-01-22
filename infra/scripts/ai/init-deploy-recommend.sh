#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[recommend-install]"

log() {
  echo "${LOG_PREFIX} $*"
}

fail() {
  echo "${LOG_PREFIX} ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_DIR="$(cd "${SCRIPT_DIR}/../init" && pwd)"
# shellcheck source=/dev/null
. "${INIT_DIR}/init.sh"

require_root

if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
  apt_update
fi

log "Installing base packages..."
apt-get install -y git curl ca-certificates

log "Installing Python 3.11..."
SKIP_APT_UPDATE=1 bash "${INIT_DIR}/install-python.sh"

REPO_URL="https://github.com/gguip1/13-team-project-ai.git"
REPO_DIR="/home/ubuntu/13-team-project-ai"
SERVICE_DIR="${REPO_DIR}/services/recommend"
VENV_DIR="/home/ubuntu/.venvs/recommend"

log "Syncing repository..."
if [[ -d "${REPO_DIR}/.git" ]]; then
  sudo -u ubuntu git -C "${REPO_DIR}" fetch origin
  sudo -u ubuntu git -C "${REPO_DIR}" checkout main
  sudo -u ubuntu git -C "${REPO_DIR}" reset --hard origin/main
else
  sudo -u ubuntu git clone --branch main "${REPO_URL}" "${REPO_DIR}"
fi

PY_BIN="/usr/local/bin/python3.11"
if [[ ! -x "${PY_BIN}" ]]; then
  PY_BIN="/usr/bin/python3.11"
fi
[[ -x "${PY_BIN}" ]] || fail "python3.11 not found."

if [[ -x "${VENV_DIR}/bin/python" ]]; then
  CURRENT_VER="$("${VENV_DIR}/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  if [[ "${CURRENT_VER}" != "3.11" ]]; then
    log "Existing venv uses Python ${CURRENT_VER}. Recreating..."
    rm -rf "${VENV_DIR}"
  fi
fi

if [[ ! -d "${VENV_DIR}" ]]; then
  log "Creating venv at ${VENV_DIR}..."
  sudo -u ubuntu "${PY_BIN}" -m venv "${VENV_DIR}"
fi

PIP_BIN="${VENV_DIR}/bin/pip"
[[ -x "${PIP_BIN}" ]] || fail "pip not found in venv: ${PIP_BIN}"
[[ -d "${SERVICE_DIR}" ]] || fail "Service directory not found: ${SERVICE_DIR}"

log "Installing Python dependencies..."
sudo -u ubuntu "${PIP_BIN}" install -U pip
sudo -u ubuntu "${PIP_BIN}" install -r "${SERVICE_DIR}/requirements.txt"

UNIT_FILE="/etc/systemd/system/recommend.service"
log "Writing systemd unit file..."
cat <<'EOF' > "${UNIT_FILE}"
[Unit]
Description=Recommend API
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/13-team-project-ai/services/recommend
Environment="PATH=/home/ubuntu/.venvs/recommend/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/home/ubuntu/.venvs/recommend/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable recommend
systemctl restart recommend

log "Provisioning complete. Check logs with: journalctl -u recommend -f"
