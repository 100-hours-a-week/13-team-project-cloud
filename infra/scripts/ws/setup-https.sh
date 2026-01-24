#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../init/init.sh"

usage() {
  cat <<'USAGE'
Usage:
  sudo infra/scripts/ws/setup-https.sh [domain...]

Defaults:
  domains: moyeobab.com api.moyeobab.com

Environment:
  CERTBOT_EMAIL=...   Email for Let's Encrypt registration (recommended).
  CERTBOT_NO_EMAIL=1  Register without email (not recommended).
  REDIRECT=1          Enable HTTP->HTTPS redirect.
  STAGING=1           Use Let's Encrypt staging environment.
  SKIP_APT_UPDATE=1   Skip apt-get update.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_root

DOMAINS=("$@")
if [[ ${#DOMAINS[@]} -eq 0 ]]; then
  DOMAINS=("moyeobab.com" "api.moyeobab.com")
fi

HTTP_CONF="${SCRIPT_DIR}/nginx-http.conf"
HTTPS_CONF="${SCRIPT_DIR}/nginx.conf"
DEST_CONF="/etc/nginx/conf.d/nginx.conf"

if [[ ! -f "$HTTP_CONF" ]]; then
  echo "HTTP config not found: $HTTP_CONF" >&2
  exit 1
fi

if [[ ! -f "$HTTPS_CONF" ]]; then
  echo "HTTPS config not found: $HTTPS_CONF" >&2
  exit 1
fi

if ! command -v certbot >/dev/null 2>&1; then
  if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
    apt_update
  fi
  apt-get install -y certbot python3-certbot-nginx
fi

if [[ -f /etc/nginx/sites-enabled/default ]]; then
  rm -f /etc/nginx/sites-enabled/default
fi

install -m 0644 "$HTTP_CONF" "$DEST_CONF"
nginx -t
systemctl reload nginx

certbot_args=(--nginx)
for domain in "${DOMAINS[@]}"; do
  certbot_args+=( -d "$domain" )
done

if [[ "${REDIRECT:-0}" -eq 1 ]]; then
  certbot_args+=(--redirect)
fi

if [[ "${STAGING:-0}" -eq 1 ]]; then
  certbot_args+=(--staging)
fi

if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
  certbot_args+=(--non-interactive --agree-tos --email "$CERTBOT_EMAIL")
elif [[ "${CERTBOT_NO_EMAIL:-0}" -eq 1 ]]; then
  certbot_args+=(--non-interactive --agree-tos --register-unsafely-without-email)
fi

certbot "${certbot_args[@]}"

install -m 0644 "$HTTPS_CONF" "$DEST_CONF"
nginx -t
systemctl reload nginx

echo "Done."
