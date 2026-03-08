# K8S-009: kube-proxy ipvs 심화 - 무엇이었고 왜 지금은 기준선이 아닌가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | `kube-proxy` `ipvs` 모드의 동작, 장점, 비선정 이유 정리 |
| 관련 문서 | [K8S-006 Service 데이터플레인 비교 연구](K8S-006-service-dataplane-comparison-study.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md) |

---

## 1) 문서 목적

이 문서는 `ipvs`가 정확히 무엇이었는지, 왜 한때 유력한 대안이었는지, 그리고 왜 현재 Kubernetes 기준으로는 더 이상 기준선으로 잡지 않는지 설명하기 위해 작성했다.

---

## 2) IPVS가 무엇인가

IPVS는 Linux kernel의 IP Virtual Server 기능이다. Kubernetes `kube-proxy`의 `ipvs` 모드는 이 커널 기능과 `iptables` API를 함께 사용해 `Service ClusterIP -> endpoint IP` 전달 규칙을 만든다.

Kubernetes 공식 문서는 `ipvs` 모드가 netfilter hook function 기반이며, `iptables`와 비슷한 위치에서 동작하지만 **hash table을 기반으로 kernel space에서 동작한다**고 설명한다.

즉 `ipvs`는 Kubernetes가 직접 만든 새로운 load balancer가 아니라, **Linux kernel L4 load balancer 기능을 kube-proxy가 활용하는 방식**이다.

---

## 3) IPVS 모드의 구조

단순화하면 IPVS 모드의 구조는 아래와 같다.

```mermaid
flowchart LR
    A["클라이언트"] --> B["Service ClusterIP:Port"]
    B --> C["IPVS virtual server"]
    C --> D["scheduler 선택"]
    D --> E["real server(endpoint)"]
    E --> F["필요한 일부 보조 규칙은 iptables 사용"]
```

중요한 점은 다음과 같다.

- `virtual server`는 Service를 뜻한다.
- `real server`는 실제 backend endpoint를 뜻한다.
- `scheduler`는 어떤 backend를 고를지 정하는 알고리즘이다.
- 즉 `ipvs`는 `iptables`보다 더 전형적인 커널 L4 load balancer 모델을 사용한다.

---

## 4) 왜 한때 유력했는가

`ipvs`는 `iptables`보다 다음 장점이 있었다.

- rule synchronization이 더 빨랐다.
- 네트워크 throughput이 더 높았다.
- 다양한 scheduler를 제공했다.

Kubernetes가 한때 `ipvs`를 실험적 대안으로 본 이유도 여기에 있다.

---

## 5) 제공하던 scheduler 예시

Kubernetes 문서는 `ipvs`에서 다음과 같은 scheduler를 제공한다고 설명한다.

- `rr`: round robin
- `wrr`: weighted round robin
- `lc`: least connection
- `wlc`: weighted least connection
- `sh`: source hashing
- `dh`: destination hashing
- `sed`: shortest expected delay
- `nq`: never queue
- `mh`: maglev hashing

즉 `ipvs`는 단순히 빠르기만 한 것이 아니라, **backend 선택 알고리즘 선택 폭도 넓었다.**

---

## 6) 그런데 왜 지금은 기준선이 아닌가

Kubernetes 공식 문서는 현재 `ipvs` 모드를 deprecated로 표시한다.

핵심 이유는 다음과 같다.

### 6.1. Kubernetes Service API와 정합성이 좋지 않았다

공식 문서 기준으로 kernel IPVS API는 Kubernetes Service API와 잘 맞지 않았고, 일부 edge case를 완전히 올바르게 구현하지 못했다.

즉 단순 성능만 보면 장점이 있었지만, **Kubernetes가 요구하는 Service 동작을 정확히 담아내는 데 한계**가 있었다.

### 6.2. 현재 Kubernetes 기준선과 정합성이 떨어진다

즉 `ipvs`는 과거의 성능 개선 실험으로는 의미가 있었지만, 현재는 유지해야 할 전략적 기준선으로 보기 어렵다.

### 6.3. 지금 배우는 비용 대비 장기 가치가 낮다

현재 시점에서 `ipvs`를 깊게 운영 기준선으로 채택하면, deprecated 방향의 구현을 별도로 더 배워야 하는 셈이 된다. 지금 기준선으로는 적절하지 않다.

### 6.4. 운영 전제도 더 있다

Kubernetes 공식 문서는 `ipvs` 모드 사용 전 노드에 IPVS 커널 모듈이 준비되어 있어야 하며, 없으면 `kube-proxy`가 오류로 종료된다고 설명한다.

즉 `ipvs`는 단순히 설정값 하나만 바꾸는 모드가 아니라, 커널 모듈 가용성까지 운영 전제로 요구한다.

---

## 7) 정리

`ipvs`는 "빠른 커널 L4 load balancer를 이용한 kube-proxy 모드"였고, 그 핵심은 hash table 기반으로 동작한다는 점이다.

하지만 현재 Kubernetes 기준으로는 deprecated 방향이며, 장기 운영 기준선으로 잡을 이유가 약하다.

따라서 지금 `ipvs`는 **비교 이해를 위한 심화 주제**로는 중요하지만, 실제 채택 후보로는 두지 않는다.

---

## 8) 참고 자료

- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
- Kubernetes v1.33 Virtual IPs and Service Proxies: https://v1-33.docs.kubernetes.io/docs/reference/networking/virtual-ips/
- NFTables mode for kube-proxy: https://kubernetes.io/blog/2025/02/28/nftables-kube-proxy/
