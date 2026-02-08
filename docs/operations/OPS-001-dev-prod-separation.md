# Dev/Prod 환경 분리 및 EIP/EBS 보호

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-02-01 |
| 적용 단계 | v1 (Big Bang) |
| 관련 문서 | [DR-002 (원격 State)](../architecture/DR-002-remote-backend.md), [DR-003 로그 모니터링 구축](../architecture/DR-003-monitoring-setup.md) |
| 주요 목표 | Dev 환경 분리, 영구 리소스 보호, 안전한 인프라 실험 환경 확보 |

---

## 1) 배경

초기에는 단일 환경(dev)에서 모든 인프라를 운영했다. 서비스가 안정화되면서 "prod를 건드리지 않고 인프라를 실험할 수 있는 환경"이 필요해졌다.

동시에, Terraform State 하나에 모든 리소스가 들어있어서 `terraform destroy`가 EIP(고정 IP)와 DB용 EBS(데이터 볼륨)까지 삭제할 위험이 있었다.

---

## 2) State 분리 전략

핵심 아이디어: 수명 주기가 다른 리소스는 State를 분리한다.

EC2 인스턴스는 자주 재생성될 수 있지만, EIP와 EBS는 절대 삭제되면 안 된다.

| State | 포함 리소스 | 수명 주기 |
|-------|------------|----------|
| dev | EC2, SG, IAM Role | 짧음 (실험/재생성 가능) |
| dev-core | EIP, EBS | 영구 (절대 삭제 불가) |
| dev-monitoring | 모니터링 EC2 | 중간 |
| prod, prod-core, prod-monitoring | 동일 구조 | 동일 |

core State의 EBS에는 `prevent_destroy` lifecycle을 적용하여, 실수로 `terraform destroy`를 실행해도 Terraform이 거부하도록 설정했다.

---

## 3) Dev/Prod 전환 — 환경 스왑

처음에는 dev에서 운영하다가 prod로 승격하는 방식을 택했다. 새로 만드는 게 아니라 기존 dev 인프라를 prod로 "승격"한 이유:

- DNS, SSL 인증서, CORS 설정이 이미 dev 도메인에 연결되어 있어서 새로 만들면 전부 재설정 필요
- dev에서 이미 안정적으로 동작하는 인프라를 그대로 prod로 올리는 게 리스크가 낮음

실행 순서:
1. dev 디렉토리를 prod로 복사
2. tfvars 내 환경 식별자 변경
3. S3 State 파일 경로 스왑 (dev → prod, prod → dev)
4. DynamoDB Lock의 Checksum 갱신 (State 파일 해시가 변경되므로)

---

## 4) Dev 환경 재구축

prod로 승격한 뒤 빈 dev 환경을 새로 구축:

- 모니터링도 dev/prod 별도 서버로 분리 (보안 격리)
- Nginx 설정을 dev 도메인용으로 분리 배포
- WireGuard VPN도 dev 전용 터널 추가 (wg0: prod, wg1: dev)

macOS에서 VPN 터널 2개를 동시에 운영할 때 소스 IP 충돌 문제가 발생했는데, prod/dev를 별도 인터페이스(wg0/wg1)로 분리하여 해결했다.

---

## 5) Security Group 리팩토링

환경 분리 과정에서 SG 규칙도 정리:

기존: 모니터링 서버 IP를 하드코딩 (`10.0.0.111/32`)
변경: SG 참조 방식으로 전환 (모니터링 서버의 SG를 소스로 지정)

이유: EC2를 재생성하면 Private IP가 바뀔 수 있어서 IP 하드코딩은 깨지기 쉽다. SG 참조는 IP가 바뀌어도 유효하다.

추가로 EC2에 고정 Private IP를 할당하여 Prometheus target 설정이 EC2 재생성 후에도 유지되도록 했다.

---

## 6) 결과

- dev에서 자유롭게 인프라 실험 가능 (prod 영향 없음)
- EIP/EBS는 core State + prevent_destroy로 이중 보호
- 모니터링도 환경별 분리되어 보안 격리 달성
- SG 규칙이 IP 하드코딩에서 참조 방식으로 전환되어 유지보수성 향상
