# K8S-006: Service 데이터플레인 비교 연구 - kube-proxy iptables vs ipvs vs eBPF replacement

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | Service 데이터플레인 개념 정리와 구현 방식 비교 연구 |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](K8S-001-final-design.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md), [K8S-007 iptables 심화](K8S-007-kube-proxy-iptables-deep-dive.md), [K8S-008 nftables 참고 메모](K8S-008-kube-proxy-nftables-deep-dive.md), [K8S-009 ipvs 심화](K8S-009-kube-proxy-ipvs-deep-dive.md), [K8S-010 eBPF replacement 메모](K8S-010-ebpf-service-dataplane-note.md) |

---

## 1) 문서 목적

이 문서는 Kubernetes `Service`가 어떻게 실제 Pod endpoint로 연결되는지 설명하고, 현재 검토 대상인 `kube-proxy` 모드와 eBPF replacement를 비교하기 위해 작성했다.

이번 문서의 목적은 "가장 빠른 구현"을 고르는 것이 아니라, **현재 단계에서 Service 데이터플레인을 어디까지 책임질 것인지**를 정리하는 데 있다.

---

## 2) 용어 통일

이 문서에서는 아래 용어를 고정해서 사용한다.

- `Service ClusterIP`
  Kubernetes `Service`에 할당되는 가상 IP 주소
- `Service VIP`
  `Service ClusterIP`의 짧은 별칭
- `Service 데이터플레인`
  `Service ClusterIP`로 들어온 트래픽을 실제 backend Pod endpoint로 전달하는 실행 계층
- `Pod 네트워크`
  CNI가 담당하는 Pod-to-Pod 연결 계층

즉 이 문서에서 다루는 것은 `Flannel`이 만드는 Pod 네트워크가 아니라, **`Service ClusterIP -> Pod endpoint` 전달 계층**이다.

---

## 3) Service ClusterIP와 Service 데이터플레인은 무엇인가

Kubernetes 공식 문서 기준으로 `Service`는 클러스터 내부에서 가상 IP를 가질 수 있고, `type: ClusterIP`인 경우 클라이언트는 이 가상 IP로 접근한다.

예를 들면:

- `backend` Service ClusterIP: `10.96.0.10:8080`
- 실제 backend Pod endpoint: `10.244.1.5:8080`, `10.244.2.9:8080`

클라이언트는 `10.96.0.10:8080`으로 요청하고, Kubernetes는 그 트래픽을 실제 backend Pod들 중 하나로 전달한다.

이때 "가상 IP로 들어온 트래픽을 실제 Pod endpoint로 보내는 계층"이 바로 `Service 데이터플레인`이다.

Kubernetes 공식 문서는 Linux에서 이 동작을 기본적으로 `kube-proxy`가 구현한다고 설명한다.

---

## 4) 현재 구조에서의 역할 분리

현재 설계 기준으로 역할을 나누면 다음과 같다.

- Pod 네트워크: `Flannel`
- Service 데이터플레인: `kube-proxy`
- 외부 L7 진입: `Traefik`
- 외부 L4 진입: `public NLB`

즉 이번 검토는 CNI 선택과 별개의 축이며, `Flannel` 선택이 곧 `Service` 전달 구현까지 자동으로 결정하는 것은 아니다.

---

## 5) 패킷이 실제로 흐르는 경로

아래 흐름은 현재 설계에서 `Service ClusterIP`가 실제 backend Pod로 연결되는 과정을 단순화한 것이다.

```mermaid
flowchart LR
    A["클라이언트 Pod 또는 노드 프로세스"] --> B["Service ClusterIP:Port"]
    B --> C["Service 데이터플레인"]
    C --> D["선택된 backend Pod endpoint"]
    D --> E["같은 노드면 로컬 전달"]
    D --> F["다른 노드면 Flannel Pod 네트워크 경유"]
```

핵심은 이렇다.

