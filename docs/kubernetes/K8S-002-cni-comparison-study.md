# K8S-002: Kubernetes CNI 비교 연구 - Flannel vs Calico vs Cilium

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | CNI 후보 비교 연구 및 최종 선택 근거의 supporting document |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](K8S-001-final-design.md), [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md), [K8S-003 Flannel 심화](K8S-003-flannel-deep-dive.md), [K8S-004 Calico 심화](K8S-004-calico-deep-dive.md), [K8S-005 Cilium 심화](K8S-005-cilium-deep-dive.md) |

---

## 1) 문서 목적

이 문서는 `Flannel`, `Calico`, `Cilium`을 단순 기능표가 아니라 **현재 팀이 실제로 책임질 네트워크 범위**를 기준으로 비교한 연구 문서다.

이번 비교의 목적은 "가장 강력한 CNI"를 고르는 것이 아니라, 아래 질문에 답하는 것이다.

1. 지금 CNI가 어디까지 책임져야 하는가
2. 지금 단계에서 `NetworkPolicy`가 핵심 요구사항인가
3. `Service` 데이터플레인과 CNI를 같이 잠글 것인가
4. 소수 운영 인원이 설명하고 디버깅하기 쉬운 네트워크 모델은 무엇인가

---

## 2) 현재 설계 전제

현재 클러스터 설계 전제는 다음과 같다.

- 운영 인원은 소수이며, 초기 운영 복잡도를 낮추는 것이 중요하다.
- 지금 당장 모든 계층을 클러스터 안으로 옮기는 것이 아니라 application layer 기준선을 먼저 고정한다.
- 외부 진입 제어는 `Gateway API + Gateway Controller` 계층이 담당한다.
- 내부 서비스 분산은 Kubernetes `Service`와 `kube-proxy` 데이터플레인이 담당한다.
- 따라서 CNI에는 우선 **Pod 네트워크를 단순하고 예측 가능하게 구성하는 역할**이 더 중요하다.

즉 이번 비교는 "누가 네트워크를 더 많이 해주느냐"보다, **현재 단계에서 어떤 계층까지 함께 들여올지**에 대한 판단이다.

---

## 3) 이번 비교에서 실제로 본 질문

### 3.1. CNI가 정확히 무엇을 담당하는가

이번 비교에서는 먼저 네트워크 축을 분리했다.

- CNI: Pod IP 할당과 Pod-to-Pod 연결성
- `kube-proxy` 또는 대체 구현: Service virtual IP와 endpoint 분산
- Gateway 계층: 외부 요청을 어떤 `Service`로 보낼지 결정

이 분리가 선명해야 CNI 선택이 과도하게 무거워지지 않는다.

### 3.2. 지금 우리에게 `NetworkPolicy`가 핵심 요구인가

현재 규모에서는 east-west 트래픽 구조가 복잡하지 않고, 현재 보안 요구 역시 다음 수단으로 1차 수용 가능하다고 판단했다.

- 클라우드 보안그룹
- 노드 역할 분리
- 특정 워크로드의 제한 배치

이는 `NetworkPolicy`가 불필요하다는 뜻이 아니라, **현재 1단계 기준선에서 필수 요구는 아니라는 뜻**이다.

### 3.3. `Service` 데이터플레인까지 같이 가져갈 것인가

`Cilium`과 일부 `Calico` 시나리오는 CNI 선택이 곧 `kube-proxy` 대체, 정책 엔진, observability까지 함께 끌고 오는 선택이 된다.

현재 단계에서는 CNI와 `Service` 데이터플레인을 분리해서 보는 편이 더 적절하다고 판단했다.

### 3.4. 지금 eBPF 통합 모델의 실익이 큰가

eBPF 기반 통합 모델은 분명 강력하지만, 현재 규모에서 그 이점이 즉시 병목 해소나 필수 기능으로 이어질 가능성은 높지 않다.

반면 운영 개념, 장애 분석 포인트, 커널 레벨 이해 요구는 바로 증가한다.

---

## 4) 비교 축

이번 비교에서는 아래 축을 기준으로 각 후보를 봤다.

1. Pod 네트워크 구성이 얼마나 단순한가
2. `Service` 데이터플레인과 분리해서 설계할 수 있는가
3. `NetworkPolicy`와 보안 기능이 현재 요구 수준과 맞는가
4. 운영자가 내부 동작을 설명하고 디버깅하기 쉬운가
5. 지금 당장 필요하지 않은 기능까지 함께 잠그는 선택은 아닌가

---

## 5) 후보별 핵심 성격

| 후보 | 현재 관찰한 핵심 성격 | 현재 단계 평가 |
|------|----------------------|----------------|
| `Flannel` | Pod 네트워크에 집중한 단순한 L3 패브릭 | 현재 1차 선택지 |
| `Calico` | 정책, 라우팅, 운영 기능까지 넓게 포괄하는 균형형 | 후속 재검토 1순위 |
| `Cilium` | eBPF 기반 통합 네트워크/보안/관측 스택 | 장기 고도화 후보 |

---

