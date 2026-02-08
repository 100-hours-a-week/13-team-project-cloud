#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[backend-setup]"

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

# Configuration (Matched with CD Pipeline)
SERVICE_NAME="${SERVICE_NAME:-moyeobab-api}"
SERVICE_USER="${SERVICE_USER:-ubuntu}"
SERVICE_GROUP="${SERVICE_GROUP:-ubuntu}"
APP_DIR="${APP_DIR:-/home/ubuntu/app}"
JAR_PATH="${APP_DIR}/app.jar"
ENV_FILE="${APP_DIR}/env.conf"
JAVA_BIN="${JAVA_BIN:-/usr/bin/java}"

log "Checking dependencies..."
if [[ ! -x "${JAVA_BIN}" ]]; then
  fail "Java not found at ${JAVA_BIN}. Please run install-java.sh first."
fi

log "Preparing application directory..."
if [[ ! -d "${APP_DIR}" ]]; then
  mkdir -p "${APP_DIR}"
  chown "${SERVICE_USER}:${SERVICE_GROUP}" "${APP_DIR}"
fi

UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
log "Writing systemd unit file: ${UNIT_FILE}"

cat <<EOF > "${UNIT_FILE}"
[Unit]
Description=Moyeobab API Server
After=network.target postgresql.service redis-server.service

[Service]
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${APP_DIR}
# '-' prefix allows service to start even if ENV_FILE is missing (it'll be injected by CD)
EnvironmentFile=-${ENV_FILE}
ExecStart=${JAVA_BIN} -jar ${JAR_PATH}
SuccessExitStatus=143
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

log "Registering and enabling service..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

log "Setup complete."
log "Next: Deploy app.jar and env.conf via CD, then run: sudo systemctl restart ${SERVICE_NAME}"