# Web Server (Nginx)

## 설치

```bash
sudo ./install.sh
```

## 설정 배포

```bash
# prod
scp prod/nginx.conf root@<SERVER_IP>:/etc/nginx/nginx.conf
scp prod/conf.d/nginx.conf root@<SERVER_IP>:/etc/nginx/conf.d/nginx.conf
ssh root@<SERVER_IP> "nginx -t && systemctl reload nginx"

# dev
scp dev/nginx.conf root@<SERVER_IP>:/etc/nginx/nginx.conf
scp dev/conf.d/nginx.conf root@<SERVER_IP>:/etc/nginx/conf.d/nginx.conf
ssh root@<SERVER_IP> "nginx -t && systemctl reload nginx"
```

## HTTPS 설정 (Certbot)

```bash
# certbot 설치
sudo apt-get install -y certbot python3-certbot-nginx

# 인증서 발급
sudo certbot --nginx -d moyeobab.com -d api.moyeobab.com \
  --non-interactive --agree-tos --email admin@moyeobab.com

# 자동 갱신 확인
sudo certbot renew --dry-run
```

dev 환경:
```bash
sudo certbot --nginx -d dev.moyeobab.com -d api.dev.moyeobab.com \
  --non-interactive --agree-tos --email admin@moyeobab.com
```

## 보안 설정 (SEC-20260204-001)

### Rate Limiting
- `nginx.conf`: IP당 POST/PUT/DELETE 2r/s, burst 10, 초과 시 429
- `conf.d/nginx.conf`: `limit_req zone=global_write_limit burst=10 nodelay`

### Slowloris 방어
- `client_header_timeout 10s`
- `client_body_timeout 10s`
- `keepalive_timeout 15s`
- `send_timeout 10s`

### 경로 차단
- Swagger/OpenAPI: `/v3/api-docs`, `/swagger-ui` 등 → 404
- Actuator: `/actuator` → 404
- WordPress 스캐너: `/wp-admin`, `/wp-login.php` 등 → 404

## 디렉토리 구조

```
webserver/
├── install.sh          ← nginx 설치
├── dev/
│   ├── nginx.conf      ← /etc/nginx/nginx.conf
│   └── conf.d/
│       └── nginx.conf  ← /etc/nginx/conf.d/nginx.conf
└── prod/
    ├── nginx.conf
    └── conf.d/
        └── nginx.conf
```
