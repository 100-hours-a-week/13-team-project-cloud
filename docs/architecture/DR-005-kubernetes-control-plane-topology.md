# DR-005: 컨트롤 플레인 구조 선정 - Single vs HA

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md), [DR-004 Kubernetes 배포 방식 선정](DR-004-kubernetes-distribution-selection.md) |
| 주요 목표 | 초기 Kubernetes 컨트롤 플레인 구조 선정 및 장애 허용 범위, 후속 운영 과제 기준선 확정 |

---

## 1) 결정

본 설계에서는 초기 Kubernetes 컨트롤 플레인 구조로 `single control plane`을 채택한다.

이번 결정은 고가용성이 중요하지 않다는 뜻이 아니다. 현재 단계에서는 모든 계층을 곧바로 Kubernetes에 완전히 종속시키기보다, 운영 가능한 기준선을 먼저 확정하고 control plane 구조를 과도하게 복잡하게 만들지 않는 편이 더 적절하다고 판단했다.

따라서 초기에는 `single control plane`을 기준선으로 두고, control plane 백업과 복구, HA 전환 기준은 후속 운영 과제로 관리한다.

---

## 2) 배경

현재 클러스터 설계 전제는 다음과 같다.

- 운영 인원은 소수다.
- 지금은 application layer부터 먼저 클러스터화하는 단계다.
- 아직 모든 계층이 Kubernetes control plane 가용성에 직접적으로 강하게 종속되는 단계는 아니다.
- 지금 필요한 것은 완성형 대규모 구조보다, 설명 가능하고 운영 가능한 기준선을 먼저 고정하는 것이다.

`kubeadm` 공식 문서는 단일 control plane과 HA 구성을 모두 지원한다. 다만 HA 구성은 다수 control plane node, control plane endpoint용 load balancer, 그리고 `stacked etcd` 또는 `external etcd` 운영을 함께 요구한다.

즉 이번 결정은 "HA가 기술적으로 더 좋아 보이느냐"가 아니라, **현재 단계에서 어떤 장애를 수용하고 그 대신 무엇을 단순하게 가져갈 것인가**에 대한 판단이다.

---

## 3) 선택 기준

이번 선택은 아래 기준으로 평가한다.

### 3.1. 현재 단계의 실제 의존도와 맞는가

아직 모든 계층이 Kubernetes control plane 고가용성에 즉시 종속되는 구조는 아니다. 따라서 현재 워크로드 단계와 control plane 구조가 균형을 이루는지 봐야 한다.

### 3.2. 운영 복잡도 대비 실익이 충분한가

HA는 분명 장점이 있지만, control plane node 증가, endpoint용 load balancer, etcd quorum 운영, 업그레이드 절차 복잡도까지 함께 평가해야 한다.

### 3.3. 장애 영향 범위를 설명할 수 있는가

지금 단계에서는 절대 죽지 않는 구조보다, **control plane 장애가 무엇을 멈추고 무엇을 유지하는지 설명 가능한 구조**가 더 중요하다.

### 3.4. 이후 확장 경로가 선명한가

현재 `single control plane`을 선택하더라도, 이후 `HA`로 넘어가는 공식 경로가 분명해야 한다.

---

## 4) 고려한 대안

검토 대상은 다음 두 가지였다.

- `single control plane`
- `HA control plane`

여기서 `HA control plane`은 다수 control plane node와 control plane endpoint용 load balancer, 그리고 `stacked etcd` 또는 `external etcd` 기반 구성을 포함하는 형태를 의미한다.

---

## 5) 선택 근거

### 5.1. 현재 단계에서는 control plane 기준선을 먼저 단순하게 고정하는 편이 맞다

현재는 application layer부터 먼저 클러스터화하는 단계다. 아직 모든 계층이 Kubernetes control plane 가용성에 직접 종속되지는 않는다.

따라서 지금 필요한 것은 처음부터 control plane을 다중 노드로 크게 가져가는 것보다, `kubeadm` 기준선 위에서 운영 절차와 장애 모델을 먼저 명확히 만드는 것이다.

### 5.2. `single control plane`은 장애 모델을 설명하기 쉽다

`single control plane`을 선택하면 장애 모델이 비교적 명확하다.

- control plane node 장애
- API server, scheduler, controller-manager, etcd 장애
- control plane 기능 정지 시 영향 범위

현재 단계에서는 이 명확성이 장점이다. 중요한 것은 control plane이 절대 죽지 않게 만드는 것보다, **죽었을 때 어떤 기능이 멈추는지 설명할 수 있어야 한다는 점**이다.

### 5.3. control plane 장애가 곧바로 전체 데이터 경로 소멸을 의미하는 것은 아니다

일반적으로 control plane 장애가 발생해도 이미 실행 중인 워크로드와 기존 data plane은 즉시 모두 사라지지 않는다.

예를 들어 이미 떠 있는 Pod, 기존 `kube-proxy` 규칙, CNI가 반영한 기존 네트워크 경로는 당장 유지될 수 있다. 반면 새로운 스케줄링, 새로운 rollout, 상태 변경 반영은 중단된다.

