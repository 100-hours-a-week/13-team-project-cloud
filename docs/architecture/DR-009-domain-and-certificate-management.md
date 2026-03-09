# DR-009: 도메인 및 인증서 관리 방식 선정

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md), [DR-007 트래픽 진입점 API 선정](DR-007-kubernetes-gateway-api-selection.md), [DR-008 Kubernetes Gateway Controller 선정](DR-008-kubernetes-gateway-controller-selection.md) |
| 주요 목표 | 외부 도메인, TLS 종료 위치, 인증서 발급 및 갱신 방식 기준선 확정 |

---

## 1) 결정

본 설계에서는 TLS 종료 위치를 `Traefik`으로 두고, 인증서 발급 및 갱신은 초기 단계부터 `cert-manager`가 담당한다.

초기 ACME 검증 방식은 `HTTP-01`을 기준으로 두고, wildcard 인증서나 DNS 자동화 요구가 생기면 `DNS-01`을 후속 확장 방식으로 검토한다.

---

## 2) 배경

현재 외부 진입 구조는 다음과 같다.

- 외부 L4 진입: `public NLB`
- 클러스터 내부 L7 진입: `Traefik`
- 라우팅 API: `Gateway API`

이 구조에서 외부 LB는 연결을 클러스터로 전달하는 L4 역할에 집중하고, 실제 HTTPS 세션 종료와 도메인별 라우팅은 Gateway 계층이 담당하는 편이 설계상 더 자연스럽다.

Traefik 공식 문서는 built-in Let's Encrypt integration이 `IngressRoute`에는 동작하지만, `Gateway API listeners`에 대해서는 자동 발급하지 않으며 `cert-manager` 같은 별도 controller 사용을 안내한다.

따라서 현재 구조에서는 초기부터 `Traefik`은 TLS 종료와 라우팅을 맡고, 인증서 lifecycle은 `cert-manager`가 담당하는 형태가 더 정합적이다.

---

## 3) 선택 기준

이번 선택은 아래 기준으로 평가한다.

### 3.1. TLS 종료 위치가 현재 외부 진입 구조와 맞는가

현재 구조는 외부 LB와 Gateway 계층의 책임을 분리하고 있으므로, TLS 종료도 이 책임 구조와 일치해야 한다.

### 3.2. 초기 인증서 운영 복잡도를 과도하게 늘리지 않는가

현재 단계에서는 인증서 발급과 갱신을 가능한 한 단순하게 운영할 수 있어야 한다.

### 3.3. Gateway 다중화 시 운영 모델이 무너지지 않는가

초기에는 단순성이 중요하지만, replica 증가나 HA 요구가 생길 때 인증서 전략을 분리할 수 있어야 한다.

### 3.4. 이후 자동화 확장 경로가 선명한가

초기 단순성만이 아니라, 이후 `cert-manager` 기반 운영으로 전환 가능한지 봐야 한다.

---

## 4) 고려한 대안

검토 대상은 다음과 같았다.

- 외부 LB에서 TLS 종료
- `Traefik`에서 TLS 종료
- 애플리케이션에서 TLS 종료

인증서 관리 방식은 아래 두 축을 함께 검토했다.

- `Traefik` 내장 ACME 자동화
- `cert-manager` 기반 인증서 관리

---

## 5) 선택 근거

### 5.1. TLS 종료는 `Traefik`에서 하는 편이 현재 구조와 가장 잘 맞는다

현재 구조에서 외부 LB는 L4 진입점이고, `Traefik`은 Gateway 계층의 L7 진입점이다. 따라서 HTTPS 세션 종료와 인증서 제시는 `Traefik`이 담당하는 편이 역할 분리에 맞다.

즉 구조는 다음과 같다.

- 사용자
- `public NLB`
- `Traefik`
- Kubernetes `Service`
- Pod

이 구조에서 외부 LB는 연결 전달만 담당하고, 실제 도메인별 HTTPS 처리는 `Traefik`이 수행한다.

### 5.2. `Gateway API` 기준에서는 `cert-manager`가 더 정합적이다

Traefik 공식 문서는 built-in Let's Encrypt integration이 `IngressRoute`와는 다르게 `Gateway API listeners`에 대해서는 자동 발급을 하지 않는다고 설명한다. 대신 `cert-manager` 또는 다른 certificate controller를 사용해 HTTPS listener의 `certificateRefs`가 참조할 Secret을 생성하는 구성을 안내한다.

따라서 현재 구조에서는 `Traefik`의 내장 ACME보다, 초기부터 `cert-manager`를 인증서 lifecycle의 기준선으로 두는 편이 더 자연스럽다.

### 5.3. 초기 ACME 검증 방식은 `HTTP-01`을 우선 기준으로 둔다

`HTTP-01`은 인증기관이 정해진 HTTP 경로에 접근해 도메인 소유를 검증하는 방식이다.

