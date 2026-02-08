# Nginx Exporter 설치 가이드

Nginx의 내부 메트릭(Connections, Requests 등)을 수집하여 Prometheus로 전달합니다.

## 1. 사전 준비 (Nginx 설정)
Exporter가 Nginx의 상태를 읽을 수 있도록 `stub_status` 페이지를 로컬에서 활성화해야 합니다.

### Nginx 설정 수정 (`/etc/nginx/nginx.conf`)
`server` 블록(보통 80 포트) 내에 아래 내용을 추가합니다.

```nginx
server {
    listen 80;
    server_name localhost;

    location /stub_status {
        stub_status;
        allow 127.0.0.1;    # 로컬호스트만 접근 허용
        deny all;           # 나머지는 차단
    }
}
```

수정 후 Nginx 재설정:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 2. 설치
이 디렉토리의 `install.sh` 스크립트를 실행합니다.

```bash
# bash로 실행하는 것을 권장합니다.
sudo bash install.sh
```

### 스크립트가 수행하는 작업:
*   서버 아키텍처(ARM64/AMD64) 자동 감지 및 바이너리 다운로드
*   `nginx_exporter` 시스템 사용자 자동 생성
*   Systemd 서비스(`nginx_exporter.service`) 등록 및 시작

## 3. 확인
설치가 완료되면 9113 포트에서 메트릭이 나오는지 확인합니다.

```bash
curl localhost:9113/metrics
```

## 4. 문제 해결
*   **Failed to determine user credentials**: `sudo useradd -rs /bin/false nginx_exporter` 명령으로 유저를 직접 생성한 후 서비스를 재시작하세요.
*   **Exec format error**: 서버 아키텍처와 다운로드된 바이너리가 맞지 않는 경우입니다. `install.sh`를 최신 버전으로 업데이트하여 다시 실행하세요.
