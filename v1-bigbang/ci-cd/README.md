# v1 CI/CD 파이프라인

각 서비스 레포의 GitHub Actions 워크플로우를 모아둔 참조본.
실제 실행 원본은 각 레포의 `.github/workflows/`에 있음.

## 파이프라인 구조

```
Push/PR → CI (빌드/테스트/린트) → CD (배포 → 헬스체크 → 롤백)
                                     ↓
                                Discord 알림
```

모든 CD는 CI 성공 시에만 트리거 (`workflow_run`).

## 서비스별 요약

### Backend (Spring Boot)

| 파일 | 트리거 | Runner | 주요 단계 |
|------|--------|--------|-----------|
| `backend-ci.yml` | PR→develop, Push→main/develop | ubuntu-latest | Gradle build → Test Report → JAR 아티팩트 |
| `backend-cd.yml` | CI 성공 후 | ubuntu-latest | JAR scp → systemctl restart → /api/ping 헬스체크 |

- Java 21, Gradle 캐싱
- 배포 경로: `/home/ubuntu/app/app.jar`
- 롤백: 백업 JAR 복원 + 서비스 재시작

### Frontend (React/Vite)

| 파일 | 트리거 | Runner | 주요 단계 |
|------|--------|--------|-----------|
| `frontend-ci.yml` | Push→main/develop | ubuntu-24.04-arm | npm ci → Lint → Test → Build → dist 아티팩트 |
| `frontend-cd.yml` | CI 성공 후 | ubuntu-24.04-arm | rsync dist → 헬스체크 |
| `frontend-pr-ci.yml` | PR→develop/main | ubuntu-24.04-arm | 검증 → PR 코멘트 |

- Node 24, npm 캐싱
- 배포 경로: `/var/www/html`
- 롤백: `/var/www/html-backup` rsync 복원
- Vite 환경변수: `VITE_API_BASE_URL`, `VITE_KAKAO_MAP_APP_KEY`

### AI Recommend (FastAPI)

| 파일 | 트리거 | Runner | 주요 단계 |
|------|--------|--------|-----------|
| `recommend-ci.yml` | PR/Push (services/recommend/** 변경 시) | ubuntu-24.04-arm | ruff lint/format → mypy → pytest |
| `recommend-cd.yml` | CI 성공 후 | ubuntu-24.04-arm | git pull → pip install → systemctl restart → /health 헬스체크 |

- Python 3.11, pip 캐싱
- 배포: git pull + venv pip install (아티팩트 없이 소스 직접 배포)
- 롤백: 이전 git SHA로 reset + 서비스 재시작

## 공통 패턴

| 항목 | 내용 |
|------|------|
| 알림 | Discord Webhook (jq로 Embed 생성) |
| 환경 분리 | main→production, develop→develop |
| 롤백 | 모든 CD에 자동 롤백 포함 |
| 동시성 | `concurrency` 그룹으로 중복 실행 방지 |
| Secrets | `EC2_KEY_PAIR`, `EC2_ELASTIC_IP`, `DISCORD_WEBHOOK_URL` 등 GitHub Environments에서 관리 |

## 필요 GitHub Secrets

### Backend
- `EC2_KEY_PAIR`, `EC2_USER`, `EC2_ELASTIC_IP`
- `HEALTH_CHECK_URL`
- `DISCORD_WEBHOOK_URL`

### Frontend
- `EC2_KEY_PAIR`, `EC2_USER`, `EC2_ELASTIC_IP`, `SSH_PORT`
- `HEALTH_CHECK_URL`
- `VITE_API_BASE_URL`, `VITE_KAKAO_MAP_APP_KEY`
- `DISCORD_WEBHOOK_URL`

### AI Recommend
- `SSH_KEY`, `SSH_USER`, `SSH_HOST`, `SSH_PORT`
- `DISCORD_WEBHOOK_URL`
