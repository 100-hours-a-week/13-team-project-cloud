#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/../init/init.sh"

require_root
if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
  apt_update
fi

JAVA_PKG="${JAVA_PKG:-openjdk-21-jdk}"

if command -v java >/dev/null 2>&1; then
  java_version="$(java -version 2>&1 | awk -F\" '/version/ {print $2; exit}')"
  if [[ "${java_version}" == 21* ]]; then
    echo "Java 21 already installed."
    exit 0
  fi
fi

apt-get install -y "${JAVA_PKG}"
java -version