## 6) Flannel을 어떻게 봤는가

`Flannel`은 현재 요구를 다음 방식으로 만족한다.

- Pod 네트워크를 단순하게 붙인다.
- `flanneld` 중심의 비교적 단순한 운영 모델을 가진다.
- Kubernetes API 기반 `kube subnet manager`를 사용할 수 있다.
- CNI와 `Service` 데이터플레인을 분리해서 설계하기 쉽다.

중요한 점은 `Flannel`을 "학습용"으로 본 것이 아니라, **CNI의 책임 범위를 Pod 네트워크 안정화에 의도적으로 한정하는 선택지**로 봤다는 점이다.

상세 내용은 [K8S-003 Flannel 심화](K8S-003-flannel-deep-dive.md)에서 다룬다.

---

## 7) Calico를 어떻게 봤는가

`Calico`는 단순 CNI를 넘어 정책, 라우팅, 운영 구조까지 포괄하는 실무형 플랫폼에 가깝다.

- `Felix`, `BIRD`, `confd`, `Typha`, `kube-controllers` 등 운영 구성요소가 분명하다.
- `NetworkPolicy`와 `GlobalNetworkPolicy` 같은 정책 모델이 강하다.
- overlay와 라우팅 고도화를 함께 가져갈 수 있다.
- eBPF 데이터플레인으로의 확장 경로도 있다.

즉 `Calico`는 좋은 대안이지만, 현재 단계에서는 **네트워크 책임 범위를 너무 빨리 넓히는 선택**으로 평가했다.

상세 내용은 [K8S-004 Calico 심화](K8S-004-calico-deep-dive.md)에서 다룬다.

---

## 8) Cilium을 어떻게 봤는가

`Cilium`은 CNI라기보다 eBPF 중심의 통합 네트워킹 스택에 가깝다.

- 각 노드의 `cilium-agent`가 커널에 eBPF 프로그램을 설치한다.
- `kube-proxy replacement`를 지원한다.
- `Hubble`을 통해 네트워크 observability를 강화할 수 있다.

즉 `Cilium`은 장기적으로 매우 매력적이지만, 현재 단계에서는 **Pod 네트워크, Service 데이터플레인, observability를 한 번에 같이 잠그는 선택**이 된다.

상세 내용은 [K8S-005 Cilium 심화](K8S-005-cilium-deep-dive.md)에서 다룬다.

---

## 9) 왜 현재 1차 선택이 Flannel인가

현재 비교 결과가 `Flannel`로 기운 이유는 네 가지다.

### 9.1. 지금 문제는 고급 네트워크 제어보다 기본 Pod 네트워크 안정화다

현재 단계의 핵심은 복잡한 네트워크 정책 엔진이 아니라, **기본 연결성과 구조 단순성**이다.

### 9.2. CNI와 `Service` 데이터플레인을 분리해서 볼 수 있다

현재는 다음 역할 분리가 더 중요하다.

- CNI: `Flannel`
- Service 데이터플레인: Kubernetes `Service + kube-proxy`
- 외부 진입: `Gateway API + Traefik`

이 구조가 문서화와 운영 책임 구분을 가장 단순하게 만든다.

### 9.3. 현재는 `NetworkPolicy`가 기준선을 결정하는 핵심 요구가 아니다

세밀한 east-west 정책보다, 보안그룹과 노드 역할 분리, 워크로드 배치 제약으로 1차 격리를 수용하는 편이 현재 단계와 더 잘 맞는다.

### 9.4. 운영자가 설명하고 디버깅하기 쉬운 모델이다

초기 운영에서 중요한 것은 기능 최대화보다 장애 원인 범위를 좁히는 것이다. `Flannel`은 이 점에서 가장 단순한 문제 공간을 제공한다.

---

## 10) 이번 비교의 결론

이번 비교의 결론은 아래와 같다.

- `Flannel`: 현재 1단계 기준선에 가장 적합하다.
- `Calico`: 네트워크 정책과 세그멘테이션 요구가 커질 때 가장 먼저 재검토할 후보다.
- `Cilium`: eBPF 기반 통합 데이터플레인과 observability가 실제 요구가 될 때 재검토할 후보다.

즉 `Flannel` 선택은 "제일 쉬운 것을 쓰자"가 아니라, **현재 단계에서 CNI의 책임 범위를 의도적으로 줄이고 나머지 축을 분리 관리하자**는 판단이다.

최종 결정은 [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md)에 기록한다.

---

## 11) 참고 자료

- Kubernetes Network Plugins: https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/
- Kubernetes Services, Load Balancing, and Networking: https://kubernetes.io/docs/concepts/services-networking/
- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
- Kubernetes NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Flannel README: https://github.com/flannel-io/flannel
- Calico Component Architecture: https://docs.tigera.io/calico/latest/reference/architecture/overview
- Calico GlobalNetworkPolicy: https://docs.tigera.io/calico/latest/reference/resources/globalnetworkpolicy
- Cilium System Requirements: https://docs.cilium.io/en/stable/operations/system_requirements.html
- Cilium kube-proxy replacement: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
