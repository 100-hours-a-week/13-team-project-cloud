# docs/

운영 과정에서 내린 의사결정, 겪은 사고, 해결 과정을 기록한 문서.

Kubernetes 관련 공식 문서는 아래 원칙으로 관리한다.

- 설계 본문: `docs/kubernetes/`
- 개별 선택 근거: `docs/architecture/DR-xxx`
- `v3-kubernetes/docs`: 이전 검토 흔적과 참고 자료

## 문서 접두어 규칙

| 접두어 | 의미 | 설명 |
|--------|------|------|
| DR | Decision Record | 인프라/아키텍처 의사결정 기록. 왜 이 도구/방식을 선택했는지. |
| K8S | Kubernetes Design | Kubernetes 설계 본문. 세부 선택 근거는 DR 참조. |
| SEC | Security Incident | 보안 사고 대응 기록. 사고 경위, 분석, 대응, 교훈. |
| OPS | Operations Record | 운영 절차 및 환경 관리 기록. |

## 구조

```
docs/
├── architecture/      의사결정 및 아키텍처 기록 (DR)
├── kubernetes/        Kubernetes 설계 본문 (K8S)
├── incidents/         사고 대응 기록 (SEC)
└── operations/        운영 절차 및 환경 관리 (OPS)
```

---

## 문서 목록

### architecture/ — 의사결정 및 아키텍처

| 문서 | 날짜 | 요약 |
|------|------|------|
| [DR-001 IaC 도구 선정](architecture/DR-001-iac-tool-selection.md) | 2026-01-23 | CloudFormation, Ansible, Terraform, OpenTofu 비교 후 Terraform 채택 |
| [DR-002 원격 State 관리](architecture/DR-002-remote-backend.md) | 2026-01-26 | S3 + DynamoDB Lock 기반 원격 Backend 채택. 비용 분석 포함 |
| [DR-003 로그 모니터링 구축](architecture/DR-003-monitoring-setup.md) | 2026-01-30 | CloudWatch, ELK, PLG 비교 후 PLG Stack 채택. SEC-001이 계기 |
| [DR-004 Kubernetes 배포 방식 선정](architecture/DR-004-kubernetes-distribution-selection.md) | 2026-03-08 | self-managed Kubernetes 배포 기준선으로 kubeadm 채택 |
| [DR-005 컨트롤 플레인 구조 선정](architecture/DR-005-kubernetes-control-plane-topology.md) | 2026-03-08 | 초기 Kubernetes 컨트롤 플레인 구조로 single control plane 채택 |
| [DR-006 Kubernetes CNI 선정](architecture/DR-006-kubernetes-cni-selection.md) | 2026-03-08 | 현재 단계의 Kubernetes CNI로 Flannel 채택 |
| [DR-007 트래픽 진입점 API 선정](architecture/DR-007-kubernetes-gateway-api-selection.md) | 2026-03-08 | 클러스터 외부 트래픽의 Kubernetes 표현 모델로 Gateway API 채택 |
| [DR-008 Kubernetes Gateway Controller 선정](architecture/DR-008-kubernetes-gateway-controller-selection.md) | 2026-03-08 | Kubernetes 외부 진입 계층의 Gateway 컨트롤러로 Traefik 채택 |
| [DR-009 도메인 및 인증서 관리 방식 선정](architecture/DR-009-domain-and-certificate-management.md) | 2026-03-08 | Traefik에서 TLS 종료, 인증서 lifecycle은 cert-manager가 담당하는 기준선 채택 |
| [DR-010 Service 데이터플레인 전략 선정](architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md) | 2026-03-08 | `kube-proxy` 유지, 초기 모드는 `iptables`, `nftables`는 후속 검토 |

### kubernetes/ — Kubernetes 설계 본문

