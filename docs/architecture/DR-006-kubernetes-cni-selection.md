# DR-006: Kubernetes CNI로 Flannel 채택

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md), [K8S-002 CNI 비교 연구](../kubernetes/K8S-002-cni-comparison-study.md), [K8S-003 Flannel 심화](../kubernetes/K8S-003-flannel-deep-dive.md), [K8S-004 Calico 심화](../kubernetes/K8S-004-calico-deep-dive.md), [K8S-005 Cilium 심화](../kubernetes/K8S-005-cilium-deep-dive.md) |
| 주요 목표 | 현재 단계의 Kubernetes Pod 네트워크 기준선과 CNI 선택 근거 기록 |

---

## 1) 결정

본 설계에서는 현재 단계의 Kubernetes CNI로 `Flannel`을 채택한다.

이번 결정은 "가장 쉬운 CNI"를 고르는 것이 아니라, 현재 단계에서 CNI가 책임져야 할 범위를 **Pod 네트워크 안정화**에 명확히 한정하고, `Service` 데이터플레인, 정책 엔진, 고급 observability는 후속 설계 축으로 분리하기 위한 결정이다.

초기 기준선은 아래와 같이 둔다.

- CNI: `Flannel`
- Pod 네트워크 방식: overlay(VXLAN) 기반
- Service 데이터플레인: Kubernetes `Service + kube-proxy`
- 외부 진입: `Gateway API + Traefik`

---

## 2) 배경

현재 클러스터 설계 전제는 다음과 같다.

- 운영 인원은 소수다.
- 지금은 application layer 기준선을 먼저 고정하는 단계다.
- 외부 진입 제어는 Gateway 계층이 담당한다.
- 내부 서비스 분산은 Kubernetes `Service`와 `kube-proxy` 데이터플레인이 담당한다.

Kubernetes 공식 문서는 CNI 플러그인이 Kubernetes 네트워크 모델을 구현해야 한다고 설명한다. 또한 Kubernetes `Service`의 virtual IP 메커니즘은 `kube-proxy`가 `Service`와 `EndpointSlice`를 watch해 구현한다고 안내한다.

즉 이번 이슈의 핵심은 "네트워크에서 가장 많은 기능을 미리 가져오는가"가 아니라, **현재 단계에서 CNI를 어디까지의 책임으로 정의할 것인가**에 있다.

---

## 3) 이번 비교에서 답한 질문

### 3.1. CNI가 정확히 어디까지 담당하는가

현재 설계에서는 다음 축을 분리해서 본다.

- CNI: Pod IP와 Pod-to-Pod 연결성
- `kube-proxy`: `Service` virtual IP와 endpoint 분산
- Gateway 계층: 외부 요청의 L7 진입 제어

따라서 CNI 선택이 곧 `Service` 데이터플레인과 외부 진입 구조를 모두 잠그는 선택이 되어서는 안 된다.

### 3.2. 현재 `NetworkPolicy`가 핵심 요구인가

현재 단계에서는 그렇지 않다고 판단했다.

현재 1단계 격리는 아래 수단으로 우선 수용한다.

- 클라우드 보안그룹
- 노드 역할 분리
- 특정 워크로드의 배치 제약

이는 `NetworkPolicy`를 영구적으로 배제한다는 뜻이 아니라, **현재 기준선에서 필수 요구로 올리지 않는다는 뜻**이다.

### 3.3. 지금 eBPF 기반 통합 모델이 필요한가

현재 규모와 운영 인력을 고려하면, eBPF 기반 통합 데이터플레인의 장점보다 개념 수와 운영 부담 증가가 더 먼저 체감될 가능성이 높다.

---

## 4) 선택 근거

### 4.1. 현재 문제는 고급 네트워크 제어보다 기본 Pod 네트워크 안정화다

지금 단계에서 가장 중요한 것은 Pod 간 연결성을 단순하고 예측 가능하게 확보하는 것이다.

Flannel 공식 README는 Flannel을 Kubernetes용 단순한 L3 네트워크 패브릭으로 설명한다. 각 노드의 `flanneld`가 서브넷 lease를 관리하고, Kubernetes API 또는 etcd를 backing store로 사용하며, VXLAN 등으로 노드 간 Pod 트래픽을 전달한다.

현재 단계의 요구는 이 수준에 정확히 맞는다.

### 4.2. CNI와 `Service` 데이터플레인을 분리해서 설계할 수 있다

Flannel을 선택해도 `Service` 데이터플레인 전략은 별도 축으로 남는다.

- Pod 네트워크: `Flannel`
- Service 데이터플레인: `kube-proxy`
- 외부 진입: Gateway 계층

이 분리는 문서 구조와 운영 책임 구분을 모두 단순하게 만든다.

### 4.3. 현재는 `NetworkPolicy`가 기준선을 좌우하는 핵심 요구가 아니다

현재 규모에서는 east-west 트래픽 구조가 복잡하지 않고, 보안 요구 역시 보안그룹, 노드 역할 분리, 제한된 워크로드 배치로 1차 수용 가능하다고 판단했다.

따라서 지금 단계에서 CNI 선택의 핵심 기준을 세밀한 정책 엔진이 아니라, **기본 네트워크 안정성과 운영 단순성**에 두는 것이 맞다.

