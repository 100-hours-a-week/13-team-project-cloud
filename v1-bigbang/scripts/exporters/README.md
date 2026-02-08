# Monitoring Exporters 설치 가이드

이 디렉토리는 Prometheus 모니터링을 위한 각종 Exporter들의 설치 스크립트를 관리합니다.
모든 스크립트는 **App Server (10.0.0.161)**에서 `root` 권한으로 실행해야 합니다.

## 📋 Exporter 목록 및 포트

| Exporter | Port | 설명 |
|---|---|---|
| **Node Exporter** | 9100 | 서버 리소스 (CPU, RAM, Disk, Net) |
| **Nginx Exporter** | 9113 | Nginx 연결 상태 및 요청 처리량 |
| **Redis Exporter** | 9121 | Redis 메모리, 키 개수, 커맨드 통계 |
| **Postgres Exporter** | 9187 | DB 세션, 락, 튜플 상태 등 |

## 🚀 설치 방법

각 디렉토리로 이동하여 `install.sh`를 실행하세요.

### 1. Node Exporter (필수)
서버의 기본 상태를 모니터링합니다.
```bash
cd infra/scripts/exporters/node
sudo ./install.sh
```

### 2. Nginx Exporter
Nginx의 `stub_status` 모듈이 활성화되어 있어야 합니다.
```bash
cd infra/scripts/exporters/nginx
sudo ./install.sh
```

### 3. Redis Exporter
Redis 서버가 로컬(`localhost:6379`)에 떠 있어야 합니다.
```bash
cd infra/scripts/exporters/redis
sudo ./install.sh
```

### 4. Postgres Exporter
데이터베이스 접속 계정(`DATA_SOURCE_NAME`) 설정이 필요합니다.
```bash
cd infra/scripts/exporters/postgres
# 환경변수로 DB 접속 정보 설정 (postgres 계정 권장)
export DATA_SOURCE_NAME="postgresql://postgres:password@localhost:5432/postgres?sslmode=disable"
sudo -E ./install.sh
```

## 🔍 상태 확인
설치 후 서비스가 정상적으로 실행 중인지 확인합니다.
```bash
# 전체 상태 확인
systemctl status node_exporter nginx_exporter redis_exporter postgres_exporter

# 메트릭 확인 (예시)
curl localhost:9100/metrics | head
```

## 🛡️ 보안 그룹 설정 (AWS)
모니터링 서버(10.0.0.111)에서 이 포트들(9100, 9113, 9121, 9187)로 접근할 수 있도록 **인바운드 규칙**을 열어주어야 합니다.
