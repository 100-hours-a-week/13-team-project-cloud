# K8S-007: kube-proxy iptables 심화 - 왜 현재 Service 데이터플레인 기준선인가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | `kube-proxy` `iptables` 모드의 동작과 현재 적합성 정리 |
| 관련 문서 | [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md) |

---

## 1) 문서 목적

이 문서는 `iptables` 모드가 단순히 "예전 방식"이 아니라, 현재 단계에서 `Service` 데이터플레인 기준선을 가장 보수적으로 고정하는 선택이라는 점을 설명하기 위해 작성했다.

---

## 2) iptables 모드가 실제로 하는 일

`kube-proxy`는 `Service`와 `EndpointSlice`를 watch하고, 각 노드에서 `Service ClusterIP -> Pod endpoint` 전달 규칙을 만든다.

`iptables` 모드에서는 이 규칙이 Linux netfilter `iptables` 체인으로 표현된다. 클라이언트가 `Service ClusterIP`로 접근하면, 커널은 이 규칙을 따라 실제 backend Pod endpoint로 패킷을 전달한다.

즉 `iptables` 모드는 `Service` 가상 주소를 **커널의 패킷 처리 규칙으로 구현하는 가장 전통적인 경로**다.

---

## 3) 패킷 흐름을 어떻게 구현하는가

`iptables` 모드의 흐름을 단순화하면 아래와 같다.

```mermaid
flowchart LR
    A["클라이언트"] --> B["Service ClusterIP:Port"]
    B --> C["KUBE-SERVICES 체인"]
    C --> D["Service별 체인"]
    D --> E["Endpoint별 체인"]
    E --> F["DNAT"]
    F --> G["선택된 Pod endpoint"]
```

운영상 중요한 포인트는 다음과 같다.

- 상단 체인에는 Service별 규칙이 쌓인다.
- Service 규칙은 다시 endpoint별 규칙으로 분기한다.
- endpoint 규칙에서 최종적으로 DNAT가 일어나 실제 Pod IP로 목적지가 바뀐다.
- 세션 어피니티를 켠 경우에는 같은 클라이언트를 같은 backend로 보내는 추가 로직이 개입할 수 있다.

즉 `iptables` 모드는 직관적으로 이해하기 쉬운 대신, Service 수가 많아질수록 상단 규칙 조회 비용이 늘어나는 구조다.

---

## 4) 기술적 특징

### 4.1. 장점

- Kubernetes Linux 환경의 기본 `kube-proxy` 경로다.
- 가장 오래 사용되어 왔고, 운영 자료와 장애 사례가 많다.
- `type: NodePort`를 `127.0.0.1`에서 접근하는 오래된 동작과 더 잘 맞는다.
- 로컬 방화벽이 강하게 설정된 환경에서도 NodePort inbound를 허용하려는 추가 규칙을 자동으로 넣는다.
- Linux 6.1 미만 커널에서 발생할 수 있는 일부 conntrack 문제에 대한 완화 로직이 기본 포함된다.

### 4.2. 한계

- 상단 규칙 수가 Service 수에 비례해 커진다.
- Kubernetes 블로그 기준으로 첫 패킷이 `KUBE-SERVICES` 체인을 검사하는 시간은 Service 수에 대해 O(n) 성격을 가진다.
- 대규모에서 규칙 갱신도 여전히 부담이 될 수 있다.

---

## 5) 왜 현재 기준선으로 맞는가

### 5.1. Kubernetes의 기본 경로다

Kubernetes 공식 config API 문서는 Linux에서 `kube-proxy` 기본 모드가 현재 `iptables`라고 설명한다.

즉 `iptables`는 여전히 가장 보수적이고 기본적인 기준선이다.

### 5.2. 현재 규모에서 충분히 설명 가능하다

현재 단계의 핵심은 대규모 `Service` 수에서의 최고 성능보다, `Service ClusterIP`가 실제로 어떻게 Pod endpoint로 연결되는지 설명 가능한 기준선을 갖는 것이다.

`iptables` 모드는 이 점에서 가장 익숙하고 자료도 풍부하다.

### 5.3. 다른 대안과 비교할 기준선을 제공한다

현재 `iptables`를 기준선으로 잡아두면, 이후 다른 `kube-proxy` 모드나 eBPF replacement를 검토할 때 비교 기준도 선명해진다.

즉 `iptables`는 최종 목표가 아니라, **현재 운영 기준선**으로서 의미가 있다.

---

## 6) 현재 선택이 의미하는 것

`iptables` 모드를 기준선으로 둔다는 것은 다음 뜻이다.

- `kube-proxy`를 유지한다.
- `Service ClusterIP` 전달은 검증된 기본 경로로 구현한다.
- `ipvs`나 eBPF replacement를 현재 기준선에 포함하지 않는다.
- 성능 최적화보다 운영 설명 가능성을 우선한다.

이는 "느려도 그냥 익숙한 걸 쓰자"가 아니라, 현재 단계에서 **Service 데이터플레인 책임 범위를 보수적으로 고정하자**는 결정이다.

---

## 7) 현재 기준선에서 감수하는 트레이드오프

장점

- Kubernetes 기본 경로와 직접 정합된다.
- 현재 팀이 설명하고 디버깅하기 쉽다.
- 문서와 운영 절차를 단순하게 가져가기 좋다.

한계

- 대규모 `Service`와 endpoint 수에서 규칙 수 증가에 따른 비효율이 커질 수 있다.
- 장기적으로 가장 진보된 데이터플레인이라고 보기는 어렵다.
- 이후 트래픽 규모가 커지면 재검토가 필요하다.

---

## 8) 참고 대안과 비교했을 때의 현재 차이

| 항목 | `iptables` | `nftables` |
|------|------------|-------------|
| 상단 dispatch 구조 | Service별 규칙 나열 | `verdict map` 기반 조회 |
| 첫 패킷 조회 비용 | Service 수가 커질수록 증가 | 더 일정한 조회 특성 |
| NodePort localhost | 가능할 수 있음 | 기본적으로 불가 |
| NodePort 방화벽 우회 규칙 | kube-proxy가 일부 추가 | 직접 방화벽 설정 필요 |
| conntrack 완화 로직 | 기본 포함 | 기본 미포함 |
| 현재 문서/운영 축적 | 더 많음 | 상대적으로 적음 |

즉 다른 대안이 존재하더라도, 현재 시점에서는 `iptables` 쪽이 호환성과 운영 이해도 측면에서 더 보수적인 기준선이다.

---

## 9) 언제 재검토해야 하는가

아래 조건이 생기면 `iptables` 기준선은 재검토 대상이 된다.

1. `Service` 수와 endpoint 수가 증가해 규칙 규모가 부담이 될 때
2. 다른 `kube-proxy` 모드나 eBPF replacement의 실익이 실제 운영상 커질 때

---

## 10) 참고 자료

- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
- kube-proxy configuration API: https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/
- NFTables mode for kube-proxy: https://kubernetes.io/blog/2025/02/28/nftables-kube-proxy/