### 4.4. 운영자가 설명하고 디버깅하기 쉬운 모델이다

Flannel은 비교적 좁은 책임 범위를 가진다. 그만큼 장애 분석 시에도 문제 공간을 좁히기 쉽다.

현재 단계에서 이 점은 기능 확장성보다 더 큰 장점이다.

### 4.5. 이번 선택은 "학습용"이 아니라 "책임 범위 축소"다

Flannel을 선택한 이유는 기능을 포기해서가 아니라, 현재 단계에서 네트워크 계층의 책임 범위를 명확히 줄이기 위해서다.

즉 이번 선택은 **현재 운영 단계와 팀 규모에 맞춘 설계적 축소**다.

---

## 5) 선택하지 않은 이유

### 5.1. Calico

`Calico`는 매우 좋은 대안이며, 후속 재검토 1순위 후보다.

다만 `Calico`는 `Felix`, `BIRD`, `confd`, `Typha`, `GlobalNetworkPolicy` 등으로 대표되는 더 넓은 정책 및 운영 모델을 함께 가져온다.

공식 아키텍처 기준으로 `Felix`는 각 노드의 Linux kernel FIB에 route와 ACL을 프로그래밍하고, `BIRD`는 그 route를 BGP peer에 배포하며, `confd`는 datastore 변경을 감시해 `BIRD` 설정을 갱신한다.

즉 `Calico` 선택은 단순한 CNI 선택이 아니라, 라우팅 전파 모델과 정책 모델까지 함께 채택하는 결정에 가깝다. 이는 `NetworkPolicy`와 세그멘테이션이 현재 핵심 요구가 아닐 때는, 네트워크 책임 범위를 너무 빨리 넓히는 선택이 된다.

### 5.2. Cilium

`Cilium`은 eBPF 기반 통합 네트워킹, `kube-proxy replacement`, `Hubble` observability까지 포괄하는 강력한 대안이다.

그러나 현재 단계에서는 CNI 선택이 곧 `Service` 데이터플레인, observability, 커널/eBPF 운영 모델까지 함께 잠그는 선택이 된다. 지금은 이 통합성이 장점보다 부담으로 작용할 가능성이 더 크다.

---

## 6) 결과

현재 단계의 네트워크 계층 역할은 다음과 같이 분리한다.

- CNI: `Flannel`
- Pod 네트워크 방식: overlay(VXLAN)
- Service 데이터플레인: Kubernetes `Service + kube-proxy`
- 외부 진입: `Gateway API + Traefik`
- 정책/고급 observability: 후속 확장 항목으로 보류

이 구조에서 CNI는 Pod 연결성에 집중하고, 나머지 축은 후속 DR과 운영 설계로 분리 관리한다.

---

## 7) 장단점

장점

- CNI의 책임 범위를 Pod 네트워크에 명확히 한정할 수 있다.
- 운영 모델과 장애 원인 범위가 비교적 단순하다.
- `kubeadm` 기반 업스트림 Kubernetes 기준선과 잘 맞는다.
- `Service` 데이터플레인 및 Gateway 계층과의 책임 분리가 선명하다.

단점

- `NetworkPolicy` 중심 기준선을 바로 가져가지 않는다.
- `Calico` 수준의 세그멘테이션과 정책 모델은 후속 과제로 남는다.
- `Cilium` 수준의 eBPF 통합 데이터플레인과 observability는 현재 기준선에 포함되지 않는다.

---

## 8) 후속 검토 항목

1. `kube-proxy`의 `iptables` / `nftables` / eBPF replacement 비교 DR 작성
2. east-west 보안 요구가 증가할 경우 `Calico` 재검토
3. 데이터 계층을 클러스터 내부로 더 많이 옮길 경우 `NetworkPolicy` 기준선 재검토
4. 고급 네트워크 observability와 `kube-proxy replacement`가 필요해질 경우 `Cilium` 재평가

---

## 9) 최종 판단 문장

> 현재 단계에서 CNI의 핵심 요구는 고급 정책 엔진이나 eBPF 기반 통합 데이터플레인이 아니라, Pod 네트워크를 단순하고 안정적으로 구성하는 것이다. `Flannel`은 Kubernetes용 단순한 L3 네트워크 패브릭으로서 현재 팀 규모와 운영 단계에 가장 맞는 책임 범위를 제공한다. 따라서 초기 CNI는 `Flannel`로 표준화하되, 정책, `Service` 데이터플레인, 고급 관측 기능은 후속 설계 축으로 분리해 단계적으로 확장한다.

---

## 10) 참고 자료

- Kubernetes Network Plugins: https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- Kubernetes Services, Load Balancing, and Networking: https://kubernetes.io/docs/concepts/services-networking/
- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
- Kubernetes NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Flannel README: https://github.com/flannel-io/flannel
- Calico Component Architecture: https://docs.tigera.io/calico/latest/reference/architecture/overview
- Calico GlobalNetworkPolicy: https://docs.tigera.io/calico/latest/reference/resources/globalnetworkpolicy
- Cilium System Requirements: https://docs.cilium.io/en/stable/operations/system_requirements.html
- Cilium kube-proxy replacement: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
