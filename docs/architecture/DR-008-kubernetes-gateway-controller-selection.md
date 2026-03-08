# DR-008: Kubernetes Gateway 컨트롤러로 Traefik 채택

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md), [DR-007 트래픽 진입점 API 선정](DR-007-kubernetes-gateway-api-selection.md) |
| 주요 목표 | 외부 진입 제어 계층의 Gateway 컨트롤러 선정 및 선택 근거 기록 |

---

## 1) 결정

`DR-007`에서 트래픽 진입점 API로 `Gateway API` 채택을 확정했다. 본 문서에서는 그 전제 위에서 Kubernetes 외부 진입 계층의 Gateway 컨트롤러로 `Traefik`을 채택한다.

Traefik은 Kubernetes `Gateway API` 구현체이며, `HTTPRoute` core와 일부 확장 기능, `GRPCRoute`, 그리고 실험 채널의 `TCPRoute`, `TLSRoute`까지 지원한다. 또한 Helm 차트 사용 시 CRD와 RBAC 관리가 단순하고, `kubernetesGateway` provider 활성화만으로 Gateway API 구성을 시작할 수 있다.

---

## 2) 배경

현재 클러스터는 소수 운영 인원 기준으로 설계되며, 초기 외부 진입 경로와 라우트 수가 많지 않다.

- 외부 L4 진입: 별도 External LB
- 클러스터 내부 L7 진입: Gateway 컨트롤러
- 내부 서비스 분산: Kubernetes `Service`와 `kube-proxy`/CNI 데이터플레인

Kubernetes에서 `kube-proxy`는 Service의 virtual IP 메커니즘을 구현하며, 각 노드에서 Service와 `EndpointSlice`를 watch해 패킷 전달 규칙을 구성한다. `EndpointSlice`는 Service 뒤의 backend Pod IP를 효율적으로 추적하기 위한 Kubernetes 표준 메타데이터 객체다.

따라서 지금 Gateway 계층의 핵심 요구는 "고급 서비스 메시 수준의 제어"보다 "명확한 외부 진입 제어와 낮은 운영 복잡도"에 가깝다.

---

## 3) 고려한 대안

검토 대상은 다음 세 가지였다.

- `Traefik`
- `NGINX Gateway Fabric`
- `Envoy Gateway`

세 구현체 모두 사용자 관점에서는 선언형 YAML 기반으로 보이지만, 내부 운영 모델은 다르다.

- `Traefik`: Kubernetes 리소스를 직접 감시해 자체 동적 구성을 갱신
- `NGINX Gateway Fabric`: control plane이 Gateway API 리소스를 NGINX 설정으로 번역하고, data plane의 NGINX Agent에 gRPC로 전달해 적용
- `Envoy Gateway`: Gateway API를 구현하고 확장 기능을 제공하지만, control plane/data plane 분리와 별도 내부 모델 이해가 전제

---

## 4) 선택 근거

### 4.1. Gateway API 표준 정합성

`Gateway API`를 트래픽 진입점 표준으로 채택한 방향과 가장 자연스럽게 맞는다. Traefik은 Gateway API 표준 `v1.4.0`을 지원하며 `HTTPRoute` core를 완전히 지원한다.

이는 현재 설계가 원하는 역할 분리형 리소스 모델(`GatewayClass` / `Gateway` / `HTTPRoute`)과 직접 연결된다.

### 4.2. 현재 규모에 적합한 운영 단순성

현재 단계에서는 라우트 수가 적고, 다중 Gateway 격리나 분리형 데이터플레인 운영보다 "빠르게 이해되고 운영 가능한 구조"가 더 중요하다.

`NGINX Gateway Fabric`은 control plane, data plane, NGINX Agent, gRPC 구성 전달, 설정 파일 반영과 reload라는 더 많은 내부 구성요소를 가진다. 반면 Traefik은 Kubernetes 리소스를 직접 감시하고 내부 동적 구성을 갱신하는 구조라 초기 운영 모델이 더 단순하다.

### 4.3. 현재 요구 대비 적정 복잡도

우리의 현재 요구는 "외부 요청을 올바른 Kubernetes Service로 전달하는 L7 진입점"이다.