현재처럼 공개 도메인 수가 많지 않고, `public NLB -> Traefik Gateway` 구조가 단순한 단계에서는 `HTTP-01`이 가장 이해하기 쉽고 운영 개념도 적다.

이 구성을 위해서는 Gateway에 port 80 HTTP listener가 필요하며, `cert-manager`는 Gateway API용 임시 `HTTPRoute`를 생성해 challenge를 처리한다.

### 5.4. `DNS-01`은 후속 확장 방식으로 둔다

`DNS-01`은 ACME 검증을 위해 `_acme-challenge.<domain>` TXT 레코드를 DNS에 생성하는 방식이다. 예를 들어 Route53을 사용할 경우, 컨트롤러가 DNS provider API를 호출해 TXT 레코드를 자동으로 만들고 검증 후 제거할 수 있다.

이 방식은 wildcard 인증서나 더 복잡한 구조에 유리하지만, 현재 단계에서는 `HTTP-01`보다 운영 개념이 한 단계 더 많다. 따라서 초기 기준선은 `HTTP-01`, 후속 확장은 `DNS-01`으로 둔다.

---

## 6) 선택하지 않은 이유

### 6.1. 외부 LB에서 TLS 종료

외부 LB에서 TLS를 종료하면 클라우드 네트워크 계층에 인증서 책임이 올라간다. 현재 설계는 외부 LB와 Gateway 계층의 책임을 분리하려 하므로, 이 구조와는 맞지 않는다.

### 6.2. `Traefik` 내장 ACME 자동화

`Traefik`은 자체 ACME 기능을 제공하지만, 공식 문서 기준으로 이 자동화는 `IngressRoute`에는 적용되더라도 `Gateway API listeners`에 대해 자동 발급을 하지 않는다.

현재 구조는 `Gateway API`를 기준선으로 채택했으므로, 이 방식은 현재 API 선택과 정합성이 떨어진다.

### 6.3. 애플리케이션에서 TLS 종료

애플리케이션별로 인증서와 HTTPS 처리를 분산시키면 운영 책임이 분산되고, Gateway 계층의 역할이 약해진다. 현재 구조에서는 적절하지 않다.

---

## 7) 결과

초기 기준선은 다음과 같이 둔다.

- External LB listener: `TCP` pass-through
- TLS termination: `Traefik`
- Initial certificate management: `cert-manager`
- Initial ACME challenge: `HTTP-01`
- Expansion path: `DNS-01` 및 wildcard 검토

즉 초기부터 Gateway는 TLS 종료와 라우팅에 집중하고, 인증서 lifecycle은 `cert-manager`가 담당한다.

---

## 8) 장단점

장점

- 현재 외부 진입 구조와 역할 분리가 잘 맞는다.
- `Gateway API`와 `Traefik` 조합에 맞는 인증서 운영 모델이다.
- 초기 HTTPS 도입과 이후 확장 경로가 일관된다.

단점

- Gateway 다중화 시 인증서 관리 모델을 재검토해야 한다.
- `DNS-01` 기반 자동화는 후속 설계가 필요하다.
- `cert-manager` 운영 컴포넌트를 초기부터 함께 관리해야 한다.

---

## 9) 후속 검토 항목

1. `cert-manager`의 Gateway API HTTP-01 solver 구성 방식 상세화
2. Route53 기반 `DNS-01` 자동화 필요 여부 검토
3. wildcard 인증서 필요 여부 검토
4. 인증서 secret 관리 및 rotation 운영 절차 정리

---

## 10) 최종 판단 문장

> 본 설계에서는 TLS 종료 위치를 `Traefik`으로 두고, 인증서 발급 및 갱신은 초기 단계부터 `cert-manager`가 담당한다. 현재 구조는 `Gateway API`를 기준선으로 채택했으며, Traefik 공식 문서도 built-in Let's Encrypt integration이 `Gateway API listeners`에 대해 자동 발급하지 않는다고 안내한다. 따라서 `Traefik`은 TLS 종료와 라우팅에 집중하고, 인증서 lifecycle은 별도 controller가 담당하는 구성이 현재 구조와 가장 잘 맞는다. 초기 ACME 검증은 `HTTP-01`을 우선 기준으로 두고, wildcard 또는 DNS 자동화 요구가 생기면 `DNS-01`을 후속 확장 방식으로 검토한다.

---

## 11) 참고 자료

- Traefik Kubernetes Advanced: https://doc.traefik.io/traefik/v3.6/expose/kubernetes/advanced/
- Traefik Setup on Kubernetes: https://doc.traefik.io/traefik/master/setup/kubernetes/
- cert-manager concepts: https://cert-manager.io/docs/concepts/
- cert-manager HTTP01 with Gateway API: https://cert-manager.io/docs/configuration/acme/http01/
- cert-manager Gateway usage: https://cert-manager.io/docs/usage/gateway/
- ACME challenge types: https://letsencrypt.org/docs/challenge-types/
