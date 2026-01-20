#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/init.sh"

require_root

POSTGRES_USER="appuser"
POSTGRES_PASSWORD="CHANGE_ME"
POSTGRES_DB="appdb"
POSTGRES_ALLOWED_CIDR="0.0.0.0/0"
POSTGRES_LISTEN="*"
POSTGRES_AUTH_METHOD="scram-sha-256"

if [[ "${POSTGRES_PASSWORD}" == "CHANGE_ME" ]]; then
  echo "Set POSTGRES_PASSWORD in this script before running." >&2
  exit 1
fi

PG_CONF_DIR=""
if command -v pg_lsclusters >/dev/null 2>&1; then
  PG_VERSION="$(pg_lsclusters --no-header | awk 'NR==1 {print $1}')"
  if [[ -n "${PG_VERSION}" && -d "/etc/postgresql/${PG_VERSION}/main" ]]; then
    PG_CONF_DIR="/etc/postgresql/${PG_VERSION}/main"
  fi
fi

if [[ -z "${PG_CONF_DIR}" ]]; then
  PG_CONF_DIR="$(ls -d /etc/postgresql/*/main 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "${PG_CONF_DIR}" ]]; then
  echo "PostgreSQL config directory not found." >&2
  exit 1
fi

PG_CONF="${PG_CONF_DIR}/postgresql.conf"
PG_HBA="${PG_CONF_DIR}/pg_hba.conf"

if grep -qE '^[# ]*listen_addresses' "${PG_CONF}"; then
  sed -i "s@^[# ]*listen_addresses.*@listen_addresses = '${POSTGRES_LISTEN}'@" "${PG_CONF}"
else
  echo "listen_addresses = '${POSTGRES_LISTEN}'" >> "${PG_CONF}"
fi

HBA_LINE="host all all ${POSTGRES_ALLOWED_CIDR} ${POSTGRES_AUTH_METHOD}"
if ! grep -qF "${HBA_LINE}" "${PG_HBA}"; then
  echo "${HBA_LINE}" >> "${PG_HBA}"
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
    CREATE ROLE "${POSTGRES_USER}" LOGIN PASSWORD '${POSTGRES_PASSWORD}';
  ELSE
    ALTER ROLE "${POSTGRES_USER}" WITH PASSWORD '${POSTGRES_PASSWORD}';
  END IF;
END
\$\$;
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${POSTGRES_DB}') THEN
    CREATE DATABASE "${POSTGRES_DB}" OWNER "${POSTGRES_USER}";
  END IF;
END
\$\$;
SQL

systemctl restart postgresql
