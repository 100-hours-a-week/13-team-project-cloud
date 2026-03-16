# K8S-003: Flannel 심화 - 왜 현재 단계의 1차 CNI 선택지인가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | Flannel의 운영 모델, 장점, 한계, 현재 적합성 정리 |
| 관련 문서 | [K8S-002 CNI 비교 연구](K8S-002-cni-comparison-study.md), [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md) |

---

## 1) 문서 목적

이 문서는 `Flannel`이 "학습용이라서 쉬운 선택"이 아니라, **현재 단계에서 CNI의 책임 범위를 Pod 네트워크에 집중시키기 위한 의도적 선택지**라는 점을 설명하기 위해 작성했다.

---

## 2) Flannel이 실제로 하는 일

Flannel 공식 README는 Flannel을 Kubernetes용 **단순한 L3 네트워크 패브릭**으로 설명한다.

핵심 동작은 다음과 같다.

- 각 노드에 작은 에이전트인 `flanneld`를 배치한다.
- 노드별 Pod 서브넷을 할당한다.
- Kubernetes API 또는 etcd를 backing store로 사용한다.
- VXLAN 등 백엔드 메커니즘으로 노드 간 Pod 트래픽을 전달한다.

Flannel은 클러스터 전체 네트워크를 고도화하는 도구라기보다, **노드 간 Pod 연결성을 단순하게 성립시키는 데 집중한 도구**에 가깝다.

---

## 3) 운영 모델이 왜 단순한가

Flannel의 장점은 기능 목록보다 **운영 모델의 좁은 책임 범위**에 있다.

### 3.1. Pod 네트워크에 집중한다

Flannel은 주로 다음 질문에 답한다.

- Pod가 어느 서브넷을 쓸 것인가
- 다른 노드의 Pod로 패킷을 어떻게 보낼 것인가

반대로 다음 축은 직접 넓게 가져가지 않는다.

- `Service` virtual IP 구현
- 고급 정책 엔진
- eBPF 기반 통합 데이터플레인
- 고급 observability

### 3.2. Kubernetes API 기반 운영이 가능하다

Flannel은 `kube subnet manager` 방식을 지원한다. 이 방식은 Kubernetes API를 backing store로 사용하므로, 별도 etcd를 추가로 운영하지 않아도 된다.

현재처럼 `kubeadm` 기반 업스트림 Kubernetes를 기준선으로 두는 구조에서는 이 단순성이 중요하다.

### 3.3. 현재 기준선은 overlay 중심으로 잡기 쉽다

현재 단계에서는 라우팅 최적화보다 배포 단순성과 예측 가능성이 더 중요하다.

따라서 Flannel은 초기 기준선으로 다음 구조를 설명하기 쉽다.

- Pod 네트워크: `Flannel`
- 백엔드: overlay(VXLAN) 기반
- `Service` 데이터플레인: `kube-proxy`

---

## 4) 왜 현재 상황에 잘 맞는가

### 4.1. 지금은 "네트워크 고도화"보다 "네트워크 기준선 확정" 단계다

현재 설계의 우선순위는 아래와 같다.

- 외부 진입 구조 정리
- 내부 `Service` 구조 정리
- Pod 네트워크 안정화

즉 지금은 CNI에 고급 정책, 서비스 프록시, observability까지 한 번에 요구할 단계가 아니다.

### 4.2. 계층 분리가 잘 된다

Flannel을 선택하면 현재 문서 구조도 선명해진다.

- CNI는 Pod 네트워크만 담당
- Service 분산은 `kube-proxy`가 담당
- 외부 진입은 Gateway 계층이 담당

이 분리가 되면 "어느 문제가 어느 계층 책임인지"를 문서와 운영에서 동시에 설명하기 쉬워진다.

### 4.3. 문제 범위를 좁히기 쉽다

초기 운영에서는 장애의 원인을 빨리 줄여가는 것이 중요하다.

Flannel 기반에서는 주로 아래 문제 공간으로 수렴한다.

