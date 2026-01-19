# Init Scripts

Ubuntu 환경에서 초기 설치를 위한 스크립트 모음입니다.

## 스크립트 설명

- `init.sh`: 공통 함수(권한/apt 업데이트) + 전체 설치 실행 엔트리
- `install-nginx.sh`: Nginx 설치 및 서비스 활성화
- `install-postgresql.sh`: PostgreSQL 설치 및 서비스 활성화
- `install-redis.sh`: Redis 설치 및 서비스 활성화

## 실행 명령

```bash
# 전체 설치
sudo infra/script/init/init.sh

# 개별 설치
sudo infra/script/init/install-nginx.sh
sudo infra/script/init/install-postgresql.sh
sudo infra/script/init/install-redis.sh
```
