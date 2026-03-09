# DR-004: Kubernetes 배포 방식 선정 - kubeadm

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md) |
| 주요 목표 | self-managed Kubernetes 배포 기준선 선정 및 후속 네트워크/진입점 설계의 기반 고정 |

---

## 1) 결정

본 설계에서는 self-managed Kubernetes 배포 기준선으로 `kubeadm` 기반 업스트림 Kubernetes를 채택한다.

이번 결정의 기준은 "가장 빨리 설치되는 배포판"이 아니다. 현재 단계에서 더 중요한 것은 CNI, Gateway, 인증서, 배포 자동화, Service 데이터플레인 같은 핵심 구성 요소를 특정 배포판의 기본 번들에 덜 종속적으로 선택할 수 있는가에 있다.

`kubeadm`은 Kubernetes 공식 문서가 제공하는 표준 부트스트랩 경로이며, 설계상으로도 **클러스터 부트스트랩과 그 위의 운영 스택을 분리**하기에 가장 적합한 기준선이다.

---

## 2) 배경

현재 클러스터 설계 전제는 다음과 같다.

- 운영 인원은 소수다.
- 지금은 application layer부터 먼저 클러스터화하는 단계다.
- CNI, Gateway, 외부 LB, 인증서 관리, 업그레이드 정책은 각각 별도 설계 축으로 관리하려 한다.
- 배포판이 많은 기능을 기본값으로 같이 가져오는 것보다, 각 계층을 독립적으로 고를 수 있는 구조가 더 중요하다.

Kubernetes 공식 문서에서 `kubeadm`은 `kubeadm init`과 `kubeadm join`을 제공하는 best-practice fast path로 설명되며, machine provisioning 자체나 add-on 설치는 범위 밖이라고 명시한다.

즉 이번 결정의 핵심은 "더 많은 것을 한 번에 제공하느냐"가 아니라, **클러스터 기준선을 어디까지로 정의하고 그 위의 선택을 얼마나 독립적으로 유지할 수 있느냐**에 있다.

---

## 3) 선택 기준

이번 선택은 아래 기준으로 평가한다.

### 3.1. 업스트림 표준성과 설명 가능성

기준선은 특정 배포판의 제품 모델보다, 업스트림 Kubernetes 문서와 운영 절차에 직접 연결되는 편이 유리하다.

### 3.2. 번들 구성요소에 대한 종속 최소화

현재 설계에서는 CNI, Gateway, 인증서, Service 데이터플레인 전략을 별도로 결정하고자 한다. 따라서 배포판의 기본 번들이 설계 방향을 사실상 잠그지 않는 편이 좋다.

### 3.3. 부트스트랩과 Day-2 운영의 책임 경계

클러스터를 어떻게 띄우는지와, 그 위에 어떤 네트워크/진입점/운영 정책을 올릴지를 분리할 수 있어야 한다.

### 3.4. 현재 팀 규모에서의 적합성

운영 인원이 적더라도, 초기 설치 편의보다 장애 시 동작을 설명하고 추적할 수 있는 운영 투명성이 더 중요하다.

---

## 4) 고려한 대안

검토 대상은 다음 세 가지였다.

- `kubeadm`
- `k3s`
- `k0s`

이 셋 모두 self-managed Kubernetes를 구성할 수 있지만, 내부 운영 모델과 기본 번들 전략은 다르다.

---

## 5) 선택 근거

### 5.1. `kubeadm`은 업스트림 Kubernetes의 가장 직접적인 부트스트랩 기준선이다

Kubernetes 공식 문서는 `kubeadm`을 최소 실행 가능한 클러스터를 띄우기 위한 표준 부트스트랩 도구로 설명한다. 또한 `kubeadm`은 bootstrapping에 집중하고, machine provisioning이나 add-on 설치는 범위 밖이라고 명시한다.

이 점은 현재 설계에 중요하다. 우리는 배포 방식 자체보다, 그 위에 올릴 CNI, Gateway, 인증서, 데이터플레인을 독립 설계 축으로 두려 하기 때문이다.

### 5.2. 설치 도구와 운영 스택을 분리하기 쉽다

`kubeadm`은 기본적으로 클러스터를 "띄우는" 역할에 집중한다. 따라서 다음 선택을 배포판 기본값과 느슨하게 결합할 수 있다.

- CNI
- Gateway API / Gateway Controller
- 인증서 전략
- 외부 LB
- `kube-proxy` 모드 또는 대체 모델

즉 `kubeadm`은 기능이 적어서 불리한 것이 아니라, **현재 설계에서 필요한 독립 선택 여지를 가장 많이 남기는 기준선**이다.

### 5.3. 운영 동작이 덜 숨겨진다

`kubeadm init`, `kubeadm join`, `kubeadm upgrade`는 Kubernetes 공식 절차와 직접 연결된다. control plane static Pod, join, 인증서, upgrade 흐름도 공식 문서와 일치한다.

현재 단계에서는 자동화가 많은 제품형 배포판보다, 클러스터가 어떤 구조로 올라오고 어떤 순서로 확장되는지 설명 가능한 편이 더 중요하다.

