#!/bin/bash
set -euo pipefail

REDIS_PASSWORD="${redis_password}"
MASTER_IP="${redis_master_ip}"
SENTINEL_MASTER_NAME="${sentinel_master_name}"
HOSTNAME="${hostname}"
LOKI_URL="${loki_url}"

hostnamectl set-hostname "$HOSTNAME"
apt-get update -y

# =============================================================================
# 1. Redis — Replica 모드
# =============================================================================
apt-get install -y redis-server

cat > /etc/redis/redis.conf << CONF
bind 0.0.0.0
port 6379
daemonize no
supervised systemd

requirepass $REDIS_PASSWORD
masterauth $REDIS_PASSWORD

replicaof $MASTER_IP 6379

save 900 1
save 300 10
save 60 10000
dbfilename dump.rdb
dir /var/lib/redis

maxmemory 1gb
maxmemory-policy noeviction
appendonly yes
appendfilename "appendonly.aof"
CONF

systemctl restart redis-server
systemctl enable redis-server
echo "[INFO] Redis Replica 설치 완료"

# =============================================================================
# 2. Sentinel
# =============================================================================
mkdir -p /etc/redis
cat > /etc/redis/sentinel.conf << CONF
port 26379
bind 0.0.0.0
daemonize no

sentinel monitor $SENTINEL_MASTER_NAME $MASTER_IP 6379 2
sentinel auth-pass $SENTINEL_MASTER_NAME $REDIS_PASSWORD
sentinel down-after-milliseconds $SENTINEL_MASTER_NAME 5000
sentinel failover-timeout $SENTINEL_MASTER_NAME 60000
sentinel parallel-syncs $SENTINEL_MASTER_NAME 1
CONF

chown redis:redis /etc/redis/sentinel.conf

cat > /etc/systemd/system/redis-sentinel.service << SVC
[Unit]
Description=Redis Sentinel
After=network.target redis-server.service

[Service]
Type=simple
User=redis
Group=redis
ExecStart=/usr/bin/redis-server /etc/redis/sentinel.conf --sentinel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl start redis-sentinel
systemctl enable redis-sentinel
echo "[INFO] Redis Sentinel 설치 완료"

# =============================================================================
# 3. Node Exporter (시스템 메트릭 → Prometheus)
# =============================================================================
NODE_EXPORTER_VERSION="1.9.0"
ARCH=$(dpkg --print-architecture)
cd /tmp
wget -q "https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-$${ARCH}.tar.gz"
tar xzf "node_exporter-$${NODE_EXPORTER_VERSION}.linux-$${ARCH}.tar.gz"
cp "node_exporter-$${NODE_EXPORTER_VERSION}.linux-$${ARCH}/node_exporter" /usr/local/bin/
chmod +x /usr/local/bin/node_exporter

cat > /etc/systemd/system/node-exporter.service << SVC
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl start node-exporter
systemctl enable node-exporter
echo "[INFO] Node Exporter 설치 완료 (포트 9100)"

# =============================================================================
# 4. Redis Exporter (Redis 메트릭 → Prometheus)
# =============================================================================
REDIS_EXPORTER_VERSION="1.67.0"
cd /tmp
wget -q "https://github.com/oliver006/redis_exporter/releases/download/v$${REDIS_EXPORTER_VERSION}/redis_exporter-v$${REDIS_EXPORTER_VERSION}.linux-$${ARCH}.tar.gz"
tar xzf "redis_exporter-v$${REDIS_EXPORTER_VERSION}.linux-$${ARCH}.tar.gz"
cp "redis_exporter-v$${REDIS_EXPORTER_VERSION}.linux-$${ARCH}/redis_exporter" /usr/local/bin/
chmod +x /usr/local/bin/redis_exporter

cat > /etc/systemd/system/redis-exporter.service << SVC
[Unit]
Description=Redis Exporter
After=network.target redis-server.service

[Service]
Type=simple
ExecStart=/usr/local/bin/redis_exporter --redis.addr=redis://localhost:6379 --redis.password=$REDIS_PASSWORD
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl start redis-exporter
systemctl enable redis-exporter
echo "[INFO] Redis Exporter 설치 완료 (포트 9121)"

# =============================================================================
# 5. Promtail (로그 → Loki)
# =============================================================================
PROMTAIL_VERSION="3.4.2"
cd /tmp
wget -q "https://github.com/grafana/loki/releases/download/v$${PROMTAIL_VERSION}/promtail-linux-$${ARCH}.zip"
apt-get install -y unzip
unzip -o "promtail-linux-$${ARCH}.zip"
cp "promtail-linux-$${ARCH}" /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

mkdir -p /etc/promtail
cat > /etc/promtail/config.yml << CONF
server:
  http_listen_port: 3100
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: $LOKI_URL
    external_labels:
      host: $HOSTNAME
      env: prod

scrape_configs:
  - job_name: redis
    static_configs:
      - targets: [localhost]
        labels:
          job: redis
          __path__: /var/log/redis/*.log
  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          __path__: /var/log/syslog
CONF

cat > /etc/systemd/system/promtail.service << SVC
[Unit]
Description=Promtail
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl start promtail
systemctl enable promtail
echo "[INFO] Promtail 설치 완료"

echo "[INFO] 전체 설치 완료: Redis + Sentinel + Node Exporter + Redis Exporter + Promtail"
