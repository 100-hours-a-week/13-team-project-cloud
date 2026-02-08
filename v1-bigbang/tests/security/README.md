# Security Tests

SEC-20260204-001 보안 강화 작업의 방어 검증 테스트.

## 배경

단일 서버 환경에서 특정 IP의 대량 POST 요청(초당 54회)으로 DB 커넥션 고갈 및 OS 스레싱 발생.
Nginx 레벨에서 L7 DoS 방어 및 Slowloris 방어 설정 후, 방어가 정상 동작하는지 검증하기 위한 테스트.

## 테스트 목록

### 1. Rate Limit 테스트 (`rate-limit-test.sh`)

**방어 대상**: L7 DoS (대량 POST 요청)

**Nginx 설정**: `limit_req_zone` — IP당 2r/s, burst 10, 초과 시 429 반환

**테스트 방법**:
- 200개의 POST 요청을 동시 병렬 전송
- 1~12회 성공(2r/s + burst 10), 13회 이후 429 응답 확인

**실행**:
```bash
export ACCESS_TOKEN='your_jwt_token'
export CSRF_TOKEN='your_csrf_token'
./rate-limit-test.sh
```

### 2. Slowloris 테스트 (Python)

**방어 대상**: Slowloris 공격 (저속 헤더 전송으로 커넥션 점유)

**Nginx 설정**: `client_header_timeout 10s`, `client_body_timeout 10s`, `keepalive_timeout 15s`

**테스트 방법**:
- Python `Slowloris` 패키지로 다수의 소켓을 열어 불완전한 헤더를 지속 전송
- 10초 후 서버가 연결을 끊는지 확인

**실행**:
```bash
# venv 활성화
source ../venv/bin/activate

# slowloris 실행 (기본: 150 소켓)
slowloris api.dev.moyeobab.com

# 소켓 수 지정
slowloris api.dev.moyeobab.com -s 300
```

