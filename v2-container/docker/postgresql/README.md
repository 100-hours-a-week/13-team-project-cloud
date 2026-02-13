# PostgreSQL (v2 dev)

## 구성

| 컨테이너 | 이미지 | 포트 | 역할 |
|-----------|--------|------|------|
| postgres | postgres:16 | 5432 | 메인 DB |
| postgres-exporter | postgres-exporter:v0.16.0 | 9187 | Prometheus 메트릭 |
| promtail | promtail:3.4.2 | - | 로그 → Loki 전송 |

## 사전 작업

```bash
# 0. Docker 권한 부여 (EC2 최초 1회)
sudo usermod -aG docker $USER
newgrp docker

# 1. 데이터 디렉토리 생성
sudo mkdir -p /data/postgresql

# 2. 환경변수 설정
cp .env.example .env
# POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB 값 입력

# 3. Loki DNS 레코드 확인 (terraform apply 완료 여부)
nslookup loki.internal.dev.moyeobab.com
```

## 실행

```bash
docker compose up -d
```

## 확인

```bash
# 컨테이너 상태
docker compose ps

# DB 접속 테스트
docker compose exec postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -c "SELECT version();"

# 메트릭 확인
curl localhost:9187/metrics | head
```

## 설정 파일

| 파일 | 설명 |
|------|------|
| `postgresql.conf` | 성능 튜닝 (shared_buffers, work_mem 등) |
| `promtail.yml` | 로그 수집 → Loki 전송 |
| `.env` | 인증 정보 (gitignore) |

### postgresql.conf 주요 설정 (t4g.small 2GB 기준)

| 항목 | 값 | 설명 |
|------|-----|------|
| shared_buffers | 512MB | RAM의 25% |
| effective_cache_size | 1GB | RAM의 50% |
| work_mem | 4MB | 쿼리당 정렬/해시 |
| maintenance_work_mem | 128MB | VACUUM, CREATE INDEX |
| wal_level | replica | 리드 레플리카 대비 |
| log_min_duration_statement | 1000ms | 슬로우 쿼리 로깅 |

## 데이터 경로

| 경로 | 설명 |
|------|------|
| `/data/postgresql` (호스트) | DB 데이터 영속 저장 |
| `promtail-positions` (named volume) | Promtail 읽기 위치 |

## 로그 흐름

```
PostgreSQL → stderr → Docker json-file → Promtail → Loki
```

`logging_collector = off` (기본값 유지) — Docker가 stderr를 캡처하여 Promtail이 수집.
