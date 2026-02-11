# docs/

운영 과정에서 내린 의사결정, 겪은 사고, 해결 과정을 기록한 문서.

## 문서 접두어 규칙

| 접두어 | 의미 | 설명 |
|--------|------|------|
| DR | Decision Record | 인프라/아키텍처 의사결정 기록. 왜 이 도구/방식을 선택했는지. |
| SEC | Security Incident | 보안 사고 대응 기록. 사고 경위, 분석, 대응, 교훈. |
| OPS | Operations Record | 운영 절차 및 환경 관리 기록. |

## 구조

```
docs/
├── architecture/      의사결정 및 아키텍처 기록 (DR)
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
| [OPS-004 DNS 이전](operations/OPS-004-dns-migration-gabia-to-route53.md) | 2026-02-10 | 가비아 → Route 53 이전 시 루트 도메인 `@` 표기 차이로 Prod 장애 → 제거 후 해결 |

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
```
