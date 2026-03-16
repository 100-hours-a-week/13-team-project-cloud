# DR-011: 데이터 계층 배치 전략 선정 - Stateful workload는 클러스터 밖 유지

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-09 |
| 상태 | 승인됨 |
| 적용 범위 | v3 (데이터 계층 배치 기준) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md), [DR-004 Kubernetes 배포 방식 선정](DR-004-kubernetes-distribution-selection.md), [DR-005 컨트롤 플레인 구조 선정](DR-005-kubernetes-control-plane-topology.md), [OPS-005 Prod DB 마이그레이션 실행](../operations/OPS-005-db-migration-execution.md), [OPS-007 Redis v1→v2 마이그레이션 실행](../operations/OPS-007-redis-migration-execution.md) |
| 주요 목표 | Kubernetes 적용 범위를 application layer로 제한하고, stateful data workload의 배치 위치를 클러스터 밖 VM/EC2로 고정 |

---

## 1) 결정

본 설계에서는 **stateful data workload를 클러스터 밖 VM/EC2에 유지**한다.

이번 결정은 Kubernetes 자체를 포기한다는 뜻이 아니다. 설계 기준에서 Kubernetes는 application rollout, service discovery, runtime 표준화에 집중하고, 데이터 계층은 스토리지, 복제, 백업, 복구, 성능 튜닝 책임을 직접 다룰 수 있는 별도 운영 경계로 둔다.

따라서 아래 원칙을 고정한다.

- Kubernetes 기본 대상: `api`, `backend`, `recommend` 등 stateless application workload
- 클러스터 밖 유지 대상: `PostgreSQL`, `Redis`, `MongoDB`, `MQ`, `Kafka`, `Qdrant` 등 stateful data workload
- 외부 데이터 계층 연결 기준: `Route53 private DNS` 또는 이에 준하는 private endpoint 이름 체계
- 데이터 계층의 백업/복구/복제 전략: Kubernetes 리소스가 아니라 각 데이터 엔진별 운영 절차로 관리

---

## 2) 배경

대상 구조는 stateless application layer와 다수의 stateful data layer가 함께 존재한다.

- stateless/app
  - API 서버
  - backend
  - recommend
- stateful/data
  - `Redis`
  - `MQ`
  - `RDB`
  - `MongoDB`
  - `Kafka`
  - `Qdrant`

현재 운영 전제는 아래와 같다.

- 관리형 서비스는 비용 이유로 사용하지 않는다.
- 가능한 한 직접 운영한다.
- Kubernetes를 고려한 핵심 이유는 "운영 편의성"이다.
- 그러나 data layer는 배포보다 스토리지와 데이터 안전성이 운영 난이도의 중심이다.

여기서 중요한 구분은 아래다.

- application layer의 운영 편의성
  - 배포
  - 롤아웃/롤백
  - self-healing
  - service discovery
- data layer의 운영 편의성
  - 디스크
  - 복제
  - 백업
  - 복구
  - 성능 튜닝
  - 장애 원인 추적

설계 기준에서는 Kubernetes가 첫 번째 범주에는 강한 이점을 주지만, 두 번째 범주의 본질적인 난제를 대신 해결하지 못한다고 판단했다.

---

## 3) 선택 기준

이번 선택은 아래 기준으로 평가한다.

### 3.1. 배포 편의성과 데이터 운영 편의성을 분리해서 평가할 수 있는가

Kubernetes가 편하게 만드는 영역과 그렇지 않은 영역을 섞지 않는다. rollout 편의가 data durability 문제를 해결한 것처럼 보이게 만들지 않는 것이 중요하다.

### 3.2. 운영 복잡도가 실제로 줄어드는가

node pool 분리, `StatefulSet`, `PVC`, storage class를 도입하더라도, 실제로 백업/복구/성능/장애 대응이 더 쉬워지는지 본다.

### 3.3. 스토리지 리스크와 장애 도메인을 단순하게 유지하는가

data layer는 CPU보다 디스크와 네트워크 지연, 복제 상태, 장애 시 복구 절차가 더 중요하다. 이 영역은 추상화보다 명시적 운영 경계가 유리할 수 있다.

### 3.4. 데이터 계층의 운영 경계를 명확하게 유지하는가

data workload를 Kubernetes 대상에서 분리한다는 결정이 문서와 운영 절차에서 흔들리지 않아야 한다.

---

## 4) 고려한 대안

검토 대상은 다음 세 가지였다.