| 문서 | 날짜 | 요약 |
|------|------|------|
| [K8S-001 Kubernetes 최종 설계서](kubernetes/K8S-001-final-design.md) | 2026-03-08 | v3 Kubernetes 최종 설계 문서의 기준선. 본문 직접 결정과 DR 참조 대상을 구분 |
| [K8S-002 Kubernetes CNI 비교 연구](kubernetes/K8S-002-cni-comparison-study.md) | 2026-03-08 | Flannel, Calico, Cilium을 운영 책임 범위 기준으로 비교 |
| [K8S-003 Flannel 심화](kubernetes/K8S-003-flannel-deep-dive.md) | 2026-03-08 | Flannel을 현재 1차 CNI 선택지로 본 이유와 한계 정리 |
| [K8S-004 Calico 심화](kubernetes/K8S-004-calico-deep-dive.md) | 2026-03-08 | Calico의 정책/운영 강점과 현재 비선정 이유 정리 |
| [K8S-005 Cilium 심화](kubernetes/K8S-005-cilium-deep-dive.md) | 2026-03-08 | Cilium의 eBPF 통합 모델과 장기 재검토 조건 정리 |
| [K8S-006 Service 데이터플레인 비교 연구](kubernetes/K8S-006-service-dataplane-comparison-study.md) | 2026-03-08 | `Service ClusterIP` 전달 계층과 `kube-proxy` 모드 비교 |
| [K8S-007 kube-proxy iptables 심화](kubernetes/K8S-007-kube-proxy-iptables-deep-dive.md) | 2026-03-08 | `iptables`를 현재 Service 데이터플레인 기준선으로 둔 이유 정리 |
| [K8S-008 kube-proxy nftables 심화](kubernetes/K8S-008-kube-proxy-nftables-deep-dive.md) | 2026-03-08 | `nftables`를 유망한 후속 후보로 본 이유 정리 |
| [K8S-009 kube-proxy ipvs 심화](kubernetes/K8S-009-kube-proxy-ipvs-deep-dive.md) | 2026-03-08 | `ipvs`의 동작과 deprecated 방향 정리 |
| [K8S-010 eBPF Service 데이터플레인 메모](kubernetes/K8S-010-ebpf-service-dataplane-note.md) | 2026-03-08 | eBPF replacement를 현재 제외한 이유 정리 |

### incidents/ — 사고 대응

| 문서 | 날짜 | 심각도 | 요약 |
|------|------|--------|------|
| [SEC-001 DB 유출](incidents/SEC-001-db-credential-leak.md) | 2026-02-02 | Critical | Wiki에 DB 비밀번호 노출 → 크레덴셜 교체 중 7시간 연쇄 장애 |
| [SEC-002 DoS 대응](incidents/SEC-002-dos-attack-and-security-hardening.md) | 2026-02-04 | High | 초당 54회 POST 공격 → Rate Limiting 구축 |
| [SEC-002 상세 분석](incidents/SEC-002-dos-analysis.md) | 2026-02-03 | — | 트래픽 패턴 분석, 1차/2차 장애 원인 규명, 개선 전략 도출 |
| [SEC-003 Safe Browsing](incidents/SEC-003-google-safe-browsing.md) | 2026-02-05 | Medium | SPA catch-all 라우팅이 피싱 오탐 유발 → 경로 차단으로 해결 |

### operations/ — 운영

| 문서 | 날짜 | 요약 |
|------|------|------|
| [OPS-001 Dev/Prod 환경 분리](operations/OPS-001-dev-prod-separation.md) | 2026-02-01 | State 분리, 환경 스왑, EBS 보호, SG 리팩토링 |
| [OPS-002 Slowloris 방어](operations/OPS-002-slowloris-defense.md) | 2026-02-04 | Connection Timeout 최적화, 커넥션 점유율 82% 감소 |
| [OPS-003 DB 커넥션 풀 부하 테스트](operations/OPS-003-db-connection-pool-load-test.md) | 2026-02-05 | HikariCP 10→30 증설 검증 → 2 vCPU에서 역효과 확인, 현행 유지 결정 |
| [OPS-005 Prod DB 마이그레이션 실행](operations/OPS-005-db-migration-execution.md) | 2026-02-23 | PostgreSQL v1→v2 Logical Replication + PgBouncer 실행, k6 10,000건 유실 0건 검증, Grafana 증거 12장 |
| [OPS-006 V1→V2 카나리 마이그레이션 실행](operations/OPS-006-canary-migration-execution.md) | 2026-02-20 | EC2 직설치→Docker 무중단 카나리 전환. Route53 DNS 캐시 실패 → ALB Weighted TG 전환, k6 50VU checks 100%/에러 0% |
| [OPS-007 Redis v1→v2 마이그레이션 실행](operations/OPS-007-redis-migration-execution.md) | 2026-02-23 | Cold Cutover + REPLICAOF. AUTH 토큰 미반영 500 현장 수정, k6 refresh_401_rate 0% (세션 유실 0건) |

---

## Kubernetes 문서 읽는 순서

