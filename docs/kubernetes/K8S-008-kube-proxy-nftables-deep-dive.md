# K8S-008: kube-proxy nftables 심화 - 왜 유망한 후속 후보인가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | `kube-proxy` `nftables` 모드의 장점과 현재 비선정 이유 정리 |
| 관련 문서 | [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md) |

---

## 1) 문서 목적

이 문서는 `nftables` 모드가 단순히 "새로운 옵션"이 아니라, 장기적으로 `iptables`와 `ipvs`를 대체할 가능성이 큰 후보라는 점과, 그럼에도 왜 지금 즉시 기준선으로 올리지 않는지 설명하기 위해 작성했다.

---

## 2) nftables 모드가 무엇인가

Kubernetes 공식 문서와 블로그 기준으로 `nftables`는 Linux에서 사용할 수 있는 `kube-proxy` 모드이며, `iptables`와 `ipvs`의 후속 구현으로 설명된다.

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

## 4) 장점

### 4.1. `iptables`와 `ipvs`의 후속 후보로 보고 있다

Kubernetes 블로그는 `nftables`가 장기적으로는 `iptables`와 `ipvs`를 대체하는 방향이며, 특히 `ipvs`보다 더 적합한 구현이라고 설명한다.

### 4.2. 대규모에서 성능과 규칙 관리 측면이 유리하다

특히 `Service` 수와 endpoint 수가 커질수록 `nftables`는 `iptables`보다 효율적인 경로가 될 수 있다.

### 4.3. 공식 프로젝트의 현재 권장 방향과 가깝다

Kubernetes는 `iptables`를 당분간 계속 지원하겠다고 하지만, 장기적으로는 `nftables`가 더 나은 구현이라고 분명히 설명한다.

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

### 6.3. 운영 이해도와 디버깅 경험이 아직 낮다

현재는 `nftables` 규칙 구조와 운영 경험이 충분히 쌓이지 않았다. 따라서 성능상 장점이 있더라도, 지금 당장 기준선으로 채택하는 것은 운영 설명 가능성을 떨어뜨릴 수 있다.

---

## 7) 호환성 차이와 주의점

`nftables`는 단순히 더 빠른 모드가 아니라, 일부 오래된 `iptables` 동작을 그대로 유지하지 않는다.

- `type: NodePort`를 `127.0.0.1`에서 접근하는 동작은 기본적으로 지원하지 않는다.
- `iptables` 모드가 넣어주던 NodePort용 방화벽 accept 규칙을 자동으로 넣지 않는다.
- Linux 6.1 미만 커널의 일부 conntrack 문제에 대해 `iptables`가 제공하던 완화 로직이 기본 포함되지 않는다.
- Kubernetes 블로그는 다른 네트워킹 구성 요소나 관측 도구가 아직 `nftables` 모드를 충분히 지원하지 않을 수 있다고 경고한다.

즉 `nftables`는 성능상 더 나은 후속 후보지만, **기존 `iptables`의 호환성 습관까지 그대로 기대하면 안 된다.**

---

## 8) 정리

`nftables`는 "안 좋은 선택지"가 아니라, **현재 기준선 뒤에 오는 가장 유력한 후속 후보**다.

따라서 현재는 `iptables`를 쓰되, `Service` 규모나 운영 이해도가 충분히 올라오면 가장 먼저 재검토할 대상은 `nftables`다.

---

## 9) 참고 자료

- Kubernetes v1.33 release: https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/
- NFTables mode for kube-proxy: https://kubernetes.io/blog/2025/02/28/nftables-kube-proxy/
- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
