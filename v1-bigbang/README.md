# v1 Big Bang

단일 EC2 인스턴스에 Nginx + Spring Boot + PostgreSQL + Redis를 직접 배포하는 구조.

## 구조

```
v1-bigbang/
├── terraform/           IaC
│   ├── modules/         재사용 모듈 (VPC, EC2, Monitoring)
│   ├── environments/    환경별 구성 (dev, prod, *-core, *-monitoring)
│   └── backend/         Terraform State 관리 (S3 + DynamoDB)
├── monitoring/          PLG Stack (Prometheus, Loki, Grafana) — Docker Compose
│   ├── dev/
│   └── prod/
├── ci/                  GitHub Actions 워크플로우 (각 레포 참조본)
│   ├── backend/         BE CI/CD (Gradle → JAR → EC2)
│   ├── frontend/        FE CI/CD (npm → dist → EC2 rsync)
│   └── ai/              AI CI/CD (ruff/mypy → git pull → systemctl)
├── scripts/             프로비저닝 및 배포
│   ├── init/            서버 초기 패키지 설치
│   ├── webserver/       Nginx 설정 (dev/prod)
│   ├── backend/         백엔드 서비스 배포
│   ├── frontend/        프론트엔드 배포 및 롤백
│   ├── ai/              AI 추천 서비스 배포
│   ├── database/        PostgreSQL 마이그레이션
│   └── exporters/       Prometheus Exporter 설치
└── tests/               테스트
    ├── security/        Rate Limit, Slowloris 방어 테스트
    ├── load/            부하 테스트
    └── reports/         k6 테스트 리포트
```

## Terraform 환경

| 환경 | 용도 | State |
|------|------|-------|
| dev | 개발 앱 서버 | S3 remote |
| dev-core | dev 기반 인프라 (EIP, EBS) | S3 remote |
| dev-monitoring | dev 모니터링 서버 | S3 remote |
| prod | 운영 앱 서버 | S3 remote |
| prod-core | prod 기반 인프라 | S3 remote |
| prod-monitoring | prod 모니터링 서버 | S3 remote |

## 상세 문서

- CI/CD 파이프라인: [`ci-cd/README.md`](ci-cd/README.md)
- 웹서버 설정: [`scripts/webserver/README.md`](scripts/webserver/README.md)
- Exporter: [`scripts/exporters/README.md`](scripts/exporters/README.md)
- DB 마이그레이션: [`scripts/database/README.md`](scripts/database/README.md)
- 보안 테스트: [`tests/security/README.md`](tests/security/README.md)
