#!/bin/bash
# Postgres Exporter 설치 스크립트 (sh/bash 호환)
set -e

VERSION="0.15.0"
ARCH="amd64"

# 아키텍처 자동 감지
MACHINE_TYPE=$(uname -m)
if [ "$MACHINE_TYPE" = "aarch64" ] || [ "$MACHINE_TYPE" = "arm64" ]; then
  ARCH="arm64"
else
  ARCH="amd64"
fi

echo "=== Postgres Exporter ${VERSION} (${ARCH}) 설치 시작 ==="
echo "주의: 실행 전 DATA_SOURCE_NAME 환경변수가 설정되어 있거나, 서비스 파일을 수정해야 합니다."

cd /tmp
WGET_URL="https://github.com/prometheus-community/postgres_exporter/releases/download/v${VERSION}/postgres_exporter-${VERSION}.linux-${ARCH}.tar.gz"
echo "다운로드 중: ${WGET_URL}"
wget -O postgres_exporter.tar.gz "${WGET_URL}"
tar xvfz postgres_exporter.tar.gz
sudo mv postgres_exporter-${VERSION}.linux-${ARCH}/postgres_exporter /usr/local/bin/

# 사용자 생성
if ! id "postgres_exporter" >/dev/null 2>&1; then
    echo "postgres_exporter 사용자 생성 중..."
    sudo useradd -rs /bin/false postgres_exporter
fi

# 서비스 파일 생성
# 주의: 실제 비밀번호는 환경에 맞게 수정 필요
cat <<EOF | sudo tee /etc/systemd/system/postgres_exporter.service
[Unit]
Description=Postgres Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
# 기본값: 로컬 postgres 유저 (비밀번호 없음 또는 peer 인증)
Environment="DATA_SOURCE_NAME=postgresql://postgres:postgres@localhost:5432/postgres?sslmode=disable"
ExecStart=/usr/local/bin/postgres_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 보안 설정: 비밀번호가 포함된 서비스 파일은 root만 읽을 수 있어야 함
sudo chmod 600 /etc/systemd/system/postgres_exporter.service

sudo systemctl daemon-reload
sudo systemctl enable --now postgres_exporter

echo "=== Postgres Exporter 설치 완료 ==="
sudo systemctl status postgres_exporter --no-pager