- application과 data를 모두 Kubernetes에 배치
- application만 Kubernetes, data는 VM/EC2에 배치
- application과 data를 모두 VM/EC2에 배치

이번 문서는 이 중 두 번째 대안을 기준선으로 확정한다.

---

## 5) 선택 근거

### 5.1. Kubernetes는 application rollout에는 강하지만, data 운영 자체를 단순화하지는 않는다

`Deployment`, readiness/liveness probe, rolling update, service discovery는 stateless workload에 매우 잘 맞는다.

반면 stateful workload의 운영 중심은 아래 항목이다.

- 디스크 영속성
- 복제와 리더 선출
- 백업과 복구 검증
- 성능과 IOPS 보장
- 장애 시 정합성 확인

`StatefulSet`과 `PVC`는 Pod identity와 volume attachment를 표준화할 뿐, 데이터 엔진의 백업/복구 전략을 대신 제공하지 않는다.

### 5.2. node pool 분리는 자원 분리일 뿐, 데이터 운영 난제를 없애지 못한다

application node pool과 data node pool을 나누면 스케줄링 경계는 선명해진다. 그러나 아래 문제는 그대로 남는다.

- 디스크 장애
- 볼륨 attach/mount 실패
- 로컬 디스크 종속성
- CSI 또는 storage backend 이슈
- 노드 장애 이후 데이터 복구 절차

즉 node pool 분리는 "한 클러스터에 같이 둬도 된다"는 조건 일부를 만들 뿐, "운영이 단순해진다"는 결론까지는 주지 않는다.

### 5.3. stateful을 Kubernetes에 올리면 복잡도가 사라지지 않고 다른 계층으로 이동한다

VM/EC2 직접 운영에서는 운영자가 OS, systemd, 디스크, failover를 직접 본다.

Kubernetes 위 stateful에서는 여기에 더해 아래 계층이 추가된다.

- `StatefulSet`
- `PVC/PV`
- `StorageClass`
- CSI
- scheduler 제약
- taint/toleration, affinity

결과적으로 문제를 보는 창이 늘어난다. 장애 시 "DB 문제인지", "Pod 문제인지", "volume attach 문제인지", "노드 문제인지"를 함께 봐야 한다.

### 5.4. 현재 조건에서는 storage abstraction보다 명시적 운영 경계가 더 유리하다

관리형 서비스를 쓰지 않고 직접 운영할수록, 결국 책임은 데이터 엔진과 디스크에 모인다.

특히 아래 워크로드는 Kubernetes에서의 이점보다 storage와 복구 난이도가 더 크게 체감될 가능성이 높다.

- `PostgreSQL`
- `MongoDB`
- `Kafka`
- durable `MQ`
- `Qdrant`

이 워크로드는 프로세스를 다시 띄우는 것보다, 데이터가 안전하게 남아 있고 성능이 예측 가능하며 복구 절차가 검증되어 있는지가 더 중요하다.

### 5.5. 데이터 계층을 별도 경계로 두는 편이 더 단순하다

stateful workload를 클러스터 안으로 들이지 않으면 아래 설계를 Kubernetes 기준으로 다시 만들 필요가 없다.

- endpoint와 접속 경로 설계
- 백업과 복구 절차 정리
- 모니터링과 알람 정의
- 운영 런북 작성
- 데이터 마이그레이션

현재 판단은 data layer 경계를 처음부터 분리하는 편이 더 단순하다는 것이다.

### 5.6. 기존 운영 경험도 data layer 분리 쪽을 지지한다

현재 문서 체계에는 이미 PostgreSQL과 Redis를 별도 호스트 또는 별도 EC2/Docker 경계로 다룬 운영 기록이 있다.

- [OPS-005 Prod DB 마이그레이션 실행](../operations/OPS-005-db-migration-execution.md)
- [OPS-007 Redis v1→v2 마이그레이션 실행](../operations/OPS-007-redis-migration-execution.md)

즉 이 저장소의 운영 경험 자체가 "데이터 계층은 별도 경계로 다루고, 이관 시 백업/복제/컷오버를 명시적으로 설계한다"는 방향에 더 가깝다.

---

## 6) 선택하지 않은 이유

### 6.1. application과 data를 모두 Kubernetes에 배치

이 방식은 표면적으로 가장 일관돼 보인다.

하지만 현재 조건에서는 다음 이유로 기준선으로 채택하지 않았다.

