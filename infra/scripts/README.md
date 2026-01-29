# Scripts Provisioning Guide

이 문서는 Ubuntu 서버에서 scripts를 이용해 프로비저닝하는 순서를 정리합니다.

## 0) scripts 복사 (로컬에서 실행)

```bash
scp -i key.pem -r infra/scripts ubuntu@<SERVER_IP>:/home/ubuntu
```

서버 기준 기본 경로는 `/home/ubuntu/scripts` 입니다.

## 1) 기본 패키지 설치 (서버에서 실행)

```bash
sudo /home/ubuntu/scripts/init/init.sh
```

개별 설치가 필요하면:

```bash
sudo /home/ubuntu/scripts/init/install-nginx.sh
sudo /home/ubuntu/scripts/init/install-postgresql.sh
sudo /home/ubuntu/scripts/init/install-redis.sh
sudo /home/ubuntu/scripts/init/install-python.sh
```

## 2) DB EBS 마이그레이션 (옵션)

EBS가 연결되어 있는 경우에만 수행:

```bash
lsblk -f
sudo /home/ubuntu/scripts/database/migrate-postgres-data-dir.sh /dev/nvme1n1 /var/lib/postgresql/16/main
```

디스크가 비어있을 때만 포맷:

```bash
sudo AUTO_FORMAT=1 /home/ubuntu/scripts/database/migrate-postgres-data-dir.sh /dev/nvme1n1 /var/lib/postgresql/16/main
```

## 3) PostgreSQL 사용자 생성 (옵션)

```bash
sudo -u postgres psql
```

`/home/ubuntu/scripts/database/README.md`의 DDL 실행.

## 4) Redis 비밀번호 설정 (옵션)

`/home/ubuntu/scripts/redis/README.md`의 명령만 실행.

## 5) 백엔드 설정 (옵션)

```bash
sudo /home/ubuntu/scripts/backend/install-java.sh
sudo /home/ubuntu/scripts/backend/run-backend-test.sh
```

`run-backend-test.sh`는 `/home/ubuntu/scripts/backend/`에 JAR가 있어야 함.

## 6) 프론트 배포 (옵션)

```bash
sudo /home/ubuntu/scripts/frontend/deploy-frontend-test.sh
sudo /home/ubuntu/scripts/frontend/fix-permissions.sh /var/www/html
```

## 7) HTTPS 설정 (nginx + certbot)

도메인이 서버 IP를 가리키고 80/443 포트가 열려 있어야 함.

```bash
sudo CERTBOT_EMAIL=admin@moyeobab.com /home/ubuntu/scripts/ws/setup-https.sh
```

도메인 직접 지정:

```bash
sudo CERTBOT_EMAIL=admin@moyeobab.com /home/ubuntu/scripts/ws/setup-https.sh moyeobab.com api.moyeobab.com
```

## 8) 모니터링 (옵션)

`/home/ubuntu/scripts/node_exporter/README.md` 참고.

## 9) 상태 확인

```bash
sudo systemctl status nginx --no-pager
sudo systemctl status postgresql --no-pager
sudo systemctl status redis-server --no-pager
ss -lntp
```

---

## 10) System Configuration & Management (요약)

서버의 주요 프로세스는 systemd를 통해 관리되며, 서버 재부팅 시 자동으로 시작됩니다.

### 관리되는 서비스 목록
| 서비스명 | 설명 | 설정 파일 위치 | 포트 |
| :--- | :--- | :--- | :--- |
| **moyeobab-api** | Spring Boot 백엔드 | /etc/systemd/system/moyeobab-api.service | 8080 |
| **recommend** | FastAPI AI 추천 서비스 | /etc/systemd/system/recommend.service | 8000 |
| **nginx** | 웹 서버 (Reverse Proxy) | 기본 패키지 (/etc/nginx/...) | 80, 443 |
| **postgresql** | 데이터베이스 | 기본 패키지 (/etc/postgresql/...) | 5432 |
| **redis-server** | 인메모리 캐시 | 기본 패키지 (/etc/redis/...) | 6379 |

### 자동 시작 및 재시작 정책
- **자동 시작 (Enable):** 모든 서비스는 systemctl enable이 적용되어 있어 서버가 껐다 켜져도(Reboot) 자동으로 실행됩니다.
- **재시작 정책 (Restart):**
    - 백엔드 및 AI 서비스: Restart=always가 설정되어 있어, 프로세스가 예기치 않게 종료(Crash)되면 5초 후 자동으로 재시작됩니다.
    - 인프라 서비스(Nginx, DB 등): 패키지 기본 설정에 따르며, 일반적으로 실패 시 재시작되도록 구성되어 있습니다.

### 로그 관리 (Logging)
모든 서비스의 로그는 systemd-journald에 의해 통합 관리됩니다. 별도의 파일로 저장되지 않고 저널(Journal)에 기록됩니다.

**로그 확인 방법:**
```bash
# 실시간 로그 확인 (tail -f)
sudo journalctl -u moyeobab-api -f
sudo journalctl -u recommend -f
sudo journalctl -u nginx -f

# 특정 서비스의 전체 로그 조회
sudo journalctl -u postgresql

# 시스템 전체 오류 로그 조회
sudo journalctl -p err -xb
```
