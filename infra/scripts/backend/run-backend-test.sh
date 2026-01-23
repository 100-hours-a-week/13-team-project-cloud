#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../init/init.sh"

require_root

SERVICE_NAME="${SERVICE_NAME:-matchimban-backend-test}"
SERVICE_USER="${SERVICE_USER:-ubuntu}"
SERVICE_GROUP="${SERVICE_GROUP:-ubuntu}"
JAR_PATH="${JAR_PATH:-${SCRIPT_DIR}/matchimban-api-0.0.1-SNAPSHOT.jar}"
JAVA_BIN="${JAVA_BIN:-/usr/bin/java}"
APP_PORT="${APP_PORT:-8080}"
SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-test}"
JAVA_OPTS="${JAVA_OPTS:-}"

if [[ ! -x "${JAVA_BIN}" ]]; then
  echo "Java not found at ${JAVA_BIN}. Install Java 21 first." >&2
  exit 1
fi

if [[ ! -f "${JAR_PATH}" ]]; then
  echo "Jar not found: ${JAR_PATH}" >&2
  exit 1
fi

UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
cat <<EOF > "${UNIT_FILE}"
[Unit]
Description=Matchimban Backend (test)
After=network.target

[Service]
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=$(dirname "${JAR_PATH}")
Environment=SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE}
Environment=JAVA_OPTS=${JAVA_OPTS}
ExecStart=${JAVA_BIN} \$JAVA_OPTS -jar ${JAR_PATH} --server.port=${APP_PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

echo "Backend test service started: ${SERVICE_NAME}"
echo "Logs: journalctl -u ${SERVICE_NAME} -f"
