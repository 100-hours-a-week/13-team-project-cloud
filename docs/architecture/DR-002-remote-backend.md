# DR-002: Terraform 원격 State 관리 채택 (S3 + DynamoDB)

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-01-26 |
| 상태 | 승인됨 |
| 적용 단계 | v1 (Big Bang) |
| 관련 문서 | [DR-001 (IaC 도구 선정)](DR-001-iac-tool-selection.md) |
| 주요 목표 | Terraform State를 팀 협업 가능한 원격 저장소로 전환 |

---

## 1) 배경

[DR-001](DR-001-iac-tool-selection.md)에서 Terraform을 채택한 직후, State 파일 관리 문제가 즉시 발생했다.

- State 파일(`terraform.tfstate`)이 로컬에만 존재하면 팀원 간 상태 공유가 불가능하다.
- 동시에 `terraform apply`를 실행하면 State가 충돌하거나 덮어쓰기될 수 있다.
- State에는 DB 비밀번호, 보안 그룹 규칙 등 민감 정보가 평문으로 포함된다.

---

## 2) 요구사항

- 팀 전원이 동일한 State를 참조할 수 있어야 한다.
- 동시 실행 시 한 명만 apply 가능하도록 잠금(Lock)이 필요하다.
- State 파일의 버전 관리와 암호화가 보장되어야 한다.
- 추가 SaaS 비용 없이 AWS 리소스만으로 구성 가능해야 한다.

---

## 3) 결정

AWS S3(State 저장) + DynamoDB(Lock 관리) 조합을 원격 Backend로 채택한다.

S3 선택 이유:
- tfstate를 단일 클라우드에서 중앙 관리하는 게 로컬 파일보다 안전하다.
- 버전 관리와 서버 측 암호화(SSE-S3)를 기본 제공한다.
- Terraform Cloud 같은 SaaS 없이 AWS 네이티브 리소스만으로 해결되어 벤더 종속이 없다.

DynamoDB Lock 도입 배경:

처음에는 "어차피 2명인데 Lock이 필요한가?" 하는 의문이 있었다. 하지만 Terraform은 State 동시 갱신이 한 번만 꼬여도 복구 비용이 훨씬 크다. 2인이라도 CI/로컬에서 plan/apply 타이밍이 겹칠 가능성이 있으니, 예방 비용이 월 1달러도 안 되는 수준이라면 넣지 않을 이유가 없다고 판단했다.

---

## 4) DynamoDB Lock 비용 분석

Lock 테이블은 `terraform plan`/`apply` 실행 시에만 잠깐 읽기/쓰기가 발생하므로, 요청량 자체가 극히 적다.

Provisioned 최소치 기준 (1 RCU + 1 WCU):
- RCU $0.00013/h + WCU $0.00065/h = $0.00078/h
- 월(약 720h): $0.00078 x 720 = 약 $0.56/월

서울 리전 단가가 약간 더 높아도 $1 미만/월에 수렴한다. On-demand로 두면 체감 0원대(요청량이 너무 적어서).

결론: "혹시 모를 State 충돌/손상 예방"이라는 이득에 비해 운영비는 사실상 무시 가능한 수준이다.

---

## 5) 초기 구축 시 겪은 문제: 닭과 달걀

Backend 리소스(S3, DynamoDB) 자체도 Terraform으로 관리하고 싶었는데, Backend가 없는 상태에서 Backend를 생성해야 하는 순환 참조가 발생했다.

해결: Backend 리소스 전용 디렉토리를 분리하고, 이 디렉토리만 로컬 State로 관리한다.

```
terraform/
├── backend/          ← S3, DynamoDB 생성 (로컬 State)
│   └── dev/
└── environments/     ← 실제 인프라 (원격 State)
    ├── dev/
    └── prod/
```

---

## 6) 환경별 State 분리

State를 하나로 관리하면 dev 변경이 prod에 영향을 줄 수 있다. 6개 환경으로 분리:

| 환경 | S3 Key | 용도 |
|------|--------|------|
| dev | `dev/terraform.tfstate` | 개발 앱 서버 |
| dev-core | `dev-core/terraform.tfstate` | EIP, EBS 등 영구 리소스 |
| dev-monitoring | `dev-monitoring/terraform.tfstate` | 모니터링 서버 |
| prod | `prod/terraform.tfstate` | 운영 앱 서버 |
| prod-core | `prod-core/terraform.tfstate` | 운영 영구 리소스 |
| prod-monitoring | `prod-monitoring/terraform.tfstate` | 운영 모니터링 서버 |

core를 별도로 분리한 이유는 EIP와 DB용 EBS가 dev/prod 서버와 수명 주기가 다르기 때문이다. dev 서버를 destroy해도 IP 주소와 데이터는 보존되어야 한다.

---

## 7) 결과

- 모든 인프라 변경이 PR 기반으로 표준화됨
- `terraform plan` 결과를 팀이 리뷰한 후에만 apply 실행
- State Lock 덕분에 동시 실행 사고가 원천 차단됨
