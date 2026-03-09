# K8S-011: Kubernetes 용어와 역할 정리

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-03-09 |
| 상태 | 작성 중 |
| 문서 역할 | Kubernetes 관련 문서에서 반복 등장하는 핵심 용어의 의미와 역할을 표로 정리 |
| 관련 문서 | [K8S-001 Kubernetes 최종 설계서](K8S-001-final-design.md), [DR-006 Kubernetes CNI 선정](../architecture/DR-006-kubernetes-cni-selection.md), [DR-010 Service 데이터플레인 전략 선정](../architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md) |

---

## 1) 문서 목적

이 문서는 Kubernetes 설계 문서에서 반복 등장하는 용어를 `무엇인지`, `무슨 역할인지`, `설계 기준에서 어디에 위치하는지` 기준으로 빠르게 확인하기 위한 참고 문서다.

설계 기준은 다음을 전제로 읽는다.

- Kubernetes 대상: application workload, monitoring workload
- Kubernetes 비대상: stateful data workload

---

## 2) 클러스터 / 노드 / 실행 계층

| 용어 | 무엇인지 | 역할 | 설계 기준에서의 위치 |
|------|------|------|------|
| `kubeadm` | 업스트림 Kubernetes 부트스트랩 도구 | control plane과 worker를 초기화하고 조인 절차를 제공 | 클러스터 배포 기준선 |
| `control plane` | Kubernetes 관리 계층 | API server, scheduler, controller-manager 등 클러스터 제어 담당 | 설계 기준은 `single control plane` |
| `data plane` | 실제 트래픽과 실행이 흐르는 계층 | control plane이 정한 상태를 바탕으로 실제 요청 전달과 workload 실행을 담당 | worker node, kube-proxy, CNI, Traefik 등이 여기에 걸쳐 있음 |
| `worker node` | 실제 workload가 실행되는 노드 | Pod를 실행하고 application/monitoring workload를 담음 | app/monitoring 실행 노드 |
| `kubelet` | 각 노드에서 동작하는 agent | Pod 명세를 받아 컨테이너 실행 상태를 유지 | 모든 node에 필요 |
| `containerd` | 컨테이너 런타임 | 실제 컨테이너를 실행 | 런타임 기준선 |
| `Namespace` | 클러스터 내부 논리 구획 | workload, 권한, 설정 범위를 분리 | `infra-system`, `monitoring-system`, `dev-app`, `prod-app` |

---

## 3) 네트워크 / 트래픽 / 이름 해석

| 용어 | 무엇인지 | 역할 | 설계 기준에서의 위치 |
|------|------|------|------|
| `CNI` | Container Network Interface 구현체 | Pod IP 할당과 Pod-to-Pod 네트워크 연결 담당 | 설계 기준은 `Flannel` |
| `Flannel` | 단순한 Kubernetes CNI | 노드 간 Pod 네트워크를 제공 | 현재 Pod 네트워크 기준선 |
| `Service` | Pod 집합 앞에 두는 가상 네트워크 객체 | 고정된 DNS 이름과 `ClusterIP` 제공 | backend/recommend 같은 app 접근 단위 |
| `Service 데이터플레인` | Service로 들어온 요청을 실제 Pod로 보내는 전달 계층 | `Service ClusterIP -> endpoint Pod` 트래픽 전달 담당 | 설계 기준에서는 `kube-proxy`가 담당 |
| `kube-proxy` | Kubernetes Service 데이터플레인 구현체 | `Service ClusterIP -> Pod endpoint` 전달 규칙 생성 | 현재 모드는 `iptables` |
| `CoreDNS` | 클러스터 DNS 서버 | `*.svc.cluster.local` 이름 해석, 외부 DNS 질의 포워딩 | 내부 서비스 이름 해석, 외부 데이터 DNS 질의 중계 |
| `Gateway API` | Kubernetes 트래픽 진입 모델 | 외부 요청을 어떤 listener와 route로 받을지 표현 | 외부 진입 리소스 모델 |
| `Traefik` | Gateway API를 구현하는 실제 L7 프록시 | TLS 종료, HTTP 라우팅, backend Service 연결 | 현재 Gateway controller |
| `cert-manager` | 인증서 lifecycle controller | 인증서 발급, 갱신, Secret 반영 | TLS 인증서 관리 담당 |
| `public NLB` | 외부 L4 load balancer | 인터넷에서 들어오는 TCP 트래픽을 클러스터 진입점으로 전달 | 외부 443 진입 계층 |
| `Route53 private DNS` | VPC 내부용 DNS 이름 체계 | 외부 데이터 계층의 private endpoint 이름 해석 | DB/Redis/Kafka/Qdrant 같은 외부 데이터 연결 기준 |

