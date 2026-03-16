# K8S-010: eBPF 기반 Service 데이터플레인 메모 - 왜 현재는 제외하는가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | eBPF 기반 `kube-proxy replacement`의 의미와 현재 제외 이유 정리 |
| 관련 문서 | [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md), [K8S-005 Cilium 심화](K8S-005-cilium-deep-dive.md) |

---

## 1) 문서 목적

이 문서는 eBPF 기반 `kube-proxy replacement`가 무엇을 의미하는지, 그리고 왜 현재 단계에서는 Service 데이터플레인 기준선에서 제외하는지 정리하기 위해 작성했다.

---

## 2) eBPF replacement가 의미하는 것

eBPF replacement는 단순히 `kube-proxy` 구현 모드를 바꾸는 것이 아니다.

이는 보통 다음을 함께 바꾸는 선택이 된다.

- `Service ClusterIP` 처리 방식
- NodePort / LoadBalancer 처리 방식
- 패킷 처리 경로
- 일부 관측성
- 네트워크 운영 모델

즉 이건 `iptables` 같은 `kube-proxy` 내부 모드 변경보다 더 큰 수준의 설계 변경이다.

---

## 3) 왜 `kube-proxy` 모드 변경과 성격이 다른가

`iptables`와 `ipvs`는 모두 "`kube-proxy`가 `Service ClusterIP -> endpoint Pod` 전달 경로를 어떻게 구현할 것인가"의 차이다.

반면 eBPF replacement는 보통 아래를 함께 바꾼다.

- `kube-proxy` 유지 여부
- Service 처리 주체
- NodePort / LoadBalancer 처리 주체
- kernel 기능 요구사항
- 관측과 디버깅 방식

예를 들어 Cilium 공식 문서는 `kubeProxyReplacement=true`일 때 kernel 지원이 부족하면 Cilium agent가 실패하도록 동작한다고 설명한다. 또 direct routing과 tunneling 모드 모두에서 동작할 수 있고, NodePort / LoadBalancer 처리와 XDP acceleration까지 연결될 수 있다고 설명한다.

즉 이 선택은 단순히 "더 빠른 Service 프록시"가 아니라, **Service 데이터플레인 전체의 운영 모델 변경**에 가깝다.

---

## 4) 기술적으로 어떤 장점이 있는가

- `Service ClusterIP` 처리와 NodePort / LoadBalancer 처리를 더 통합적으로 다룰 수 있다.
- 커널 eBPF 경로를 통해 고성능 처리를 노릴 수 있다.
- 관측성 기능과 연결되기 쉽다.
- XDP acceleration 같은 고급 최적화까지 연결될 수 있다.

이 때문에 eBPF replacement는 장기적으로는 매우 강력한 후보가 될 수 있다.

---

## 5) 왜 현재는 제외하는가

### 5.1. 현재 단계에서 잠그는 축이 너무 많다

우리는 지금 CNI와 `Service` 데이터플레인을 분리해서 보고 있다. eBPF replacement를 바로 채택하면, `Service` 데이터플레인뿐 아니라 커널 레벨 네트워크 운영 모델까지 함께 잠그게 된다.

### 5.2. 운영 이해도와 디버깅 비용이 높다

현재 단계에서는 `Service ClusterIP`, `kube-proxy`, `iptables`, `ipvs`를 먼저 명확히 이해하는 편이 더 중요하다. eBPF replacement는 이 위에 또 하나의 복잡도를 올린다.

### 5.3. 현재 실익이 충분히 크지 않다

현재 워크로드와 서비스 규모에서는 eBPF replacement가 가져오는 성능 및 기능 이점이 즉시 필수로 요구되는 단계는 아니다.

---

## 6) 현재 설계와의 긴장점

현재 공식 기준선은 다음처럼 역할을 분리한다.

- Pod 네트워크: `Flannel`
- Service 데이터플레인: `kube-proxy`
- 외부 L7 진입: `Traefik`

eBPF replacement를 바로 도입하면 이 분리선이 달라질 수 있다. 특히 Service 데이터플레인과 CNI를 다시 함께 검토하게 만들 수 있다. 이 문장은 공식 문서 인용이 아니라 현재 설계에 대한 해석이다.

즉 지금 단계에서 eBPF replacement를 넣는 것은 단순한 성능 최적화가 아니라, **이미 닫아둔 설계 경계 일부를 다시 여는 일**이 된다.

---

## 7) 정리

eBPF replacement는 장기적으로 유효한 고도화 방향일 수 있다. 그러나 현재 단계에서는 `kube-proxy` 기준선을 먼저 명확히 고정하는 편이 더 중요하다.

따라서 지금은 eBPF replacement를 채택하지 않고, 후속 재검토 항목으로 둔다.

---

## 8) 참고 자료

- Cilium kube-proxy replacement: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
