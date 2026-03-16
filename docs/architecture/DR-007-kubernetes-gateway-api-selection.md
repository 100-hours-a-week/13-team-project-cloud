# DR-007: 트래픽 진입점 API 선정 - Ingress vs Gateway API

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 승인됨 |
| 적용 단계 | v3 (Kubernetes 전환) |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](../kubernetes/K8S-001-final-design.md) |
| 주요 목표 | 클러스터 외부에서 들어오는 HTTP(S)/WebSocket 트래픽의 Kubernetes 표현 모델 선정 |

---

## 1) 결정

본 설계에서는 클러스터 외부에서 들어오는 HTTP(S)/WebSocket 트래픽의 Kubernetes 표현 모델로 `Ingress`가 아니라 `Gateway API`를 채택한다.

현재 요구사항은 단순하며 `Ingress`와 `Gateway API` 모두 필요한 기능을 제공할 수 있다. 그러나 `Gateway API` 역시 최소 구성으로 충분히 단순하게 시작할 수 있고, Kubernetes 공식 문서도 `Ingress` API가 frozen 상태이며 새로운 기능은 `Gateway API` 쪽에 추가된다고 안내한다. 또한 Kubernetes는 `Gateway API`를 `Ingress`의 successor로 설명하고 있다.

따라서 새로 시작하는 현재 구조에서 굳이 이전 API 모델을 선택할 이유가 낮다고 판단해 `Gateway API`를 표준으로 채택한다.

---

## 2) 배경

신규 셀프 매니지드 Kubernetes 클러스터는 application layer를 먼저 클러스터화하며, 현재 외부 진입점 요구사항은 비교적 단순하다.

- 외부 사용자 트래픽은 주로 `backend`로 유입
- `recommend`는 내부 서비스 간 통신 대상
- 내부 서비스 간 로드밸런싱은 Kubernetes `Service(ClusterIP)`가 담당
- HTTP(S), WebSocket 진입점만 우선 표준화하면 된다

이번 결정의 목적은, 클러스터 외부에서 들어오는 트래픽을 어떤 Kubernetes API 모델로 표현할지 정하는 것이다.

중요한 점은 이번 판단이 "지금 복잡하니 Gateway API가 필요하다"는 전제에서 출발하지 않는다는 것이다. 오히려 현재 요구는 단순하며, 바로 그렇기 때문에 `Gateway API`도 충분히 단순하게 시작할 수 있는지를 확인하는 것이 핵심이다.

---

## 3) 현재 서비스 기준의 전제

### 3.1. 현재 진입점 요구사항

현재 외부 공개 트래픽은 사실상 아래 한 가지가 핵심이다.

- `api.example.com -> backend`

즉, 현재만 보면 단순한 호스트 기반 라우팅 하나면 충분하다.

### 3.2. 내부 서비스 로드밸런싱은 별도 문제다

내부 서비스 간 통신은 Ingress나 Gateway가 아니라 Kubernetes `Service` 계층이 담당한다.

예를 들어:

- `backend -> recommend`

같은 통신은 다음 구조로 처리한다.

- `backend Pod -> recommend Service(ClusterIP) -> recommend Pods`

따라서 이번 이슈는 "내부 로드밸런서가 필요하냐"가 아니라, 외부에서 클러스터로 들어오는 입구를 어떤 API 모델로 표현할지에 대한 결정이다.

---

## 4) 비교 기준

이번 선택은 아래 기준으로 평가한다.

### 4.1. 현재 단순한 요구사항을 과도한 복잡도 없이 표현할 수 있는가

현재 요구는 매우 단순하다.

- 호스트 하나
- 서비스 하나
- 기본 HTTPS 종단

따라서 지금 필요한 수준을 최소 리소스로 표현할 수 있는가가 중요하다.

### 4.2. 새로 시작하는 구조에서 굳이 이전 API 모델을 선택할 이유가 있는가

둘 다 원하는 기능을 제공한다면, 더 이상 권장되지 않는 모델을 새로 채택할 필요가 있는지 따져봐야 한다.

### 4.3. 특정 구현체에 조기 종속되지 않는가

새로 시작하는 구조에서는 특정 컨트롤러 annotation이나 구현 방식에 빨리 종속되는 것이 장기적으로 불편할 수 있다.

