#!/bin/bash
# Nginx Exporter 설치 스크립트 (sh/bash 호환 버전)
set -e

VERSION="1.1.0"
ARCH="amd64"

# 아키텍처 자동 감지 (sh 호환 문법)
MACHINE_TYPE=$(uname -m)
if [ "$MACHINE_TYPE" = "aarch64" ] || [ "$MACHINE_TYPE" = "arm64" ]; then
  ARCH="arm64"
else
  ARCH="amd64"
fi

echo "=== Nginx Exporter ${VERSION} (${ARCH}) 설치 시작 ==="
echo "환경: ${MACHINE_TYPE} -> ${ARCH}"

# 1. 다운로드 및 설치
cd /tmp
WGET_URL="https://github.com/nginxinc/nginx-prometheus-exporter/releases/download/v${VERSION}/nginx-prometheus-exporter_${VERSION}_linux_${ARCH}.tar.gz"
echo "다운로드 중: ${WGET_URL}"
wget -O nginx-exporter.tar.gz "${WGET_URL}"
tar xvfz nginx-exporter.tar.gz
sudo mv nginx-prometheus-exporter /usr/local/bin/

# 2. 사용자 생성 (이미 존재하면 건너뜀)
if ! id "nginx_exporter" >/dev/null 2>&1; then
    echo "nginx_exporter 사용자 생성 중..."
    sudo useradd -rs /bin/false nginx_exporter
fi

# 3. 서비스 파일 생성
cat <<EOF | sudo tee /etc/systemd/system/nginx_exporter.service
[Unit]
Description=Nginx Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nginx_exporter
Group=nginx_exporter
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter -nginx.scrape-uri http://127.0.0.1:80/stub_status
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 4. 서비스 실행
sudo systemctl daemon-reload
sudo systemctl enable --now nginx_exporter

echo "=== Nginx Exporter 설치 완료 ==="
sudo systemctl status nginx_exporter --no-pager