- 노드 간 reachability
- Pod CIDR / 서브넷 할당
- MTU
- VXLAN 백엔드 문제

이는 정책, BGP, eBPF, `kube-proxy replacement`까지 함께 들어오는 구조보다 훨씬 좁다.

---

## 5) Flannel이 하지 않는 일

Flannel을 선택한다는 것은 아래 기능을 현재 기준선에 포함하지 않는다는 뜻이기도 하다.

### 5.1. `NetworkPolicy`를 핵심 기능으로 삼지 않는다

Flannel 공식 README도 Flannel은 네트워킹에 집중하며, 네트워크 정책은 `Calico` 같은 다른 프로젝트와 함께 사용할 수 있다고 설명한다.

즉 Flannel은 "정책까지 포함한 CNI 플랫폼"이 아니라, **연결성 중심의 CNI**다.

### 5.2. `Service` 데이터플레인을 대체하지 않는다

Flannel을 선택한다고 해서 `kube-proxy` 전략까지 동시에 고정되는 것은 아니다.

현재 설계에서는 다음을 분리한다.

- Pod 네트워크: `Flannel`
- Service virtual IP: `kube-proxy`
- 외부 진입: Gateway 계층

### 5.3. eBPF observability를 바로 가져오지 않는다

Flannel은 `Cilium` 같은 통합 observability 스택을 제공하지 않는다. 대신 현재 단계에서는 그 공백보다 운영 단순성이 더 중요하다고 본다.

---

## 6) 왜 이것이 "학습용"이 아닌가

Flannel을 "학습용으로만 적합하다"라고 쓰면 현재 판단이 약해진다. 실제 판단은 다르다.

이번 선택은 다음 의미에 가깝다.

1. 지금 CNI가 맡아야 할 책임은 Pod 네트워크 안정화다.
2. `Service` 데이터플레인과 정책 엔진은 별도 축으로 남긴다.
3. 현재 규모에서 네트워크 복잡도를 의도적으로 줄인다.

즉 Flannel은 **기능이 약해서 선택한 도구가 아니라, 책임 범위가 명확해서 선택한 도구**다.

---

## 7) 현재 기준선에서 감수하는 트레이드오프

Flannel 선택은 다음 장점을 준다.

- 운영 모델이 단순하다.
- 설계 문서와 운영 책임 분리가 선명하다.
- `kubeadm + containerd` 기준선과 잘 맞는다.
- 장애 원인 범위를 좁히기 쉽다.

동시에 다음 한계를 받아들인다.

- `NetworkPolicy` 중심 설계를 바로 가져가지 않는다.
- `Calico` 수준의 정책/세그멘테이션 기능은 후속 과제로 남는다.
- `Cilium` 수준의 eBPF 통합 데이터플레인과 observability는 현재 기준선에 포함되지 않는다.

---

## 8) 언제 재검토해야 하는가

아래 조건이 생기면 `Flannel` 기준선은 재검토 대상이 된다.

1. east-west 보안 정책을 네트워크 레벨에서 강하게 집행해야 할 때
2. 데이터 계층을 클러스터 내부로 더 많이 들일 때
3. `default deny + allowlist`를 실제 기준선으로 올릴 때
4. `kube-proxy replacement`나 고급 observability 요구가 커질 때

이 경우 가장 먼저 재검토할 후보는 `Calico`, 그 다음은 `Cilium`이다.

---

## 9) 최종 정리

현재 단계에서 `Flannel`의 강점은 "가볍다"가 아니라 **지금 필요한 네트워크 책임 범위를 정확히 잘라낸다**는 데 있다.

따라서 `Flannel`은 임시 학습용 선택지가 아니라, 현재 1단계 Kubernetes 설계에서 **Pod 네트워크 기준선을 안정적으로 고정하기 위한 운영 선택**으로 본다.

---

## 10) 참고 자료

- Flannel README: https://github.com/flannel-io/flannel
- Flannel CNI Plugin: https://github.com/flannel-io/cni-plugin
- Kubernetes Network Plugins: https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