내부 서비스 분산과 endpoint 선택은 이미 `Service + kube-proxy + CNI` 축에서 해결된다. 따라서 Gateway 계층에서 별도의 복잡한 분리형 제어 모델이나 과도한 확장성을 먼저 도입할 필요가 낮다.

현재 규모에서는 고급 정책 엔진보다 운영 단순성과 명확한 책임 분리가 더 큰 가치다.

### 4.4. Gateway API 기반 TLS 구성과의 정합성

Traefik은 `Gateway API`의 HTTPS listener에서 `certificateRefs`를 통해 TLS Secret을 참조하는 구성을 자연스럽게 처리할 수 있다.

Traefik 공식 문서는 built-in Let's Encrypt integration이 `IngressRoute`에는 동작하지만, `Gateway API listeners`에 대해서는 자동 발급을 하지 않으며, 이 경우 `cert-manager` 같은 별도 Certificate Controller 사용을 권장한다.

즉 현재 설계에서는 "Traefik이 인증서까지 직접 다 관리한다"가 아니라, **Gateway API 구현체로서 TLS 종료와 라우팅을 담당하고, 인증서 lifecycle은 별도 controller와 조합할 수 있다**는 점이 더 중요하다.

---

## 5) 선택하지 않은 이유

### 5.1. NGINX Gateway Fabric

`NGINX Gateway Fabric`은 Gateway API 구현체로서 충분히 유효한 대안이다.

다만 control plane이 Kubernetes API를 watch하고, Gateway별 전용 NGINX data plane을 동적으로 만들며, Agent가 gRPC로 받은 설정을 파일로 쓰고 reload하는 구조다. 이 구조는 분명한 운영 경계와 장애 격리 장점이 있지만, 현재 규모에서는 구성요소 증가와 내부 동작 이해 부담이 먼저 커질 수 있다.

### 5.2. Envoy Gateway

`Envoy Gateway`는 Gateway API를 구현하고, Envoy 고유의 강력한 트래픽 관리 기능을 쉽게 활용하게 해 주는 방향의 제품이다.

보안 정책, OIDC/JWT, rate limiting, retry, circuit breaking, observability 등 확장 기능이 풍부하다. 그러나 현재 설계에서는 그러한 고급 기능을 즉시 활용할 요구가 명확하지 않고, 초기 운영 관점에서는 도입 복잡도 대비 실익이 작다.

---

## 6) 결과

초기 Gateway 표준은 다음과 같이 고정한다.

- External LB: 클라우드 외부 진입점
- Traffic Entry API: Kubernetes `Gateway API`
- Gateway Controller: `Traefik`
- Backend dispatch: Kubernetes `Service + kube-proxy/CNI` 데이터플레인

이 구조에서 Gateway 계층은 외부 요청을 어떤 Service로 보낼지 결정하고, Service 데이터플레인은 해당 Service를 실제 Pod endpoint로 연결한다. 역할이 분리되어 있어 설계 설명과 운영 책임 구분이 명확하다.

---

## 7) 장단점

장점

- `Gateway API` 표준과 직접 정합된다.
- 현재 규모에 적합한 낮은 운영 복잡도를 유지할 수 있다.
- Helm 기반 초기 도입이 단순하다.
- 동적 구성 반영과 `Gateway API` 기반 TLS listener 구성이 자연스럽다.

단점

- `Gateway API` 기준의 인증서 발급 및 갱신은 `cert-manager` 같은 별도 구성과 함께 설계해야 한다.
- 향후 고급 정책, 분리형 운영, 복잡한 멀티테넌시 요구가 증가하면 재검토가 필요하다.

---

## 8) 후속 검토 항목

1. `Gateway API` 기준 인증서 lifecycle을 `cert-manager`로 운영하는 방식 상세화
2. Gateway replica 증가 시 외부 LB 헬스체크 및 readiness 정책 검토
3. 라우트 수, 정책 수, 멀티테넌시 요구가 증가할 경우 `NGINX Gateway Fabric` 또는 `Envoy Gateway` 재평가
4. Service 데이터플레인 측면에서 `kube-proxy iptables / nftables / eBPF replacement` 비교를 별도 ADR로 관리

---

## 9) 참고 자료

- Traefik Kubernetes Advanced: https://doc.traefik.io/traefik/v3.6/expose/kubernetes/advanced/
- Traefik Setup on Kubernetes: https://doc.traefik.io/traefik/master/setup/kubernetes/