### 5.4. 이후 확장에도 기준선이 덜 흔들린다

현재는 single control plane을 먼저 검토하고 있지만, 이후 HA로 가더라도 `kubeadm`은 공식적으로 stacked control plane과 external etcd 기반 HA 토폴로지를 모두 문서화하고 있다.

즉 `kubeadm` 기준선은 현재 단일 구성과 이후 HA 확장 사이를 가장 자연스럽게 연결한다.

---

## 6) 선택하지 않은 이유

### 6.1. k3s

`k3s`는 유효한 경량 Kubernetes 배포판이다. 공식 문서 기준으로 단일 바이너리와 낮은 자원 요구를 강조하며, `containerd`, `Flannel`, `Traefik`, `ServiceLB`, network policy controller 같은 packaged components를 기본 제공한다.

이 장점은 edge, homelab, CI 같은 환경에서는 매우 강하다.

다만 현재 설계에서는 이 번들 이점이 상대적으로 줄어든다.

- CNI는 별도 선택하려 한다.
- Gateway 계층도 별도 표준화하려 한다.
- `ServiceLB`는 현재 구조의 핵심 전제가 아니다.
- 번들 컴포넌트를 비활성화하고 교체하기 시작하면 `k3s`의 핵심 장점 일부가 희석된다.

즉 `k3s`는 좋은 제품이지만, 현재 설계 기준에서는 "배포판의 내장 기본값을 활용하는 전략"보다 "부트스트랩 후 각 축을 독립 설계하는 전략"이 더 중요했다.

### 6.2. k0s

`k0s`도 매우 유효한 대안이다. 공식 문서 기준으로 단일 self-extracting binary이며, control plane 구성요소를 process supervisor 형태로 관리한다. 또한 controller에는 기본적으로 container engine이나 kubelet이 없고, 사용자가 workload를 스케줄하지 못하도록 하는 운영 모델도 분명하다.

이 점은 단정한 운영 경험을 제공할 수 있다.

다만 현재 기준에서는 다음 점이 걸린다.

- `kubeadm`보다 업스트림 공식 운영 절차와 직접 연결되는 정도가 약하다.
- `k0s` 고유 운영 모델을 추가로 이해해야 한다.
- 현재 설계의 목표는 제품 고유 모델 채택보다, 업스트림 기준선 위에 후속 설계를 올리는 것이다.

즉 `k0s`는 구조적으로 흥미롭고 깔끔한 대안이지만, 지금 필요한 기준선은 `kubeadm` 쪽이 더 적합했다.

---

## 7) 결과

초기 Kubernetes 배포 기준선은 다음과 같이 고정한다.

- Deployment baseline: `kubeadm`
- Container runtime baseline: `containerd`
- CNI: 별도 DR에서 결정
- Control plane topology: 별도 DR에서 결정
- Gateway / 인증서 / 데이터플레인: 별도 DR에서 결정

즉 `kubeadm` 결정은 네트워크, 진입점, 운영 정책을 함께 결정하는 문서가 아니라, **그 이후 선택들이 얹힐 부트스트랩 기준선을 고정하는 문서**다.

---

## 8) 장단점

장점

- 업스트림 Kubernetes 기준선과 가장 직접 연결된다.
- 배포판 기본 번들에 덜 종속적이다.
- 부트스트랩과 운영 스택의 책임 경계를 분리하기 쉽다.
- 향후 single control plane에서 HA로 확장할 때도 공식 경로가 선명하다.

단점

- 초기 설치와 부트스트랩 편의는 `k3s`보다 높지 않다.
- 운영자가 직접 관리해야 할 범위가 넓다.
- 잘못 설계하면 "자유도"가 곧 운영 부담으로 바뀔 수 있다.

---

## 9) 후속 검토 항목

1. 컨트롤 플레인 구조 선정 (`single` vs `HA`)
2. CNI 선정
3. `kube-proxy` 모드 및 Service 데이터플레인 전략
4. 인증서 및 도메인 관리 전략
5. 노드 프로비저닝 자동화와 `kubeadm join` 절차 표준화

---

## 10) 최종 판단 문장

> 본 설계에서 `kubeadm`을 채택한 이유는 더 단순한 배포판이 없어서가 아니다. 현재 단계의 핵심은 특정 배포판의 batteries-included 기본값을 활용하는 것이 아니라, 업스트림 Kubernetes 기준선 위에서 CNI, Gateway, 인증서, 데이터플레인 전략을 독립적인 설계 축으로 유지하는 데 있다. `kubeadm`은 bootstrapping 자체에 집중하고 machine provisioning과 add-on 설치를 범위 밖으로 두므로, 현재 설계 의도와 가장 잘 맞는 self-managed Kubernetes 기준선이다.

---

## 11) 참고 자료

- Kubernetes kubeadm reference: https://kubernetes.io/docs/reference/setup-tools/kubeadm/
- Bootstrapping clusters with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- Creating Highly Available Clusters with kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
- K3s overview: https://docs.k3s.io/
- K3s packaged components: https://docs.k3s.io/installation/packaged-components
- k0s architecture: https://docs.k0sproject.io/head/architecture/