---

## 4) 워크로드 / 배포 / 스케일링

| 용어 | 무엇인지 | 역할 | 설계 기준에서의 위치 |
|------|------|------|------|
| `Pod` | Kubernetes의 최소 실행 단위 | 하나 이상의 컨테이너를 함께 실행 | backend, recommend, monitoring component가 Pod 단위로 뜸 |
| `Deployment` | stateless workload용 선언형 리소스 | 원하는 replica 수 유지, rollout/rollback 지원 | app workload 기본 배포 단위 |
| `StatefulSet` | stateful workload용 선언형 리소스 | 고정된 이름과 순서, PVC 연결 관계 유지 | data workload는 현재 대상이 아님 |
| `Job` | 끝이 있는 일회성 workload | 완료될 때까지 작업 수행 | 배치성 작업이 생기면 사용 가능 |
| `CronJob` | 주기적으로 Job을 만드는 리소스 | 스케줄 기반 작업 실행 | 정기 작업이 생기면 사용 가능 |
| `HPA` | Horizontal Pod Autoscaler | 메트릭 기반으로 Pod replica 수 조절 | app이 수평 확장 가능할 때만 의미 있음 |
| `Secret` | 민감값 전달용 리소스 | 비밀번호, 토큰, 인증서 등을 런타임에 주입 | SSM 값을 런타임 주입하는 대상 |
| `ConfigMap` | 비민감 설정 전달용 리소스 | 환경설정, 플래그, 주소 등을 런타임에 주입 | 환경별 설정 분리 |

---

## 5) 배포 도구 / 운영 도구

| 용어 | 무엇인지 | 역할 | 설계 기준에서의 위치 |
|------|------|------|------|
| `Helm` | Kubernetes 패키징/템플릿 도구 | chart와 values로 리소스 묶음을 관리 | 배포 단위 표준 |
| `Argo CD` | GitOps controller | Git 상태를 클러스터 상태로 지속 reconcile | CD 실행자 |
| `GitHub Actions` | CI 자동화 도구 | 테스트, 빌드, 이미지 푸시 수행 | CI 담당 |

---

## 6) 저장소 / 상태 관련 용어

| 용어 | 무엇인지 | 역할 | 설계 기준에서의 위치 |
|------|------|------|------|
| `PV` | PersistentVolume | 실제 영속 스토리지 리소스 | stateful data workload가 현재 대상이 아니라 기준선에 포함하지 않음 |
| `PVC` | PersistentVolumeClaim | Pod가 필요한 스토리지를 요청하는 리소스 | data workload를 클러스터에 넣지 않으므로 현재 기본 대상이 아님 |
| `StorageClass` | 스토리지 프로비저닝 정책 | 어떤 볼륨을 어떤 방식으로 만들지 정의 | 현재 data workload 비대상이라 기준선에서 제외 |

---

## 7) 설계 기준에서의 한 줄 역할 맵

| 흐름 | 역할을 맡는 구성요소 |
|------|------|
| 외부 요청 진입 | `Public DNS -> public NLB -> Traefik -> Service -> kube-proxy -> Pod` |
| Pod 간 네트워크 | `CNI(Flannel)` |
| 클러스터 내부 DNS | `CoreDNS` |
| 외부 데이터 이름 해석 | `Pod -> CoreDNS -> Route53 private DNS -> EC2 private endpoint` |
| 컨테이너 실제 실행 | `kubelet + containerd` |
| 배포 상태 반영 | `GitHub Actions -> Helm values -> Argo CD` |

---

## 8) 읽는 법

이 문서는 선택 근거 문서가 아니다. "이 단어가 대체 무슨 역할인지"를 빠르게 확인하는 목적의 참고 문서다.

- `control plane`은 "무엇을 어떻게 유지할지 결정하는 계층"이다.
- `data plane`은 "실제 요청과 패킷과 컨테이너가 움직이는 계층"이다.
- `Service 데이터플레인`은 그중에서도 "Service로 들어온 요청을 실제 Pod로 보내는 부분"이다.
- 왜 이 구성을 골랐는지는 DR 문서를 본다.
- 설계 기준 전체 구조는 `K8S-001`을 본다.
- 특정 주제의 상세 비교는 개별 심화 문서를 본다.
