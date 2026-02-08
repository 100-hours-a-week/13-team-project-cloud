#!/bin/bash
# Redis Exporter 설치 스크립트 (sh/bash 호환)
set -e

VERSION="1.58.0"
ARCH="amd64"

# 아키텍처 자동 감지
MACHINE_TYPE=$(uname -m)
if [ "$MACHINE_TYPE" = "aarch64" ] || [ "$MACHINE_TYPE" = "arm64" ]; then
  ARCH="arm64"
else
  ARCH="amd64"
fi

echo "=== Redis Exporter ${VERSION} (${ARCH}) 설치 시작 ==="

cd /tmp
WGET_URL="https://github.com/oliver006/redis_exporter/releases/download/v${VERSION}/redis_exporter-v${VERSION}.linux-${ARCH}.tar.gz"
echo "다운로드 중: ${WGET_URL}"
wget -O redis_exporter.tar.gz "${WGET_URL}"
tar xvfz redis_exporter.tar.gz
sudo mv redis_exporter-v${VERSION}.linux-${ARCH}/redis_exporter /usr/local/bin/

# 사용자 생성
if ! id "redis_exporter" >/dev/null 2>&1; then
    echo "redis_exporter 사용자 생성 중..."
    sudo useradd -rs /bin/false redis_exporter
fi

# 서비스 파일 생성
cat <<EOF | sudo tee /etc/systemd/system/redis_exporter.service
[Unit]
Description=Redis Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=redis_exporter
Group=redis_exporter
Type=simple
# 비밀번호가 있다면: -redis.password "yourpassword" 추가
ExecStart=/usr/local/bin/redis_exporter -redis.addr localhost:6379
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 보안 설정: 비밀번호가 포함될 수 있으므로 권한 제한
sudo chmod 600 /etc/systemd/system/redis_exporter.service

sudo systemctl daemon-reload
sudo systemctl enable --now redis_exporter

echo "=== Redis Exporter 설치 완료 ==="
sudo systemctl status redis_exporter --no-pager