1. [K8S-001 Kubernetes 최종 설계서](kubernetes/K8S-001-final-design.md)
2. [DR-004 Kubernetes 배포 방식 선정](architecture/DR-004-kubernetes-distribution-selection.md)
3. [DR-005 컨트롤 플레인 구조 선정](architecture/DR-005-kubernetes-control-plane-topology.md)
4. [DR-006 Kubernetes CNI 선정](architecture/DR-006-kubernetes-cni-selection.md)
5. [K8S-002 Kubernetes CNI 비교 연구](kubernetes/K8S-002-cni-comparison-study.md)
6. [K8S-003 Flannel 심화](kubernetes/K8S-003-flannel-deep-dive.md)
7. [K8S-004 Calico 심화](kubernetes/K8S-004-calico-deep-dive.md)
8. [K8S-005 Cilium 심화](kubernetes/K8S-005-cilium-deep-dive.md)
9. [DR-007 트래픽 진입점 API 선정](architecture/DR-007-kubernetes-gateway-api-selection.md)
10. [DR-008 Kubernetes Gateway Controller 선정](architecture/DR-008-kubernetes-gateway-controller-selection.md)
11. [DR-009 도메인 및 인증서 관리 방식 선정](architecture/DR-009-domain-and-certificate-management.md)
12. [DR-010 Service 데이터플레인 전략 선정](architecture/DR-010-kube-proxy-and-service-dataplane-strategy.md)
13. [K8S-006 Service 데이터플레인 비교 연구](kubernetes/K8S-006-service-dataplane-comparison-study.md)
14. [K8S-007 kube-proxy iptables 심화](kubernetes/K8S-007-kube-proxy-iptables-deep-dive.md)
15. [K8S-008 kube-proxy nftables 심화](kubernetes/K8S-008-kube-proxy-nftables-deep-dive.md)
16. [K8S-009 kube-proxy ipvs 심화](kubernetes/K8S-009-kube-proxy-ipvs-deep-dive.md)
17. [K8S-010 eBPF Service 데이터플레인 메모](kubernetes/K8S-010-ebpf-service-dataplane-note.md)
18. 필요 시 `v3-kubernetes/docs` 참고 자료

---

## 문서 간 연결

```
DR-001 (IaC 선정)
  └→ DR-002 (원격 State)
       └→ OPS-001 Dev/Prod 환경 분리 (State 분리)

SEC-001 (DB 유출, 7시간 장애)
  └→ DR-003 로그 모니터링 구축 (SEC-001이 계기)
       └→ SEC-002 (DoS 공격, 모니터링이 감지)
            ├→ SEC-002 상세 분석 (트래픽/장애 원인 분석)
            ├→ OPS-002 Slowloris 방어 (SEC-002 이후 추가 대비)
            ├→ OPS-003 DB 커넥션 풀 부하 테스트 (SEC-002 제안 검증)
            └→ SEC-003 (경로 차단이 오탐도 해결)

OPS-003 (DB 커넥션 풀 테스트, PgBouncer 불필요 근거)
  └→ OPS-005 Prod DB 마이그레이션 실행 (PgBouncer 임시 사용 후 제거)

OPS-006 (ALB 카나리 전환 — Route53 실패 → ALB 성공)
  ├→ OPS-005 Prod DB 마이그레이션 실행 (카나리 검증 후 DB 전환 진행)
  └→ OPS-007 Redis 마이그레이션 실행 (카나리 전환 완료 후 Redis 이관)

K8S-001 Kubernetes 최종 설계서
  └→ DR-004 Kubernetes 배포 방식 선정
  └→ DR-005 컨트롤 플레인 구조 선정
  └→ DR-006 Kubernetes CNI 선정
       └→ K8S-002 Kubernetes CNI 비교 연구
            ├→ K8S-003 Flannel 심화
            ├→ K8S-004 Calico 심화
            └→ K8S-005 Cilium 심화
  └→ DR-007 트래픽 진입점 API 선정
       └→ DR-008 Kubernetes Gateway Controller 선정
  └→ DR-009 도메인 및 인증서 관리 방식 선정
  └→ DR-010 Service 데이터플레인 전략 선정
       ├→ K8S-006 Service 데이터플레인 비교 연구
       ├→ K8S-007 kube-proxy iptables 심화
       ├→ K8S-008 kube-proxy nftables 심화
       ├→ K8S-009 kube-proxy ipvs 심화
       └→ K8S-010 eBPF Service 데이터플레인 메모
```
