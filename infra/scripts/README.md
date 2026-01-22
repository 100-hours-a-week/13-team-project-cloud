# Scripts

Ubuntu 환경에서 사용하는 인프라/배포 스크립트 모음입니다.

## 디렉토리 구조

- `init/`: 기본 패키지 설치(nginx/postgresql/redis/python)
- `ai/`: AI 추천 서비스 배포
- `frontend/`: 프론트 롤백 스크립트

## 실행 명령

```bash
# 전체 설치 (nginx/postgresql/redis)
sudo infra/scripts/init/init.sh

# 개별 설치
sudo infra/scripts/init/install-nginx.sh
sudo infra/scripts/init/install-postgresql.sh
sudo infra/scripts/init/install-redis.sh
sudo infra/scripts/init/install-python.sh

# AI 추천 서비스 배포
sudo infra/scripts/ai/init-deploy-recommend.sh

# 프론트 롤백
sudo infra/scripts/frontend/rollback.sh /var/www/html /var/www/html-backup
```

## Python 설치 옵션

- 기본 동작: apt로 `python3.11`이 있으면 설치, 없으면 pyenv로 설치
- `USE_PYENV=1`: pyenv 강제 사용
- `PYTHON_VERSION`: 설치 버전 지정 (기본 `3.11.9`)
- `PYENV_ROOT`: pyenv 설치 경로 (기본 `/opt/pyenv`)
- `SET_DEFAULT_PYTHON=1`: `/usr/local/bin/python3`를 pyenv 버전으로 연결
