# 모여밥 Infra Fault Injection 시나리오

## 개요

인프라 레벨 장애는 애플리케이션 시나리오와 달리 **자동 복구 여부보다 복구 절차의 정확성과 복구 시간(RTO)** 을 검증하는 데 초점을 맞춘다.

특히 PostgreSQL은 자동 페일오버가 설정되어 있지 않아 수동 승격 절차가 올바르게 동작하는지 반드시 검증해야 한다.

---

## AWS FIS 사용 이유

수동으로 인스턴스를 종료하는 방식은 실수 위험이 있고 재현성이 낮다.

AWS FIS를 사용하는 이유는 다음과 같다.

- **안전한 실험 환경**: Stop Condition(CloudWatch Alarm) 설정으로 임계값 초과 시 실험 자동 중단
- **AWS 리소스와 네이티브 통합**: EC2 인스턴스를 태그/AZ 기준으로 정밀하게 타겟 지정
- **재현 가능한 실험 템플릿**: 동일한 조건으로 반복 실행 가능
- **실험 이력 관리**: 실험 실행 이력, 결과, 중단 사유 기록

---

## 현재 인프라 구성

```
ap-northeast-2a
  ├── moyeobab-prod-v2-postgresql-primary   (t4g.small) ← SPOF
  └── moyeobab-prod-v2-redis-primary        (t4g.small) ← SPOF

ap-northeast-2b
  ├── moyeobab-prod-v2-postgresql-standby   (t4g.small)
  ├── moyeobab-prod-v2-redis-standby        (t4g.small)
  └── moyeobab-prod-v2-redis-sentinel       (t4g.micro)
```

> **핵심 위험 요소**: PostgreSQL Primary와 Redis Primary가 모두 2a에 위치.
> 
> 
> 2a AZ 장애 시 DB + Redis 동시 다운으로 서비스 전체 중단 발생.
> 
> PostgreSQL은 자동 페일오버 미설정으로 **수동 승격 절차** 필요.
> 

---

## Steady State 정의

인프라 시나리오의 Steady State는 **복구 가능 여부 + RTO(복구 목표 시간)** 를 기준으로 정의한다.

| 구성요소 | 정상 상태 지표 | RTO 목표 | 복구 방식 |
| --- | --- | --- | --- |
| PostgreSQL Primary | `pg_up` = 1, 쿼리 정상 응답 | 5분 이내 | **수동 승격** (Standby → Primary) |
| Redis Primary | `redis_up` = 1, Sentinel 감지 | 30초 이내 | **자동 페일오버** (Sentinel) |
| Backend EC2 (ASG) | `up{job="backend"}` = 1 | 3분 이내 | **자동 복구** (ASG) |
| 2a AZ 전체 | 위 3가지 모두 | 10분 이내 | PostgreSQL 수동 + Redis 자동 |

---

## 시나리오 1: PostgreSQL Primary EC2 종료

### 가설

PostgreSQL Primary가 종료되더라도 수동 승격 절차를 통해 RTO(5분) 이내에 복구되며,

복구 후 Backend가 새 Primary에 자동 재연결된다.

### Steady State

| 지표 | 기준 |
| --- | --- |
| PostgreSQL 가용성 | `pg_up` = 1 |
| RTO | < 5분 (수동 승격 완료까지) |
| Backend Error Rate | 복구 후 < 1% |
| Backend Latency P95 | 복구 후 < 500ms |

### AWS FIS 실험 구성

```
Action    : aws:ec2:terminate-instances
Target    : moyeobab-prod-v2-postgresql-primary (인스턴스 ID 직접 지정)
Duration  : PT10M
Stop Condition: Backend Error Rate > 10%
```

### 수동 승격 절차

```bash
# 1. Standby EC2에 SSH 접속
ssh moyeobab-prod-v2-postgresql-standby

# 2. Standby를 Primary로 승격
docker exec -it postgresql pg_ctl promote -D /var/lib/postgresql/data

# 3. 승격 확인
docker exec -it postgresql psql -U postgres -c "SELECT pg_is_in_recovery();"
# → f (false) 이면 Primary 승격 완료

# 4. Backend의 DB 연결 설정 변경 (Parameter Store)
# /moyeobab/spring/prod/DB_HOST → Standby EC2 IP로 변경

# 5. Backend 컨테이너 재시작 (새 DB_HOST 반영)
docker restart backend-app
```

### 검증 항목

- [ ]  Primary 종료 후 Backend에서 DB 연결 오류가 발생하는가
- [ ]  Grafana `pg_up` 메트릭이 0으로 감지되는가
- [ ]  Discord Alert가 발송되는가
- [ ]  수동 승격 완료까지 RTO(5분) 이내인가
- [ ]  승격 후 Backend가 새 Primary에 자동 재연결되는가
- [ ]  복구 후 Backend Error Rate가 SLO(1%) 이내로 돌아오는가

### 모니터링 포인트

- Grafana: DB 가용성 패널, Backend Error Rate 패널
- Loki: `{container="backend-app"} |= "could not connect to server"`