- 클라이언트는 Pod IP가 아니라 `Service ClusterIP`로 접근한다.
- `kube-proxy`는 각 노드에서 `Service`와 `EndpointSlice`를 보고 규칙을 만든다.
- 실제 backend Pod가 다른 노드에 있으면, 이후 패킷 전달은 `Flannel`이 담당하는 Pod 네트워크로 이어진다.

---

## 6) 비교 대상

이번 비교 대상은 아래 세 가지를 기준선 중심으로 보고, `nftables`는 참고 메모 수준으로만 함께 정리한다.

- `kube-proxy` `iptables` 모드
- `kube-proxy` `ipvs` 모드
- eBPF 기반 `kube-proxy replacement`
- `kube-proxy` `nftables` 모드 참고 메모

---

## 7) 비교 기준

이번 선택은 아래 기준으로 평가한다.

1. 현재 구조에서 Service 데이터플레인을 안정적으로 설명할 수 있는가
2. 현재 운영 규모와 트래픽 수준에서 과도한 복잡도를 만들지 않는가
3. 공식 Kubernetes 문서 기준으로 현재 권장 흐름과 크게 어긋나지 않는가
4. 다른 공식 대안을 알아두되 현재 기준선을 과도하게 흔들지 않는가

---

## 8) 구현 방식별 기술 비교

| 구현 방식 | 패킷 dispatch 구조 | 기술적 강점 | 호환성 또는 운영 전제 | 현재 평가 |
|------|--------------------|-------------|-----------------------|------------|
| `iptables` | `KUBE-SERVICES` 상단 체인에서 Service별 규칙을 순서대로 검사한 뒤 endpoint 규칙으로 DNAT | 가장 널리 검증됨, 현재 Linux 기본 경로, 운영 자료가 많음 | Service 수가 커질수록 첫 패킷 조회가 O(n) 성격을 가짐 | 현재 기준선 |
| `nftables` | `Service IP + protocol + port`를 `verdict map`으로 조회해 Service 체인으로 분기 | 첫 패킷 latency와 rule update 효율이 더 좋음 | kernel 5.13+, `nft` 도구, NodePort/방화벽/conntrack 차이 이해 필요 | 참고 메모 |
| `ipvs` | 커널 IPVS virtual server / real server 구조와 일부 `iptables` 보조 규칙을 함께 사용 | hash table 기반, 높은 throughput, 다양한 scheduler | IPVS 커널 모듈 필요, Service API edge case 정합성 문제, deprecated | 비선정 |
| eBPF replacement | `kube-proxy` 자체를 대체하고 kernel eBPF 프로그램으로 Service 처리 | ClusterIP, NodePort, LoadBalancer, 관측성을 통합 가능 | CNI/커널/운영 모델까지 함께 바뀜 | 현재 제외 |

---

## 9) `iptables`를 어떻게 봤는가

`iptables` 모드는 현재 Linux에서 `kube-proxy`의 기본 모드다.

- `Service`와 `EndpointSlice`를 바탕으로 netfilter 규칙을 생성한다.
- 규칙 기반으로 `Service ClusterIP -> Pod endpoint` 전달을 구현한다.
- 가장 오래 사용되어 왔고, 운영 이해도와 자료가 가장 많다.

기술적으로는 `KUBE-SERVICES` 체인 상단에 Service별 규칙이 쌓이고, 각 Service 규칙이 다시 endpoint 체인으로 분기한다. 이 구조는 이해하기 쉽지만, Service 수가 커질수록 첫 패킷이 검사해야 하는 규칙 수도 늘어난다.

상세 내용은 [K8S-007 iptables 심화](K8S-007-kube-proxy-iptables-deep-dive.md)에서 다룬다.

---

## 10) `nftables`를 어떻게 정리했는가

Kubernetes 공식 문서와 블로그 기준으로 `nftables` 모드는 stable이며, Linux `kube-proxy`의 공식 대안 중 하나다.