즉 현재 단계에서는 "control plane 장애 = 즉시 전체 서비스 소멸"로 단순화하기보다, **기존 데이터 경로 유지와 신규 상태 반영 중단을 분리해서 보는 것이 더 정확하다.**

### 5.4. HA는 장점이 분명하지만, 지금은 그 비용이 먼저 크다

`HA control plane`은 다음 장점을 준다.

- control plane node 단일 장애에 대한 내성
- API endpoint 가용성 향상
- maintenance 시 중단 가능성 감소

하지만 동시에 다음도 함께 들어온다.

- control plane endpoint용 load balancer
- 다수 control plane node 운영
- etcd quorum 관리
- 인증서, 업그레이드, 복구 절차 복잡도 증가

현재 운영 인력과 현재 워크로드 단계에서는, 이 장점보다 운영 복잡도 증가가 먼저 체감될 가능성이 높다.

### 5.5. `kubeadm` 기준선 위에서 이후 HA 확장이 가능하다

`kubeadm`은 단일 control plane과 HA 토폴로지를 모두 공식 문서로 제공한다. 따라서 지금 `single control plane`을 기준선으로 두는 것이 나중 HA로 가는 길을 막는 선택은 아니다.

즉 현재는 single로 시작하고, 실제 요구 증가 시 HA로 넘어가는 전략이 가능하다.

---

## 6) 선택하지 않은 이유

### 6.1. HA control plane

`HA control plane`은 장기적으로 충분히 유효한 방향이다.

다만 현재 단계에서는 다음 이유로 초기 기준선으로 채택하지 않았다.

- 아직 모든 계층이 control plane 고가용성에 즉시 종속되는 구조가 아니다.
- control plane node, load balancer, etcd quorum 운영까지 함께 가져오면 초기 운영 개념 수가 크게 늘어난다.
- 현재는 무중단 최적화보다, 장애 영향 범위를 명확히 문서화하는 편이 더 중요하다.

즉 `HA`는 불필요한 선택이 아니라, **현재 단계보다 다음 단계에 더 적합한 선택**이다.

---

## 7) 결과

초기 컨트롤 플레인 기준선은 다음과 같이 고정한다.

- Control plane topology: `single control plane`
- Worker node: 별도 worker 운영
- Control plane workload scheduling: 비활성화 유지
- HA 전환 여부: 후속 검토

즉 현재 설계에서는 control plane을 처음부터 크게 구성하지 않고, **단일 기준선 + 후속 운영 과제 관리**로 시작한다.

---

## 8) 장단점

장점

- 초기 control plane 구조가 단순하다.
- 장애 영향 범위를 설명하기 쉽다.
- 현재 팀 규모에 더 적합하다.
- `kubeadm` 기준선과 자연스럽게 연결된다.

단점

- control plane node 단일 장애에 취약하다.
- maintenance나 node failure 시 control plane API availability가 떨어질 수 있다.
- 장기적으로 워크로드 의존도가 커지면 HA 전환이 필요하다.

---

## 9) 현재 단계의 최소 운영 요구사항

`single control plane` 선택은 "아무 대비 없이 단일 장애점을 받아들인다"는 뜻이 아니다.

다만 현재 시점에서 아래 항목은 최소 운영 요구사항으로 본다.

1. etcd 백업 방식 정의
2. control plane 재생성 또는 복구 절차 문서화
3. control plane 핵심 컴포넌트 헬스 모니터링

반면 아래 항목은 아직 완료된 상태를 전제하지 않고, 후속 운영 과제로 둔다.

- restore 검증 주기
- 정기 복구 훈련
- HA 전환 시점과 조건

---

## 10) 후속 검토 항목

1. 어떤 조건에서 HA 전환을 시작할지 명문화
2. control plane endpoint용 load balancer 필요 시점 정의
3. `stacked etcd` vs `external etcd` 비교
4. etcd backup / restore 절차의 주기적 검증

---

## 11) 최종 판단 문장

> 본 설계에서 초기 컨트롤 플레인 구조를 `single control plane`으로 선택한 이유는 고가용성을 가볍게 보기 때문이 아니다. 현재 단계에서는 application layer 기준선을 먼저 고정하고, control plane 운영 복잡도를 과도하게 늘리지 않는 편이 더 적절하다. `HA control plane`은 분명한 장점이 있지만, 다수 control plane node, endpoint load balancer, etcd quorum 운영까지 함께 가져오므로 현재 팀 규모와 운영 단계에서는 비용이 더 크다. 따라서 초기에는 `single control plane`을 기준선으로 두고, 필요한 최소 운영 요구사항을 충족하면서 실제 의존도와 운영 요구가 커질 때 HA로 확장한다.

---

## 12) 참고 자료

- Creating Highly Available Clusters with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
- Options for Highly Available Topology: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/
- Set up a High Availability etcd Cluster with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm
