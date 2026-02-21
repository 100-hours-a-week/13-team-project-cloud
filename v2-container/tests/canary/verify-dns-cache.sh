#!/usr/bin/env bash
# OS 레벨 DNS 캐싱 검증 스크립트
#
# 목적:
#   Route53 weighted routing(V1=50/V2=50)이 설정된 상태에서
#   OS 리졸버 캐시가 트래픽 분산을 방해하는지 검증
#
# 핵심 차이:
#   - curl: OS resolver 캐시 사용 (실제 HTTP 요청과 동일한 경로)
#   - dig:  OS resolver 캐시 우회 (DNS 직접 질의)
#   → curl이 단일 IP를 고정하면 OS DNS 캐싱이 원인임을 입증
#
# 사전 조건:
#   - terraform apply (dns.tf: api_v1 weight=50, api_v2 weight=50)
#   - DNS TTL 60초 적용 완료 확인
#
# 실행:
#   chmod +x verify-dns-cache.sh
#   ./v2-container/tests/canary/verify-dns-cache.sh

set -e

DOMAIN="api.dev.moyeobab.com"
HEALTH_URL="https://${DOMAIN}/api/v1/health"
ITERATIONS=15

# V1 퍼블릭 IP 동적 조회
V1_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=moyeoBab-dev-v1-app" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text --no-cli-pager)
SLEEP_INTERVAL=0.3

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  OS DNS 캐싱 검증 — Route53 Weighted Routing (V1=50/V2=50)"
echo "  도메인: $DOMAIN"
echo "═══════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────
# 1. curl — OS resolver 캐시 통한 실제 HTTP 연결
#    dig와 달리 curl은 OS resolver 캐시를 사용함
#    캐시가 있으면 항상 같은 서버 IP로 연결됨
# ─────────────────────────────────────────────
echo ""
echo "[ 1 ] curl — OS resolver 캐시 통한 HTTP 연결 (${ITERATIONS}회)"
echo "      → dig는 캐시를 우회하지만 curl은 캐시를 사용함"
echo "      → 같은 IP만 나오면 OS 캐시에 고정된 것 (문제 원인 확인)"
echo ""

os_results=()
for i in $(seq 1 $ITERATIONS); do
  ip=$(curl -s "$HEALTH_URL" --connect-timeout 3 -w "%{remote_ip}" -o /dev/null 2>/dev/null || echo "error")
  os_results+=("$ip")
  if [ "$ip" = "$V1_IP" ]; then
    label="V1(EC2)"
  elif [ "$ip" = "error" ]; then
    label="(연결 실패)"
  else
    label="V2(ALB)"
  fi
  printf "  [%02d] %-18s %s\n" "$i" "$ip" "$label"
  sleep $SLEEP_INTERVAL
done

os_unique=$(printf '%s\n' "${os_results[@]}" | grep -v error | sort -u | wc -l | tr -d ' ')
echo ""
if [ "$os_unique" -eq 1 ]; then
  echo "  ⚠️  결과: IP가 ${ITERATIONS}회 모두 동일 → OS 캐시에 고정됨 (DNS 캐싱 문제 확인)"
else
  echo "  ✅  결과: ${os_unique}개의 다른 IP 반환 → 캐시 미적용 or TTL 만료"
fi

# ─────────────────────────────────────────────
# 2. Route53 직접 조회 (OS 캐시 우회)
#    8.8.8.8을 통해 직접 질의 → Route53이 weight대로 응답하는지 확인
# ─────────────────────────────────────────────
echo ""
echo "[ 2 ] Route53 직접 조회 (${ITERATIONS}회) — 8.8.8.8 경유"
echo "      → V1/V2 IP가 번갈아 나오면 Route53 자체는 정상"
echo ""

direct_results=()
v1_count=0
v2_count=0
for i in $(seq 1 $ITERATIONS); do
  ip=$(dig +short @8.8.8.8 "$DOMAIN" | tail -1)
  direct_results+=("$ip")
  if [ "$ip" = "$V1_IP" ]; then
    label="V1(EC2)"
    v1_count=$((v1_count + 1))
  else
    label="V2(ALB)"
    v2_count=$((v2_count + 1))
  fi
  printf "  [%02d] %-18s %s\n" "$i" "$ip" "$label"
  sleep $SLEEP_INTERVAL
done

echo ""
echo "  Route53 응답 분포: V1=${v1_count}/${ITERATIONS}  V2=${v2_count}/${ITERATIONS}"
direct_unique=$(printf '%s\n' "${direct_results[@]}" | sort -u | wc -l | tr -d ' ')
if [ "$direct_unique" -gt 1 ]; then
  echo "  ✅  Route53 weighted routing 정상 동작 (가중치대로 분산)"
else
  echo "  ⚠️  Route53 응답이 단일 IP → 가중치 미적용 또는 하나의 레코드만 활성"
fi

# ─────────────────────────────────────────────
# 3. OS DNS 캐시 통계 (환경별)
# ─────────────────────────────────────────────
echo ""
echo "[ 3 ] OS DNS 캐시 통계"
echo ""
if command -v resolvectl &>/dev/null; then
  # Linux (systemd-resolved)
  echo "  [Linux / systemd-resolved]"
  resolvectl statistics 2>/dev/null | grep -A 8 "Transactions\|Cache\|DNSSEC" || echo "  (통계 조회 불가)"
elif command -v dscacheutil &>/dev/null; then
  # macOS (mDNSResponder)
  echo "  [macOS / mDNSResponder]"
  dscacheutil -statistics 2>/dev/null || echo "  (통계 조회 불가)"
  echo ""
  echo "  캐시 초기화: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
else
  echo "  DNS 캐시 관리 도구를 찾을 수 없음"
fi

# ─────────────────────────────────────────────
# 최종 판정
# ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  최종 판정"
echo "═══════════════════════════════════════════════════════════"
if [ "$os_unique" -eq 1 ] && [ "$direct_unique" -gt 1 ]; then
  echo ""
  echo "  ✅ OS DNS 캐싱 확인됨"
  echo ""
  echo "  - curl (OS resolver): 같은 IP 고정 → 캐시가 분산을 차단"
  echo "  - dig @8.8.8.8 (직접): V1/V2 분산 정상 → Route53 자체는 올바름"
  echo ""
  echo "  결론: 단일 머신에서 Route53 weighted routing으로"
  echo "        실제 트래픽 분산이 불가능한 근본 원인 입증"
  echo "  해결: ALB Weighted Target Group (HTTP 요청 레벨 분산)"
elif [ "$os_unique" -gt 1 ] && [ "$direct_unique" -gt 1 ]; then
  echo ""
  echo "  ℹ️  DNS 캐시 미확인 (TTL 만료 또는 캐시 비활성)"
  echo ""
  echo "  - curl (OS resolver): 분산 발생 (캐시 만료 or 비활성)"
  echo "  - dig @8.8.8.8 (직접): V1/V2 분산 정상"
  echo "  → 캐시가 만료된 상태. 캐시 초기화 후 즉시 재실행 권장:"
  echo "     macOS: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
  echo "     Linux: resolvectl flush-caches"
else
  echo ""
  echo "  ❓ 결과 불명확 — 추가 분석 필요"
fi
echo ""