- Kubernetes가 data layer 운영 난제를 본질적으로 줄이지 못한다.
- storage 계층과 data 엔진, Kubernetes 계층을 함께 운영해야 한다.
- node pool 분리로도 디스크/복구/성능 문제는 그대로 남는다.
- 다시 VM/EC2로 되돌릴 가능성이 있으면 초기 투자 효율이 낮다.

### 6.2. application과 data를 모두 VM/EC2에 배치

이 방식도 충분히 가능한 대안이다.

다만 이 설계 기준에서는 application layer에 대해 Kubernetes가 주는 rollout 표준화, 서비스 디스커버리, 선언형 배포 이점은 여전히 유효하다. 따라서 이번 문서는 Kubernetes 자체를 철회하지 않고, 적용 범위를 명확히 제한하는 쪽을 선택한다.

---

## 7) 결과

설계 기준은 아래와 같이 고정한다.

### 7.1. Kubernetes 대상

- `api`
- `backend`
- `recommend`
- 기타 stateless worker / batch / web workload

### 7.2. 클러스터 밖 유지 대상

- `PostgreSQL`
- `Redis`
- `MongoDB`
- `MQ`
- `Kafka`
- `Qdrant`

### 7.3. 운영 원칙

- data workload는 기본적으로 별도 VM/EC2 또는 이에 준하는 전용 호스트에 둔다.
- Kubernetes 안에서 data workload용 `StatefulSet`, `PVC`, 전용 storage class를 설계 기준으로 두지 않는다.
- application Pod는 외부 data endpoint를 private DNS 이름으로 참조한다.
- data layer의 백업/복구 절차는 각 엔진별 런북과 운영 문서에서 관리한다.

### 7.4. 예외 규칙

예외가 필요해도 기본값은 바꾸지 않는다.

- stateful workload는 별도 DR 없이 기본값을 뒤집지 않는다

---

## 8) 장단점

장점

- data layer 장애 도메인이 Kubernetes control plane과 분리된다.
- 디스크, 복제, 백업, 복구 책임이 더 직접적으로 보인다.
- stateful workload를 다시 VM/EC2로 내리는 이중 마이그레이션 비용을 피할 수 있다.
- 성능과 장애 추적에서 추상화 계층이 줄어든다.

단점

- application과 data를 하나의 오케스트레이션 계층으로 통합하지 못한다.
- 인프라 provisioning과 운영 절차가 이원화된다.
- data layer에 대해 Kubernetes의 선언형 리소스 일관성을 그대로 활용하지 못한다.

---

## 9) 워크로드별 기본 배치 기준

| 워크로드 | 현재 기본 배치 | 메모 |
|------|------|------|
| `PostgreSQL` | VM/EC2 | 백업, PITR, 디스크, 복구 절차가 핵심 |
| `Redis` | VM/EC2 | 현재 기본값은 off-cluster, 단 순수 cache는 예외 검토 가능 |
| `MongoDB` | VM/EC2 | replica set과 백업/복구를 Kubernetes 기준선에 넣지 않음 |
| `MQ` | VM/EC2 | durable queue 운영 시 디스크와 복구 모델이 우선 |
| `Kafka` | VM/EC2 | 디스크, 세그먼트, 복제, 성능 튜닝 부담이 큼 |
| `Qdrant` | VM/EC2 | 인덱스 크기와 디스크 특성이 운영 난이도의 중심 |

---

## 10) 최종 판단 문장

> 본 설계에서 Kubernetes 적용 범위를 application layer로 제한하고 stateful data workload를 클러스터 밖 VM/EC2에 유지하는 이유는, 현재 조건에서 Kubernetes가 배포 편의성은 크게 높여주지만 데이터 운영의 본질적 난제까지 줄여주지는 못하기 때문이다. `StatefulSet`, `PVC`, node pool 분리는 배치 표면을 정리해줄 수는 있어도, 디스크, 복제, 백업, 복구, 성능, 장애 추적의 책임을 없애지 않는다. 따라서 본 설계의 운영 경계는 `app은 Kubernetes`, `data는 클러스터 밖`으로 고정한다.

---

## 11) 참고 문서

- [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md)
- [DR-004 Kubernetes 배포 방식 선정](DR-004-kubernetes-distribution-selection.md)
- [DR-005 컨트롤 플레인 구조 선정](DR-005-kubernetes-control-plane-topology.md)
- [OPS-005 Prod DB 마이그레이션 실행](../operations/OPS-005-db-migration-execution.md)
- [OPS-007 Redis v1→v2 마이그레이션 실행](../operations/OPS-007-redis-migration-execution.md)
