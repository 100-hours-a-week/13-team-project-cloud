# DR-010: kube-proxy 모드 및 Service 데이터플레인 전략 선정

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md), [K8S-006 Service 데이터플레인 비교 연구](../kubernetes/K8S-006-service-dataplane-comparison-study.md), [K8S-007 iptables 심화](../kubernetes/K8S-007-kube-proxy-iptables-deep-dive.md), [K8S-009 ipvs 심화](../kubernetes/K8S-009-kube-proxy-ipvs-deep-dive.md), [K8S-010 eBPF replacement 메모](../kubernetes/K8S-010-ebpf-service-dataplane-note.md) |
| 주요 목표 | Kubernetes `Service` 데이터플레인 기준선과 `kube-proxy` 모드 선정 |

---

## 1) 결정

본 설계에서는 Kubernetes `Service` 데이터플레인을 `kube-proxy`로 유지하고, 초기 모드는 `iptables`를 채택한다.

이번 결정은 "다른 모드가 낯설어서 피한다"는 뜻이 아니다. 현재 단계에서는 `Service ClusterIP -> Pod endpoint` 전달 계층을 가장 보수적이고 설명 가능한 기준선으로 먼저 고정하는 것이 더 중요하다.

또한 `ipvs`는 현재 Kubernetes 기준으로 deprecated 방향이므로 채택하지 않는다. eBPF 기반 `kube-proxy replacement`는 현재 단계에서 제외한다.

---

## 2) 배경

현재 설계에서 역할은 다음과 같이 분리한다.

- Pod 네트워크: `Flannel`
- Service 데이터플레인: `kube-proxy`
- 외부 L7 진입: `Traefik`
- 외부 L4 진입: `public NLB`

즉 이번 결정은 CNI 선택과 별개로, **`Service ClusterIP`가 실제 backend Pod endpoint로 어떻게 전달되는지**를 정하는 문서다.

Kubernetes 공식 문서는 Linux에서 `kube-proxy`가 `Service`의 virtual IP 메커니즘을 구현한다고 설명하며, config API 기준 기본 모드는 `iptables`다.

---

## 3) 선택 기준

이번 선택은 아래 기준으로 평가한다.

### 3.1. 현재 단계에서 Service 데이터플레인을 안정적으로 설명할 수 있는가

지금은 최고 성능 구현보다, `Service ClusterIP`가 어떻게 실제 Pod endpoint로 연결되는지 문서와 운영에서 설명 가능한 기준선이 더 중요하다.

### 3.2. 공식 Kubernetes 문서 기준과 크게 어긋나지 않는가

현재 기준선은 프로젝트의 기본 경로와 완전히 어긋나지 않는 편이 유리하다.

### 3.3. 현재 기준선을 과도하게 넓히지 않는가

지금 단계에서는 실제로 채택하지 않은 대안을 기준선 문서 안에 과도하게 끌고 들어오지 않는 편이 더 적절하다.

---

## 4) 고려한 대안

검토 대상은 다음 세 가지였다.

- `kube-proxy` `iptables` 모드
- `kube-proxy` `ipvs` 모드
- eBPF 기반 `kube-proxy replacement`

---

## 5) 선택 근거

### 5.1. `kube-proxy`는 현재 구조에서 가장 자연스러운 Service 데이터플레인 구현이다

현재 설계는 Pod 네트워크, `Service` 데이터플레인, Gateway 계층을 분리해서 본다.

이 기준에서 `kube-proxy`는 `Service ClusterIP` 전달 계층을 가장 명확하게 설명할 수 있는 기본 구현이다.

### 5.2. `iptables`는 현재 가장 보수적인 기준선이다

Kubernetes config API 기준 Linux에서 기본 `kube-proxy` 모드는 `iptables`다.

현재 단계에서는 `Service` 트래픽 전달 경로를 가장 보수적이고 검증된 기본값으로 고정하는 것이 적절하다고 판단했다. 이는 성능을 포기한다는 뜻이 아니라, **현재 단계에서 데이터플레인 책임 범위를 보수적으로 고정한다는 뜻**이다.

### 5.3. `ipvs`는 deprecated 방향이므로 채택하지 않는다

Kubernetes 공식 문서는 `ipvs` 모드를 deprecated로 설명한다. 성능상 장점은 있었지만, Kubernetes Service API와 정합성이 좋지 않았고 edge case를 완전히 구현하지 못했다.

따라서 현재 시점에서 `ipvs`를 기준선으로 채택할 이유는 약하다.

### 5.4. eBPF replacement는 현재 단계에서 제외한다

eBPF replacement는 `Service` 데이터플레인만 바꾸는 것이 아니라, 커널 레벨 네트워크 운영 모델까지 함께 바꾸는 결정이 된다.

현재 단계에서는 `kube-proxy` 기준선을 먼저 명확히 고정하는 편이 더 중요하므로, 이 축은 후속 검토로 둔다.

---

## 6) 선택하지 않은 이유

### 6.1. `ipvs`

deprecated 방향이며, 현재 Kubernetes가 권장하는 기본 경로가 아니다.

### 6.2. eBPF replacement

지금 단계에서는 잠그는 축이 너무 많고, 운영 복잡도가 급격히 증가한다.

---

## 7) 결과

초기 Service 데이터플레인 기준선은 다음과 같이 고정한다.

- Service 데이터플레인 구현: `kube-proxy`
- 초기 모드: `iptables`
- 비선정: `ipvs`
- 현재 제외: eBPF 기반 replacement

즉 현재 구조에서는 `Service ClusterIP` 전달 계층을 `kube-proxy iptables`로 운영하고, 다른 대안은 비교 참고 문서 수준으로만 남긴다.

---

## 8) 장단점

장점

- 현재 Kubernetes 기본 경로와 직접 정합된다.
- `Service ClusterIP` 전달 계층을 설명하고 운영하기 쉽다.
- `Flannel`, `Traefik`과의 역할 분리가 선명하다.

단점

- 장기적으로 가장 진보된 구현은 아니다.
- eBPF replacement의 고급 기능은 현재 기준선에 포함되지 않는다.

---

## 9) 후속 검토 항목

1. `Service` 수와 endpoint 수 증가 시 `iptables` rule 규모 영향 점검
2. eBPF replacement의 실익이 커질 경우 별도 재평가

---

## 10) 최종 판단 문장

> 본 설계에서는 Kubernetes `Service` 데이터플레인을 `kube-proxy`로 유지하고, 초기 모드는 `iptables`를 기준선으로 채택한다. 이는 다른 모드가 낯설어서가 아니라, 현재 단계에서 `Service ClusterIP` 전달 계층을 가장 보수적이고 설명 가능한 기본 경로로 먼저 고정하기 위한 판단이다. `ipvs`는 deprecated 방향이므로 채택하지 않으며, eBPF 기반 replacement는 현재 단계에서 제외한다.

---

## 11) 참고 자료

- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
- Service ClusterIP allocation: https://kubernetes.io/docs/concepts/services-networking/cluster-ip-allocation/
- kube-proxy configuration API: https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/
- Kubernetes v1.33 release: https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/
