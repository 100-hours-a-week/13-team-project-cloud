# Redis (v2 dev)

## 구성

| 컨테이너 | 이미지 | 포트 | 역할 |
|-----------|--------|------|------|
| redis | redis:7.0 | 6379 | 캐시/세션 저장소 |
| redis-exporter | redis_exporter:v1.67.0 | 9121 | Prometheus 메트릭 |
| promtail | promtail:3.4.2 | - | 로그 → Loki 전송 |

## 사전 작업

```bash
# 0. Docker 권한 부여 (EC2 최초 1회)
sudo usermod -aG docker $USER
newgrp docker

# 1. 데이터 디렉토리 생성
sudo mkdir -p /data/redis

# 2. 환경변수 설정
cp .env.example .env
# REDIS_PASSWORD 값 입력

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

# Redis 접속 테스트
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} ping

# 메모리 사용량
docker compose exec redis redis-cli -a ${REDIS_PASSWORD} info memory | grep used_memory_human

# 메트릭 확인
curl localhost:9121/metrics | head
```

## 설정 파일

| 파일 | 설명 |
|------|------|
| `redis.conf` | 메모리 설정 (maxmemory, appendonly) |
| `promtail.yml` | 로그 수집 → Loki 전송 |
| `.env` | 인증 정보 (gitignore) |

### redis.conf 주요 설정 (t4g.small 2GB 기준)

| 항목 | 값 | 설명 |
|------|-----|------|
| maxmemory | 1200mb | OS/사이드카용 ~800MB 확보 |
| maxmemory-policy | noeviction (기본값) | 메모리 초과 시 write 에러 반환 |
| appendonly | yes | AOF 영속화 활성화 |

인증(`requirepass`)은 docker-compose command에서 `${REDIS_PASSWORD}` 환경변수로 주입.

## 데이터 경로

| 경로 | 설명 |
|------|------|
| `/data/redis` (호스트) | AOF 데이터 영속 저장 |
| `promtail-positions` (named volume) | Promtail 읽기 위치 |
