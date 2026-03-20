#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/mongodb-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== MongoDB 설치 시작: $(date) ==="

# -----------------------------------------------------------------------------
# 1. 시스템 기본 설정
# -----------------------------------------------------------------------------
hostnamectl set-hostname "${hostname}"
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y curl gnupg

# -----------------------------------------------------------------------------
# 2. MongoDB 8.0 공식 저장소
# -----------------------------------------------------------------------------
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg

echo "deb [arch=arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" \
  > /etc/apt/sources.list.d/mongodb-org-8.0.list

apt-get update -y
apt-get install -y mongodb-org

# -----------------------------------------------------------------------------
# 3. 데이터 / 로그 디렉토리 (별도 경로 — 추후 EBS 마운트 대비)
# -----------------------------------------------------------------------------
mkdir -p /data/mongodb /var/log/mongodb
chown -R mongodb:mongodb /data/mongodb /var/log/mongodb

# -----------------------------------------------------------------------------
# 4. MongoDB 설정 — 프로덕션 튜닝
# -----------------------------------------------------------------------------
cat > /etc/mongod.conf << 'CONF'
# === 스토리지 ===
storage:
  dbPath: /data/mongodb
  wiredTiger:
    engineConfig:
      # 시스템 메모리의 50% — t4g.small(2GB) 기준 ~1GB
      cacheSizeGB: 1
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

# === 로깅 ===
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: reopen
  verbosity: 0

# === 네트워크 ===
net:
  port: 27017
  # 모든 인터페이스에서 수신 (SG로 접근 제어)
  bindIp: 0.0.0.0
  maxIncomingConnections: 256

# === 프로세스 ===
processManagement:
  timeZoneInfo: /usr/share/zoneinfo

# === 보안 ===
security:
  authorization: enabled

# === 운영 프로파일링 ===
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100

# === Replication (추후 3대 확장 대비) ===
# replication:
#   replSetName: "rs0"
CONF

# -----------------------------------------------------------------------------
# 5. 시스템 튜닝 (MongoDB 권장)
# -----------------------------------------------------------------------------
# Transparent Huge Pages 비활성화 (MongoDB 필수 권장)
cat > /etc/systemd/system/disable-thp.service << 'UNIT'
[Unit]
Description=Disable Transparent Huge Pages
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable disable-thp
systemctl start disable-thp

# 커널 파라미터
cat > /etc/sysctl.d/99-mongodb.conf << 'SYSCTL'
# 파일 디스크립터
fs.file-max = 98000
# VM swappiness 최소화
vm.swappiness = 1
# 네트워크 버퍼
net.core.somaxconn = 4096
net.ipv4.tcp_keepalive_time = 120
SYSCTL
sysctl --system

# mongod FD 제한
mkdir -p /etc/systemd/system/mongod.service.d
cat > /etc/systemd/system/mongod.service.d/limits.conf << 'LIMITS'
[Service]
LimitFSIZE=infinity
LimitCPU=infinity
LimitAS=infinity
LimitMEMLOCK=infinity
LimitNOFILE=64000
LimitNPROC=64000
LIMITS
systemctl daemon-reload

# -----------------------------------------------------------------------------
# 6. MongoDB 시작 + 관리자 계정 생성
# -----------------------------------------------------------------------------
systemctl enable mongod
systemctl start mongod

# mongod 시작 대기
for i in $(seq 1 30); do
  if mongosh --quiet --eval "db.runCommand({ping:1})" &>/dev/null; then
    echo "MongoDB 시작 확인"
    break
  fi
  echo "MongoDB 시작 대기... ($i/30)"
  sleep 2
done

# 관리자 계정 생성
mongosh admin --quiet --eval "
  db.createUser({
    user: '${mongodb_admin_user}',
    pwd: '${mongodb_admin_password}',
    roles: [
      { role: 'userAdminAnyDatabase', db: 'admin' },
      { role: 'readWriteAnyDatabase', db: 'admin' },
      { role: 'dbAdminAnyDatabase', db: 'admin' },
      { role: 'clusterMonitor', db: 'admin' }
    ]
  })
"

# 애플리케이션 DB + 전용 사용자 + 컬렉션 초기화
mongosh --quiet -u "${mongodb_admin_user}" -p "${mongodb_admin_password}" --authenticationDatabase admin --eval "
  const chatDb = db.getSiblingDB('matchimban_chat');
  chatDb.createUser({
    user: '${mongodb_admin_user}',
    pwd: '${mongodb_admin_password}',
    roles: [
      { role: 'readWrite', db: 'matchimban_chat' },
      { role: 'dbAdmin', db: 'matchimban_chat' }
    ]
  });
  chatDb.createCollection('chat_messages');
  chatDb.chat_messages.createIndex({ roomId: 1, createdAt: -1 });
  chatDb.chat_messages.createIndex({ senderId: 1 });
"

# -----------------------------------------------------------------------------
# 7. mongodb_exporter 설치 (Percona)
# -----------------------------------------------------------------------------
MONGODB_EXPORTER_VERSION="0.43.1"
useradd --no-create-home --shell /bin/false mongodb_exporter || true

curl -sL "https://github.com/percona/mongodb_exporter/releases/download/v$${MONGODB_EXPORTER_VERSION}/mongodb_exporter-$${MONGODB_EXPORTER_VERSION}.linux-arm64.tar.gz" | tar xz -C /tmp
cp "/tmp/mongodb_exporter-$${MONGODB_EXPORTER_VERSION}.linux-arm64/mongodb_exporter" /usr/local/bin/
chown mongodb_exporter:mongodb_exporter /usr/local/bin/mongodb_exporter

# Exporter 전용 MongoDB 사용자 (최소 권한)
mongosh --quiet -u "${mongodb_admin_user}" -p "${mongodb_admin_password}" --authenticationDatabase admin --eval "
  db.getSiblingDB('admin').createUser({
    user: 'exporter',
    pwd: 'exporter_metrics', // pragma: allowlist secret
    roles: [
      { role: 'clusterMonitor', db: 'admin' },
      { role: 'read', db: 'local' }
    ]
  })
"

cat > /etc/systemd/system/mongodb_exporter.service << 'UNIT'
[Unit]
Description=MongoDB Exporter
After=mongod.service

[Service]
User=mongodb_exporter
Group=mongodb_exporter
Type=simple
Environment=MONGODB_URI=mongodb://exporter:exporter_metrics@localhost:27017/admin?authSource=admin # pragma: allowlist secret
ExecStart=/usr/local/bin/mongodb_exporter \
  --collect-all \
  --web.listen-address=:9216
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable mongodb_exporter
systemctl start mongodb_exporter

# -----------------------------------------------------------------------------
# 8. node_exporter 설치
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
# 9. logrotate 설정
# -----------------------------------------------------------------------------
cat > /etc/logrotate.d/mongodb << 'LOGROTATE'
/var/log/mongodb/mongod.log {
  daily
  rotate 7
  compress
  missingok
  notifempty
  sharedscripts
  postrotate
    /bin/kill -SIGUSR1 $(cat /data/mongodb/mongod.lock 2>/dev/null) 2>/dev/null || true
  endscript
}
LOGROTATE

echo "=== MongoDB 설치 완료: $(date) ==="
echo "MongoDB: 27017 | Exporter: 9216 | Node Exporter: 9100"