- 성능과 확장성 측면에서 유리하다.
- 특히 큰 규모에서 rule 관리가 개선된다.
- 다만 Linux kernel 5.13+, `nft` userspace 도구 버전, 운영 익숙함이 함께 필요하다.

기술적으로는 상단 규칙을 Service 개수만큼 나열하는 대신, `Service IP + protocol + port` 조합을 `verdict map`으로 조회한다. Kubernetes 블로그는 이 구조를 사실상 O(1)에 가까운 dispatch 경로로 설명하며, 큰 클러스터에서 첫 패킷 latency와 규칙 갱신 효율이 개선된다고 설명한다.

다만 현재 설계에서는 `nftables`를 실제 선택 후보로 검토하지 않았다. 따라서 이 문서에서는 "공식적으로 존재하는 대안"으로만 정리하고, 현재 기준선이나 후속 우선순위로 올리지는 않는다.

상세 내용은 [K8S-008 nftables 참고 메모](K8S-008-kube-proxy-nftables-deep-dive.md)에서 다룬다.

---

## 11) `ipvs`를 어떻게 봤는가

`ipvs`는 Linux kernel의 IP Virtual Server 기능을 활용하는 `kube-proxy` 모드다.

- hash table 기반으로 동작한다.
- 한때 `iptables`보다 더 나은 rule synchronization과 throughput을 제공하는 실험적 대안으로 도입됐다.
- round robin, least connection, source hashing, maglev hashing 등 여러 scheduler를 제공한다.

하지만 Kubernetes 공식 문서는 현재 `ipvs` 모드를 deprecated로 표시한다. 이유는 IPVS API가 Kubernetes Service API와 잘 맞지 않아 edge case를 완전히 구현하지 못했기 때문이다.

상세 내용은 [K8S-009 ipvs 심화](K8S-009-kube-proxy-ipvs-deep-dive.md)에서 다룬다.

---

## 12) eBPF replacement를 어떻게 봤는가

eBPF replacement는 `kube-proxy`를 유지하는 대신, eBPF 기반으로 `Service` 데이터플레인을 새로 구현하는 방향이다.

- `Service ClusterIP` 처리
- NodePort / LoadBalancer 처리
- 관측성
- 일부 정책 집행

즉 이건 `iptables`와 `nftables`처럼 같은 `kube-proxy` 내부 모드 중 하나를 고르는 일이 아니라, **Service 데이터플레인 구현 주체 자체를 바꾸는 선택**에 가깝다.

현재 구조에서는 이 접근이 지나치게 많은 축을 동시에 잠근다고 판단했다.

상세 내용은 [K8S-010 eBPF replacement 메모](K8S-010-ebpf-service-dataplane-note.md)에서 다룬다.

---

## 13) 현재 비교의 결론

현재 비교 결과는 다음과 같다.

- `kube-proxy`는 유지한다.
- 초기 모드는 `iptables`를 기준선으로 둔다.
- `ipvs`는 현재 deprecated 방향이므로 채택하지 않는다.
- eBPF replacement는 현재 단계에서 제외한다.
- `nftables`는 존재를 인지하는 참고 대안으로만 남긴다.

즉 이번 선택의 핵심은 "지금 당장 최고 성능 구현"이 아니라, **Service 데이터플레인을 가장 보수적이고 설명 가능한 기준선으로 먼저 고정하는 것**이다.

최종 결정은 [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md)에 기록한다.

---

## 14) 참고 자료

- Kubernetes Virtual IPs and Service Proxies: https://kubernetes.io/docs/reference/networking/virtual-ips/
- Service ClusterIP allocation: https://kubernetes.io/docs/concepts/services-networking/cluster-ip-allocation/
- kube-proxy configuration API: https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/
- Kubernetes v1.33 release: https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/
- NFTables mode for kube-proxy: https://kubernetes.io/blog/2025/02/28/nftables-kube-proxy/
