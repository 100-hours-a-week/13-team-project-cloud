#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/rabbitmq-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== RabbitMQ 설치 시작: $(date) ==="

# -----------------------------------------------------------------------------
# 1. 시스템 기본 설정
# -----------------------------------------------------------------------------
hostnamectl set-hostname "${hostname}"
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl gnupg apt-transport-https socat logrotate

# -----------------------------------------------------------------------------
# 2. Erlang + RabbitMQ 공식 저장소 (Cloudsmith)
# -----------------------------------------------------------------------------
# RabbitMQ signing keys
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | gpg --dearmor -o /usr/share/keyrings/com.rabbitmq.team.gpg
curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key" | gpg --dearmor -o /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg
curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key" | gpg --dearmor -o /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg

# Erlang 저장소
cat > /etc/apt/sources.list.d/rabbitmq.list << 'REPO'
deb [arch=arm64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-erlang/deb/ubuntu noble main
deb [arch=arm64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.rabbitmq.com/rabbitmq/rabbitmq-server/deb/ubuntu noble main
REPO

apt-get update -y

# Erlang (RabbitMQ에 필요한 최소 패키지만)
apt-get install -y erlang-base \
  erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
  erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
  erlang-runtime-tools erlang-snmp erlang-ssl erlang-syntax-tools \
  erlang-tftp erlang-tools erlang-xmerl

# RabbitMQ Server
apt-get install -y rabbitmq-server

# -----------------------------------------------------------------------------
# 3. RabbitMQ 설정 — 프로덕션 튜닝
# -----------------------------------------------------------------------------
cat > /etc/rabbitmq/rabbitmq.conf << 'CONF'
# === 리스너 ===
listeners.tcp.default = 5672

# === Management 플러그인 ===
management.tcp.port = 15672

# === Prometheus 메트릭 ===
prometheus.tcp.port = 15692

# === 메모리 / 디스크 제한 ===
# 시스템 메모리의 60% 사용 (t4g.small = 2GB → ~1.2GB)
vm_memory_high_watermark.relative = 0.6
# 디스크 여유 공간 최소 1GB
disk_free_limit.absolute = 1GB

# === 커넥션 / 채널 ===
# 앱 서버 커넥션 수 제한 (1대 기준, 충분한 여유)
channel_max = 128
heartbeat = 60

# === 로깅 ===
log.file.level = warning
log.console = false
log.file = /var/log/rabbitmq/rabbit.log
log.file.rotation.size = 50000000
log.file.rotation.count = 5

# === 보안 ===
loopback_users.guest = true
CONF

# -----------------------------------------------------------------------------
# 4. 플러그인 활성화
# -----------------------------------------------------------------------------
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_prometheus

# -----------------------------------------------------------------------------
# 5. 서비스 시작 + 사용자 설정
# -----------------------------------------------------------------------------
systemctl enable rabbitmq-server
systemctl restart rabbitmq-server

# 기본 guest 삭제 + 관리자 계정 생성
sleep 5  # RabbitMQ 시작 대기
rabbitmqctl delete_user guest 2>/dev/null || true
rabbitmqctl add_user "${rabbitmq_user}" "${rabbitmq_password}"
rabbitmqctl set_user_tags "${rabbitmq_user}" administrator
rabbitmqctl set_permissions -p / "${rabbitmq_user}" ".*" ".*" ".*"

# 애플리케이션용 vhost
rabbitmqctl add_vhost matchimban
rabbitmqctl set_permissions -p matchimban "${rabbitmq_user}" ".*" ".*" ".*"

# -----------------------------------------------------------------------------
# 5-1. Exchange / Queue 사전 생성 (rabbitmqadmin)
# -----------------------------------------------------------------------------
ADMIN_URL="http://127.0.0.1:15672"

# Management API 준비 대기
for i in $(seq 1 20); do
  if curl -sf -u "${rabbitmq_user}:${rabbitmq_password}" "$ADMIN_URL/api/overview" &>/dev/null; then
    echo "Management API 준비 완료"
    break
  fi
  echo "Management API 대기... ($i/20)"
  sleep 3
done

# rabbitmqadmin CLI 다운로드 (Management 플러그인 HTTP API에서 제공)
curl -sf -u "${rabbitmq_user}:${rabbitmq_password}" "$ADMIN_URL/cli/rabbitmqadmin" -o /usr/local/bin/rabbitmqadmin
chmod +x /usr/local/bin/rabbitmqadmin

ADMIN="rabbitmqadmin --host=127.0.0.1 --port=15672 --username=${rabbitmq_user} --password=${rabbitmq_password} --vhost=matchimban"

# Exchange 생성
$ADMIN declare exchange name=rag.chat.exchange type=direct durable=true
$ADMIN declare exchange name=rag.chat.dlx type=direct durable=true

# Queue 생성
$ADMIN declare queue name=rag.chat.jobs durable=true \
  arguments='{"x-dead-letter-exchange":"rag.chat.dlx","x-dead-letter-routing-key":"rag.chat.jobs.dlq"}'
$ADMIN declare queue name=rag.chat.jobs.retry durable=true \
  arguments='{"x-message-ttl":5000,"x-dead-letter-exchange":"rag.chat.exchange","x-dead-letter-routing-key":"rag.chat.jobs"}'
$ADMIN declare queue name=rag.chat.jobs.dlq durable=true

# Binding 설정
$ADMIN declare binding source=rag.chat.exchange destination=rag.chat.jobs routing_key=rag.chat.jobs
$ADMIN declare binding source=rag.chat.exchange destination=rag.chat.jobs.retry routing_key=rag.chat.jobs.retry
$ADMIN declare binding source=rag.chat.dlx destination=rag.chat.jobs.dlq routing_key=rag.chat.jobs.dlq

# -----------------------------------------------------------------------------
# 6. node_exporter 설치
# -----------------------------------------------------------------------------
NODE_EXPORTER_VERSION="1.9.0"
useradd --no-create-home --shell /bin/false node_exporter || true
curl -sL "https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-arm64.tar.gz" | tar xz -C /tmp
cp "/tmp/node_exporter-$${NODE_EXPORTER_VERSION}.linux-arm64/node_exporter" /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service << 'UNIT'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# -----------------------------------------------------------------------------
# 7. 시스템 튜닝 (RabbitMQ 권장)
# -----------------------------------------------------------------------------
cat > /etc/sysctl.d/99-rabbitmq.conf << 'SYSCTL'
# 파일 디스크립터 상한
fs.file-max = 65536
# 네트워크 버퍼
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
# TCP keepalive (빠른 끊김 감지)
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6
SYSCTL
sysctl --system

# RabbitMQ 프로세스 FD 제한
mkdir -p /etc/systemd/system/rabbitmq-server.service.d
cat > /etc/systemd/system/rabbitmq-server.service.d/limits.conf << 'LIMITS'
[Service]
LimitNOFILE=65536
LIMITS
systemctl daemon-reload
systemctl restart rabbitmq-server

echo "=== RabbitMQ 설치 완료: $(date) ==="
echo "AMQP: 5672 | Management: 15672 | Prometheus: 15692 | Node Exporter: 9100"
