# K8S-004: Calico 심화 - 왜 좋은 대안이지만 현재 1차 선택은 아닌가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | Calico의 운영 모델, 강점, 현재 비선정 이유 정리 |
| 관련 문서 | [K8S-002 CNI 비교 연구](K8S-002-cni-comparison-study.md), [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md) |

---

## 1) 문서 목적

이 문서는 `Calico`를 "복잡해서 탈락한 후보"로 단순화하지 않기 위해 작성했다.

현재 판단은 `Calico`가 나쁜 선택이라는 뜻이 아니라, **지금 단계에서 CNI가 맡을 책임 범위를 너무 빨리 넓히는 선택**이라는 데 가깝다.

---

## 2) Calico를 어떻게 이해했는가

Calico 공식 문서의 component architecture를 보면, Calico는 단일 CNI 바이너리라기보다 여러 구성요소가 결합된 네트워크 플랫폼에 가깝다.

대표 구성요소는 다음과 같다.

- `Felix`
- `BIRD`
- `confd`
- CNI plugin
- Datastore plugin
- IPAM plugin
- `kube-controllers`
- `Typha`

이 구성은 Calico가 단순한 Pod 네트워크를 넘어, **라우팅, 정책, 상태 전파, 운영 확장성**까지 넓게 다룬다는 뜻이다.

특히 라우팅 전파 모델은 `Flannel`과의 차이를 설명할 때 중요하다.

- `Felix`는 각 노드에서 Linux kernel FIB에 route와 ACL을 프로그래밍한다.
- `BIRD`는 커널에 반영된 route를 BGP peer에 배포한다.
- `confd`는 datastore 변경을 감시해 `BIRD` 설정을 갱신하고 reload를 트리거한다.

즉 `Calico`는 단순히 Pod 네트워크를 붙이는 수준이 아니라, **로컬 route 반영과 inter-host route distribution을 함께 운영 모델에 포함하는 구조**다.

---

## 3) Calico의 실제 강점

### 3.1. 정책 모델이 강하다

Calico는 Kubernetes `NetworkPolicy`를 지원할 뿐 아니라, `GlobalNetworkPolicy` 같은 더 넓은 정책 모델도 제공한다.

즉 아래 요구가 커질수록 Calico는 강해진다.

- 네임스페이스 간 세그멘테이션
- east-west 허용 목록 정교화
- 공통 정책을 전역 기준으로 관리

### 3.2. 라우팅 선택지가 넓다

Calico는 overlay만 보는 것이 아니라, 라우팅과 분산 경로 전파까지 운영 모델에 포함할 수 있다.

현재보다 네트워크 경계가 더 중요해지면 이 장점은 커진다.

### 3.3. 운영형 기본안으로 설득력이 높다

Calico는 self-managed Kubernetes에서 오래 검증된 선택지이고, 정책과 운영의 균형이 좋다. 그래서 **실운영 기본안**으로는 매우 강한 후보다.

---

## 4) 그런데 왜 지금 1차 선택은 아닌가

### 4.1. 현재는 정책이 기준선을 결정하는 핵심 요구가 아니다

현재 단계에서는 `default deny + allowlist`를 즉시 기준선으로 둘 필요가 높지 않다.

지금은 보안그룹, 노드 역할 분리, 워크로드 배치 제약으로 1차 격리를 수용하고, 세밀한 네트워크 정책은 후속 확장 항목으로 남기는 편이 적절하다.

즉 Calico의 가장 강한 장점이 **지금 당장 필수 조건은 아니다**.

### 4.2. 운영자가 동시에 이해해야 할 계층이 넓어진다

Calico를 현재 1차 기준선으로 삼으면 운영자가 이해해야 할 범위가 넓어진다.

- 정책 모델
- 라우팅 모델
- BGP route distribution
- 구성요소 간 역할 분리
- 확장 경로와 운영 포인트

현재 단계에서는 이 넓은 책임 범위보다, Pod 네트워크만 먼저 단단히 고정하는 편이 더 낫다고 판단했다.

### 4.3. `Service` 데이터플레인과 정책 엔진이 같이 묶이기 쉽다

Calico는 eBPF 데이터플레인까지 확장할 수 있어 강력하지만, 현재 단계에서는 오히려 CNI와 `Service` 데이터플레인, 정책 축이 함께 엮일 가능성이 커진다.

우리는 지금 이 축들을 분리해서 설계하려 한다.

---

## 5) Calico가 더 잘 맞는 시점

아래 조건이 생기면 `Calico`는 가장 먼저 재평가할 후보다.

1. `NetworkPolicy`를 실제 기준선으로 올릴 때
2. 네임스페이스 또는 계층 단위 세그멘테이션을 강하게 가져갈 때
3. 데이터 계층을 클러스터 내부로 들이며 east-west 경계를 강화할 때
4. 보안 요구가 인프라 레벨 격리만으로 부족해질 때

즉 `Calico`는 현재 비선정 후보이지만, **후속 단계의 1순위 대안**이다.

---

## 6) 이번 검토에서 얻은 결론

이번 비교에서 `Calico`는 분명한 강점을 가진 좋은 대안이었다.

다만 현재 단계에서는 다음 이유로 1차 기준선에서 제외했다.

- 네트워크 정책과 세그멘테이션이 아직 핵심 요구가 아니다.
- `Felix -> BIRD -> confd`로 이어지는 라우팅 전파 모델까지 함께 들여오게 된다.
- 운영 책임 범위를 너무 빨리 넓히게 된다.
- CNI와 다른 네트워크 축을 분리하는 현재 설계 방향과 약간 어긋난다.

즉 `Calico`는 "과해서 탈락"이 아니라, **지금보다 한 단계 뒤에 더 잘 맞는 선택**으로 정리하는 편이 정확하다.

---

## 7) 참고 자료

- Calico Component Architecture: https://docs.tigera.io/calico/latest/reference/architecture/overview
- Calico GlobalNetworkPolicy: https://docs.tigera.io/calico/latest/reference/resources/globalnetworkpolicy
- Calico eBPF dataplane: https://docs.tigera.io/calico/latest/operations/ebpf/install
- Kubernetes NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/network-policies/
