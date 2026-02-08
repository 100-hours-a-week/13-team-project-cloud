#!/bin/bash
# Node Exporter 설치 스크립트 (sh/bash 호환)
set -e

VERSION="1.7.0"
ARCH="amd64"

# 아키텍처 자동 감지
MACHINE_TYPE=$(uname -m)
if [ "$MACHINE_TYPE" = "aarch64" ] || [ "$MACHINE_TYPE" = "arm64" ]; then
  ARCH="arm64"
else
  ARCH="amd64"
fi

echo "=== Node Exporter ${VERSION} (${ARCH}) 설치 시작 ==="

cd /tmp
WGET_URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-${ARCH}.tar.gz"
echo "다운로드 중: ${WGET_URL}"
wget -O node_exporter.tar.gz "${WGET_URL}"
tar xvfz node_exporter.tar.gz
sudo mv node_exporter-${VERSION}.linux-${ARCH}/node_exporter /usr/local/bin/

# 사용자 생성
if ! id "node_exporter" >/dev/null 2>&1; then
    echo "node_exporter 사용자 생성 중..."
    sudo useradd -rs /bin/false node_exporter
fi

# 서비스 파일 생성
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

echo "=== Node Exporter 설치 완료 ==="
sudo systemctl status node_exporter --no-pager