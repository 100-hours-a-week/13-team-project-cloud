# K8S-008: kube-proxy nftables 참고 메모 - 무엇이고 왜 현재 기준선에 넣지 않았는가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | `kube-proxy` `nftables` 모드의 특징과 현재 기준선에 넣지 않은 이유 정리 |
| 관련 문서 | [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md) |

---

## 1) 문서 목적

이 문서는 `nftables` 모드가 무엇인지와 `iptables` 대비 어떤 차이가 있는지를 정리하고, 왜 현재 설계 기준선에는 넣지 않았는지 설명하기 위해 작성했다.

---

## 2) nftables 모드가 무엇인가

Kubernetes 공식 문서와 블로그 기준으로 `nftables`는 Linux에서 사용할 수 있는 `kube-proxy` 모드다.

Kubernetes v1.33 release 문서는 `nftables` backend가 stable이라고 안내하며, 성능과 확장성 측면에서 개선을 제공한다고 설명한다.

---

## 3) 패킷 경로와 규칙 모델

`nftables` 모드의 핵심 차이는 상단 dispatch 구조다.

```mermaid
flowchart LR
    A["클라이언트"] --> B["Service ClusterIP:Port"]
    B --> C["단일 nftables rule"]
    C --> D["verdict map 조회"]
    D --> E["Service별 체인"]
    E --> F["선택된 endpoint"]
```

`iptables`는 상단 체인에 Service별 규칙을 길게 나열하는 반면, `nftables`는 `Service IP + protocol + port` 조합을 맵으로 조회해 다음 체인으로 바로 넘긴다. Kubernetes 블로그는 이를 사실상 O(1)에 가까운 dispatch 경로로 설명한다.

---

## 4) 기술적 특징

### 4.1. 큰 규모에서 dispatch 구조가 더 단순하다

특히 `Service` 수와 endpoint 수가 커질수록 `nftables`는 `iptables`보다 효율적인 경로가 될 수 있다.

### 4.2. 규칙 갱신 API가 더 점진적이다

변경된 Service와 endpoint에 대해 더 부분적으로 update를 보낼 수 있다는 점이 특징이다.

---

## 5) 기술적으로 어디가 다른가

### 5.1. 데이터플레인 latency

Kubernetes 블로그는 `iptables` 상단 규칙 조회가 Service 수에 대해 O(n) 성격을 띠는 반면, `nftables`는 단일 rule + `verdict map` 구조로 거의 일정한 조회 특성을 가진다고 설명한다.

### 5.2. 규칙 갱신 방식

`iptables`는 전체 ruleset 크기에 영향을 받는 갱신 비용이 크다. 반면 `nftables` API는 변경된 Service와 endpoint에 대해서만 더 점진적인 update를 보낼 수 있다.

### 5.3. 구성 요소 간 간섭

Kubernetes 블로그는 `nftables` API가 각 컴포넌트의 private table을 허용하므로, `iptables`에서 볼 수 있는 전역 lock contention 문제를 줄일 수 있다고 설명한다.

---

## 6) 그런데 왜 지금 기준선은 아닌가

### 6.1. 여전히 Linux 기본 모드는 `iptables`다

Kubernetes config API 기준 현재 Linux 기본 모드는 `iptables`다. 즉 `nftables`는 stable이지만 기본값은 아니다.

### 6.2. 커널과 userspace 전제가 있다

Kubernetes 문서 기준 `nftables` 모드는 kernel 5.13+와 적절한 `nft` userspace 도구 버전이 필요하다.

현재 단계에서는 이 전제를 Service 데이터플레인 기준선으로 함께 잠그기보다, 보수적 기준선을 먼저 두는 편이 적절하다.

### 6.3. 실제 설계 검토 범위에 포함하지 않았다

이번 설계에서는 `iptables`, `ipvs`, eBPF replacement를 중심으로 기준선을 정리했고, `nftables`는 존재만 인지하는 수준으로 남겼다. 따라서 성능상 장점이 있더라도, 지금 당장 기준선이나 후속 우선 검토 대상으로 두지 않는다.

---

## 7) 호환성 차이와 주의점

`nftables`는 단순히 더 빠른 모드가 아니라, 일부 오래된 `iptables` 동작을 그대로 유지하지 않는다.

- `type: NodePort`를 `127.0.0.1`에서 접근하는 동작은 기본적으로 지원하지 않는다.
- `iptables` 모드가 넣어주던 NodePort용 방화벽 accept 규칙을 자동으로 넣지 않는다.
- Linux 6.1 미만 커널의 일부 conntrack 문제에 대해 `iptables`가 제공하던 완화 로직이 기본 포함되지 않는다.
- Kubernetes 블로그는 다른 네트워킹 구성 요소나 관측 도구가 아직 `nftables` 모드를 충분히 지원하지 않을 수 있다고 경고한다.

즉 `nftables`는 기술적으로 알아둘 가치가 있지만, **기존 `iptables`의 호환성 습관까지 그대로 기대하면 안 된다.**

---

## 8) 정리

`nftables`는 Linux `kube-proxy`의 공식 대안 중 하나다. 다만 이번 설계에서는 실제 채택 후보로 깊게 검토하지 않았으므로, 현재는 참고 메모 수준으로만 남긴다.

---

## 9) 참고 자료

- Kubernetes v1.33 release: https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/
- NFTables mode for kube-proxy: https://kubernetes.io/blog/2025/02/28/nftables-kube-proxy/
- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
