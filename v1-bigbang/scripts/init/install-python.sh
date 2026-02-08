#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/init.sh"

require_root
if [[ "${SKIP_APT_UPDATE:-0}" -eq 0 ]]; then
  apt_update
fi

if command -v python3.11 >/dev/null 2>&1; then
  echo "python3.11 already installed."
  exit 0
fi

PYTHON_VERSION="${PYTHON_VERSION:-3.11.9}"
PYENV_ROOT="${PYENV_ROOT:-/opt/pyenv}"
USE_PYENV="${USE_PYENV:-0}"

HAS_APT_PY311=0
if apt-cache policy python3.11 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -qv "(none)"; then
  HAS_APT_PY311=1
fi

if [[ "${USE_PYENV}" -ne 1 && "${HAS_APT_PY311}" -eq 1 ]]; then
  apt-get install -y python3.11 python3.11-venv
  exit 0
fi

apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  git \
  libbz2-dev \
  libffi-dev \
  liblzma-dev \
  libncursesw5-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxmlsec1-dev \
  tk-dev \
  xz-utils \
  zlib1g-dev

if [[ ! -d "${PYENV_ROOT}" ]]; then
  git clone https://github.com/pyenv/pyenv.git "${PYENV_ROOT}"
fi

export PYENV_ROOT
export PATH="${PYENV_ROOT}/bin:${PATH}"

"${PYENV_ROOT}/bin/pyenv" install -s "${PYTHON_VERSION}"
"${PYENV_ROOT}/bin/pyenv" global "${PYTHON_VERSION}"

PYENV_PY="${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin/python3.11"
PYENV_PIP="${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin/pip3.11"
if [[ -x "${PYENV_PY}" ]]; then
  ln -sf "${PYENV_PY}" /usr/local/bin/python3.11
fi
if [[ -x "${PYENV_PIP}" ]]; then
  ln -sf "${PYENV_PIP}" /usr/local/bin/pip3.11
fi

if [[ "${SET_DEFAULT_PYTHON:-0}" -eq 1 ]]; then
  ln -sf "${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin/python3" /usr/local/bin/python3
fi
