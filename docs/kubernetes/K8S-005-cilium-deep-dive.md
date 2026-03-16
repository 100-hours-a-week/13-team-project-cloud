# K8S-005: Cilium 심화 - 왜 장기 고도화형 후보인가

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-08 |
| 상태 | 작성 완료 |
| 문서 역할 | Cilium의 eBPF 운영 모델, 강점, 현재 비선정 이유 정리 |
| 관련 문서 | [K8S-002 CNI 비교 연구](K8S-002-cni-comparison-study.md), [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md) |

---

## 1) 문서 목적

이 문서는 `Cilium`을 "기능은 좋지만 복잡하다" 수준에서 끝내지 않고, **왜 현재 단계에서는 장기 고도화형 후보로 분류했는지**를 정리하기 위해 작성했다.

---

## 2) Cilium을 어떻게 이해했는가

Cilium 공식 문서는 각 노드에 `cilium-agent`를 배치하고, 이 에이전트가 Linux 커널에 eBPF 프로그램을 설치해 네트워킹 작업과 보안 규칙을 수행한다고 설명한다.

또한 Cilium은 다음 축을 함께 가져갈 수 있다.

- eBPF 기반 네트워킹
- 보안 정책 집행
- `kube-proxy replacement`
- `Hubble` 기반 observability

즉 Cilium은 단순 CNI라기보다, **서비스 처리와 네트워크 관측까지 통합 가능한 네트워크 플랫폼**에 가깝다.

---

## 3) Cilium의 실제 강점

### 3.1. eBPF 중심 통합 모델

`kube-proxy replacement`를 통해 `Service` 데이터플레인까지 Cilium이 담당할 수 있다.

이 방향은 다음 요구가 커질수록 강력하다.

- 고성능 `Service` 처리
- `iptables` 기반 규칙 관리 부담 축소
- 네트워크 계층 통합

### 3.2. observability가 강하다

`Hubble`은 Cilium의 강한 장점 중 하나다. 네트워크 흐름을 더 풍부하게 볼 수 있으므로, 단순 연결성보다 관측성이 중요한 단계에서는 매우 유리하다.

### 3.3. 장기적 기술 방향성이 분명하다

현재 Kubernetes 생태계에서 eBPF 기반 네트워킹은 장기적으로 계속 중요한 선택지다. 따라서 장기 고도화를 본다면 Cilium은 매우 유효하다.

---

## 4) 그런데 왜 지금 1차 선택은 아닌가

### 4.1. 너무 많은 축을 한 번에 잠근다

현재 단계에서 Cilium을 선택하면 다음이 함께 묶인다.

- CNI
- `Service` 데이터플레인
- 정책 엔진
- observability

우리는 지금 이 축들을 의도적으로 분리해서 설계하려 한다.

### 4.2. 커널과 eBPF 운영 이해가 전제된다

Cilium 공식 문서는 Linux kernel, eBPF 기능, 필요한 권한과 시스템 요구사항을 명확히 설명한다.

즉 Cilium은 애플리케이션 레벨 설정만 이해하면 되는 도구가 아니라, **운영자가 커널과 eBPF 계층까지 책임질 준비가 있을 때 더 잘 맞는 도구**다.

### 4.3. 현재 규모에서는 장점보다 도입 복잡도가 먼저 체감될 수 있다

지금은 `Service` 수, 정책 수, 관측 요구가 아직 폭발하기 전 단계다.

이 시점에서는 Cilium의 장점이 즉시 실익으로 연결되기보다, 운영 개념 수 증가와 장애 분석 난이도 증가로 먼저 체감될 가능성이 높다.

---

## 5) Cilium이 더 잘 맞는 시점

아래 조건이 생기면 `Cilium`은 강한 재검토 대상이 된다.

1. `kube-proxy replacement`가 실제로 필요할 때
2. 네트워크 observability가 운영 핵심 요구가 될 때
3. eBPF 기반 데이터플레인을 조직적으로 운영할 준비가 생길 때
4. 정책, 서비스 처리, 관측을 한 축에서 통합 관리할 가치가 커질 때

즉 `Cilium`은 "지금은 아니다"이지, "우리와 맞지 않는다"가 아니다.

---

## 6) 이번 검토에서 얻은 결론

이번 비교에서 `Cilium`은 가장 고도화된 후보였다. 그러나 현재 단계에서는 다음 이유로 1차 기준선에서 제외했다.

- CNI의 책임 범위를 지나치게 넓힌다.
- `Service` 데이터플레인과 observability까지 같이 결정하게 된다.
- 소수 운영 인원이 감당해야 할 기술 개념이 빠르게 늘어난다.

따라서 `Cilium`은 현재 기준선보다, **장기 고도화 목표가 분명해졌을 때 다시 들어올 후보**로 정리한다.

---

## 7) 참고 자료

- Cilium Overview: https://docs.cilium.io/en/stable/overview/intro/
- Cilium System Requirements: https://docs.cilium.io/en/stable/operations/system_requirements.html
- Cilium kube-proxy replacement: https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
- Hubble Overview: https://docs.cilium.io/en/stable/observability/hubble/