### 4.4. 공식 권장 방향과 장기 일관성에 부합하는가

이 항목은 주된 선정 사유를 보강하는 기준이다. Kubernetes 공식 문서가 현재 어떤 방향을 권장하는지도 함께 본다.

---

## 5) Ingress 검토

### 5.1. 장점

현재 요구사항만 보면 `Ingress`는 매우 자연스러운 선택이다.

- 단일 HTTP 진입점을 표현하기 쉽다
- `host/path -> Service` 모델이 직관적이다
- 리소스 개념이 상대적으로 단순하다

즉, `api.example.com -> backend` 정도의 단순 요구만 놓고 보면 `Ingress`는 충분하다.

### 5.2. 선택하지 않은 이유

1. `Ingress`는 기본 모델이 단순한 대신, 조금만 기능이 늘어나도 컨트롤러별 annotation과 구현 차이에 의존하는 경우가 많다.
2. 새로 시작하는 현재 구조에서 굳이 frozen 상태의 API를 기준선으로 채택할 필요가 낮다.
3. 지금 필요한 기능이 단순하더라도, 같은 수준의 단순성을 `Gateway API`에서도 충분히 확보할 수 있다.

즉, 이번 판단은 "`Ingress`가 기능적으로 부족해서"가 아니라 "`Gateway API`도 충분히 단순한데 굳이 `Ingress`를 선택할 이유가 약하다"에 가깝다.

---

## 6) Gateway API 검토

### 6.1. 선택 근거

`Gateway API`는 현재 기준에서 다음 장점이 있다.

1. 단순한 요구도 최소 구성으로 충분히 단순하게 표현할 수 있다.

- `GatewayClass` 1개
- 공개용 `Gateway` 1개
- `backend`용 `HTTPRoute` 1개

2. `Gateway`와 `HTTPRoute`로 역할을 나누는 모델이 기본이며, 특정 구현체 annotation에 조기 종속되지 않기 쉽다.
3. Kubernetes 공식 문서 기준으로 `Ingress`의 successor 방향과 맞는다.

### 6.2. 비용

`Gateway API`는 `Ingress`보다 리소스 개념이 더 나뉘어 있어 처음 접할 때 추상화가 한 단계 더 많다.

하지만 현재 서비스 기준에서는 이 비용이 과도하지 않다. 고급 기능을 모두 쓰는 것이 아니라 최소 구성만으로 시작하면 되기 때문이다.

즉, 이번 단계의 `Gateway API`는 복잡한 플랫폼 도입이 아니라 권장 모델을 최소 구성으로 채택하는 선택이다.

---

## 7) 결과

초기 트래픽 진입점 표준은 다음과 같이 고정한다.

- Traffic Entry API: `Gateway API`
- External entry responsibility: 별도 External LB
- L7 routing responsibility: Gateway API 구현체
- Internal service load balancing: Kubernetes `Service`

구현체 선택은 후속 `DR-008`에서 결정한다.

---

## 8) 초기 운영 방향

1. 초기에는 최소 구성만 사용한다.

- 공개용 `Gateway` 1개
- 공개용 `Listener` 1개
- `backend`로 연결되는 `HTTPRoute` 1개

2. 내부 서비스 간 로드밸런싱은 계속 `Service`로 처리한다.
3. 구현체 세부 비교는 후속 결정으로 분리한다.

---

## 9) 최종 판단 문장

> 현재 서비스의 외부 진입점 요구사항은 단순하며, `Ingress`와 `Gateway API` 모두 필요한 기능을 제공할 수 있다. 그러나 `Gateway API`도 최소 구성으로 충분히 단순하게 시작할 수 있고, Kubernetes 공식 문서 역시 `Ingress` API가 frozen 상태이며 `Gateway API`를 successor 방향으로 안내하고 있다. 따라서 새로 시작하는 현재 구조에서 굳이 `Ingress`를 선택할 이유가 낮다고 판단해 `Gateway API`를 채택한다.

---

## 10) 참고 자료

- Kubernetes Ingress: https://kubernetes.io/docs/concepts/services-networking/ingress/
- Kubernetes Gateway API: https://kubernetes.io/docs/concepts/services-networking/gateway/
- Gateway API Getting Started: https://gateway-api.sigs.k8s.io/guides/getting-started/
