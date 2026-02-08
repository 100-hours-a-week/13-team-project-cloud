#!/bin/bash
# =============================================================================
# Rate Limit Test Script
# SEC-20260204-001: L7 DoS 방어 테스트
# 모든 요청을 동시에 병렬로 전송
# =============================================================================

# ========================= 설정 =========================
API_URL="https://api.dev.moyeobab.com/api/v1/meetings"
TOTAL_REQUESTS=200
ACCESS_TOKEN="${ACCESS_TOKEN:-}"
CSRF_TOKEN="${CSRF_TOKEN:-}"

# ========================= 사용법 =========================
if [ -z "$ACCESS_TOKEN" ] || [ -z "$CSRF_TOKEN" ]; then
    echo "Usage: ACCESS_TOKEN, CSRF_TOKEN 환경변수를 설정 후 실행하세요"
    echo "  export ACCESS_TOKEN='your_jwt_token'"
    echo "  export CSRF_TOKEN='your_csrf_token'"
    exit 1
fi

# ========================= 요청 바디 =========================
REQUEST_BODY='{
  "title": "Rate Limit Test",
  "scheduledAt": "2026-12-31T12:00:00.000Z",
  "locationAddress": "테스트 주소",
  "locationLat": 37.498095,
  "locationLng": 127.02761,
  "targetHeadcount": 4,
  "searchRadiusM": 500,
  "voteDeadlineAt": "2026-12-30T12:00:00.000Z",
  "exceptMeat": false,
  "exceptBar": false,
  "swipeCount": 5,
  "quickMeeting": true
}'

# 임시 디렉토리 생성
RESULT_DIR=$(mktemp -d)
trap "rm -rf $RESULT_DIR" EXIT

echo "=============================================="
echo " Rate Limit Test - POST /api/v1/meetings"
echo " 총 요청: ${TOTAL_REQUESTS}회 (동시 병렬 전송)"
echo " 예상: 1~12회 성공(2r/s + burst 10), 이후 429"
echo "=============================================="
echo ""

# 시작 시간 기록
start_time=$(date "+%H:%M:%S.%3N")
start_epoch=$(date +%s.%N)

echo "[$start_time] 모든 요청 동시 전송 시작..."
echo ""

# ========================= 병렬 요청 전송 =========================
for i in $(seq 1 $TOTAL_REQUESTS); do
    (
        req_time=$(date "+%H:%M:%S.%3N")
        response=$(curl -s -o /dev/null -w "%{http_code}|%{time_connect}|%{time_starttransfer}|%{time_total}" \
            -X POST "$API_URL" \
            -H "Content-Type: application/json" \
            -H "X-CSRF-Token: $CSRF_TOKEN" \
            -b "access_token=$ACCESS_TOKEN; csrf_token=$CSRF_TOKEN" \
            -d "$REQUEST_BODY")
        echo "$i|$req_time|$response" > "$RESULT_DIR/$i.txt"
    ) &
done

# 모든 백그라운드 작업 대기
wait

end_epoch=$(date +%s.%N)
total_duration=$(echo "$end_epoch - $start_epoch" | bc)

echo "=============================================="
printf "%-4s %-12s %-8s %-10s %-10s %-10s\n" "#" "요청시간" "상태" "연결(ms)" "TTFB(ms)" "총(ms)"
echo "--------------------------------------------------------------"

# ========================= 결과 수집 및 출력 =========================
count_200=0
count_201=0
count_429=0
count_other=0
total_time=0

for i in $(seq 1 $TOTAL_REQUESTS); do
    if [ -f "$RESULT_DIR/$i.txt" ]; then
        line=$(cat "$RESULT_DIR/$i.txt")

        req_num=$(echo "$line" | cut -d'|' -f1)
        req_time=$(echo "$line" | cut -d'|' -f2)
        http_code=$(echo "$line" | cut -d'|' -f3)
        time_connect=$(echo "$line" | cut -d'|' -f4)
        time_ttfb=$(echo "$line" | cut -d'|' -f5)
        time_total=$(echo "$line" | cut -d'|' -f6)

        # ms로 변환
        connect_ms=$(echo "$time_connect * 1000" | bc 2>/dev/null | xargs printf "%.1f" 2>/dev/null || echo "0.0")
        ttfb_ms=$(echo "$time_ttfb * 1000" | bc 2>/dev/null | xargs printf "%.1f" 2>/dev/null || echo "0.0")
        total_ms=$(echo "$time_total * 1000" | bc 2>/dev/null | xargs printf "%.1f" 2>/dev/null || echo "0.0")

        total_time=$(echo "$total_time + $time_total" | bc 2>/dev/null || echo "$total_time")

        case $http_code in
            200) ((count_200++)); status="✓ 200" ;;
            201) ((count_201++)); status="✓ 201" ;;
            429) ((count_429++)); status="✗ 429" ;;
            *)   ((count_other++)); status="? $http_code" ;;
        esac

        printf "%-4s %-12s %-8s %-10s %-10s %-10s\n" "[$req_num]" "$req_time" "$status" "$connect_ms" "$ttfb_ms" "$total_ms"
    fi
done | sort -t'[' -k2 -n

# ========================= 결과 출력 =========================
# 다시 카운트 (정렬 때문에 서브쉘에서 카운트가 안 됨)
count_200=0; count_201=0; count_429=0; count_other=0
for i in $(seq 1 $TOTAL_REQUESTS); do
    if [ -f "$RESULT_DIR/$i.txt" ]; then
        http_code=$(cat "$RESULT_DIR/$i.txt" | cut -d'|' -f3)
        case $http_code in
            200) ((count_200++)) ;;
            201) ((count_201++)) ;;
            429) ((count_429++)) ;;
            *)   ((count_other++)) ;;
        esac
    fi
done

avg_time=$(echo "scale=1; $total_time * 1000 / $TOTAL_REQUESTS" | bc 2>/dev/null || echo "0")

echo ""
echo "=============================================="
echo " 테스트 결과"
echo "=============================================="
echo " 200 OK:              $count_200"
echo " 201 Created:         $count_201"
echo " 429 Too Many:        $count_429"
echo " 기타:                $count_other"
echo "----------------------------------------------"
printf " 전체 소요시간:       %.2f초\n" $total_duration
echo " 실제 RPS:            $(echo "scale=1; $TOTAL_REQUESTS / $total_duration" | bc) req/s"
echo "=============================================="

success=$((count_200 + count_201))
echo ""
if [ $count_429 -gt 0 ]; then
    echo "✓ PASS: Rate Limiting 동작 확인"
    echo "  - 성공 요청: ${success}회"
    echo "  - 차단 요청: ${count_429}회"
else
    echo "✗ FAIL: Rate Limiting 미동작"
    echo "  - 모든 요청이 통과됨"
fi

echo ""
echo "서버 로그 확인:"
echo "  ssh root@<SERVER_IP> \"tail -20 /var/log/nginx/error.log | grep limiting\""