### 주의사항

- **dev 환경에서 먼저 검증 후 prod 진행**
- 피크 타임(점심/저녁) 외 시간대에 실행
- 승격 후 기존 Primary EC2 복구 시 **Split-Brain 방지**를 위해 기존 Primary를 Standby로 재구성해야 함

---

## 시나리오 2: Redis Primary EC2 종료

### 가설

Redis Primary가 종료되더라도 Sentinel 자동 페일오버로 RTO(30초) 이내에 복구되며, SLO를 위반하지 않는다.

### Steady State

| 지표 | 기준 |
| --- | --- |
| Redis 가용성 | `redis_up` = 1 |
| RTO | < 30초 (Sentinel 자동 페일오버) |
| Backend Error Rate | < 1% |
| Backend Latency P95 | < 500ms |

### AWS FIS 실험 구성

```
Action    : aws:ec2:terminate-instances
Target    : moyeobab-prod-v2-redis-primary (인스턴스 ID 직접 지정)
Duration  : PT5M
Stop Condition: Backend Error Rate > 10%
```

### 검증 항목

- [ ]  Sentinel이 Primary 다운을 감지하는가
- [ ]  Standby(2b)가 새 Primary로 자동 승격되는가
- [ ]  페일오버 시간이 RTO(30초) 이내인가
- [ ]  Backend가 새 Primary로 자동 재연결되는가
- [ ]  세션/채팅 기능이 복구되는가
- [ ]  Grafana `redis_up` 메트릭이 복구되는가
- [ ]  Discord Alert가 발송되는가

### 모니터링 포인트

- Grafana: Redis 가용성 패널, Backend Error Rate 패널
- Loki: `{container="backend-app"} |= "RedisConnectionException"`

---

## 시나리오 3: AZ 2a 전체 격리 (최악의 시나리오)

### 가설

2a AZ 전체가 격리되더라도 PostgreSQL 수동 승격 + Redis 자동 페일오버 + ASG 자동 복구로

RTO(10분) 이내에 서비스가 복구된다.

### Steady State

| 지표 | 기준 |
| --- | --- |
| PostgreSQL 가용성 | `pg_up` = 1 |
| Redis 가용성 | `redis_up` = 1 |
| Backend 가용성 | `up{job="backend"}` = 1 |
| RTO | < 10분 (전체 복구 완료까지) |
| Backend Error Rate | 복구 후 < 1% |

### AWS FIS 실험 구성

```
Action    : aws:ec2:terminate-instances
Target    : ap-northeast-2a의 prod 인스턴스 전체
            (필터: AZ=ap-northeast-2a, 태그: Environment=prod)
Duration  : PT15M
Stop Condition: 없음 (이 시나리오는 완전 복구 절차 검증이 목적)
```

> **주의**: 이 시나리오는 Stop Condition 없이 실행하여 실제 장애 복구 절차 전체를 검증한다.
> 
> 
> **반드시 dev 환경에서 먼저 검증 후 prod 진행.**
> 

### 복구 절차 (순서 중요)

```
1단계: Redis 자동 페일오버 확인 (목표: 30초)
  → Sentinel이 2b Standby를 자동 승격하는지 확인
  → redis-cli -h [sentinel-ip] sentinel masters 로 확인

2단계: PostgreSQL 수동 승격 (목표: 5분)
  → 시나리오 1의 수동 승격 절차 동일하게 진행
  → Standby(2b) → Primary 승격
  → Parameter Store DB_HOST 변경

3단계: Backend ASG 확인 (목표: 3분)
  → 2a 인스턴스 종료 후 ASG가 2b에 새 인스턴스 생성하는지 확인
  → ALB Target Group에 새 인스턴스 등록 확인

4단계: 전체 서비스 정상 확인
  → GET /api/ping 200 응답 확인
  → GET /api/v1/meetings 정상 응답 확인
```

### 검증 항목

- [ ]  Redis Sentinel이 2b Standby를 자동 승격하는가 (30초 이내)
- [ ]  PostgreSQL 수동 승격이 RTO(5분) 이내에 완료되는가
- [ ]  ASG가 2b에 새 Backend 인스턴스를 자동 생성하는가
- [ ]  ALB가 2b 인스턴스로만 트래픽을 라우팅하는가
- [ ]  전체 복구 완료까지 RTO(10분) 이내인가
- [ ]  복구 후 Critical Path API가 정상 동작하는가
- [ ]  Discord Alert가 모든 구성요소에 대해 발송되는가

### 모니터링 포인트

- Grafana: DB 가용성, Redis 가용성, Backend 가용성, Error Rate 패널 동시 모니터링
- Loki: `{container="backend-app"} |= "ERROR"`

### 주의사항

- **이 시나리오는 실제 서비스 중단을 동반하므로 반드시 트래픽이 없는 새벽 시간대에 실행**
- 2a Primary들 복구 후 Split-Brain 방지를 위해 Standby로 재구성 필요
- Sentinel 구성(2b)이 살아있어야 Redis 자동 페일오버가 동작함을 사전 확인
