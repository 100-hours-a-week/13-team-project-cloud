#!/usr/bin/env bash
# 카나리 마이그레이션 부하테스트 실행 스크립트 (ALB weighted routing 방식)
#
# 사전 준비:
#   1. terraform apply 완료 (V1 TG, weighted listener 생성)
#   2. V1 backend SG에 moyeobab-dev-alb-sg 포트 8080 inbound 추가
#   3. V1 TG 헬스체크 healthy 확인 (EC2 > Target Groups > moyeoBab-dev-WAS-v1)
#
# 실행:
#   chmod +x run-canary.sh
#   ./v2-container/tests/canary/run-canary.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALB_NAME="moyeoBab-dev-ALB-v2"
V1_TG_NAME="moyeoBab-dev-WAS-v1"
V2_TG_NAME="moyeoBab-dev-WAS-v2"

# ─────────────────────────────────────────────
# ARN 조회
# ─────────────────────────────────────────────
echo "AWS 리소스 ARN 조회 중..."

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text --no-cli-pager)

LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`443\`].ListenerArn" \
  --output text --no-cli-pager)

V1_TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$V1_TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text --no-cli-pager)

V2_TG_ARN=$(aws elbv2 describe-target-groups \
  --names "$V2_TG_NAME" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text --no-cli-pager)

echo "  Listener : $LISTENER_ARN"
echo "  V1 TG    : $V1_TG_ARN"
echo "  V2 TG    : $V2_TG_ARN"

# ─────────────────────────────────────────────
# 가중치 변경 함수
# ─────────────────────────────────────────────
set_weights() {
  local v1_weight=$1
  local v2_weight=$2

  aws elbv2 modify-listener \
    --no-cli-pager \
    --listener-arn "$LISTENER_ARN" \
    --default-actions '[{"Type":"forward","ForwardConfig":{"TargetGroups":[{"TargetGroupArn":"'"$V1_TG_ARN"'","Weight":'"$v1_weight"'},{"TargetGroupArn":"'"$V2_TG_ARN"'","Weight":'"$v2_weight"'}],"TargetGroupStickinessConfig":{"Enabled":false,"DurationSeconds":1}}}]' \
    > /dev/null

  echo "✅ ALB 가중치 변경: V1=$v1_weight / V2=$v2_weight (즉시 반영)"
}

# ─────────────────────────────────────────────
# Phase 1 확인 (V1=100이어야 정상 시작 — 프로덕션은 V1)
# ─────────────────────────────────────────────
echo ""
echo "  Phase 1 시작 전 V1=100 확인..."
set_weights 100 0

# ─────────────────────────────────────────────
# k6 실행 (백그라운드)
# ─────────────────────────────────────────────
REPORT="canary-migration-$(date +%Y%m%d-%H%M).html"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  카나리 마이그레이션 테스트 시작"
echo "  보고서: $SCRIPT_DIR/$REPORT"
echo "═══════════════════════════════════════════════════════════"
echo ""

K6_WEB_DASHBOARD=true \
K6_WEB_DASHBOARD_EXPORT="$SCRIPT_DIR/$REPORT" \
k6 run "$SCRIPT_DIR/canary-migration.js" &

K6_PID=$!
START_TIME=$(date +%s)

# ─────────────────────────────────────────────
# Phase 2: 3분 후 V1=50 / V2=50
# ─────────────────────────────────────────────
echo "⏳ Phase 2 전환까지 3분 대기..."
sleep 180

echo ""
echo "🔄 Phase 2: V1=50 / V2=50 카나리 시작..."
set_weights 50 50

# ─────────────────────────────────────────────
# Phase 3: 3분 후 V1=0 / V2=100 (마이그레이션 완료)
# ─────────────────────────────────────────────
echo ""
echo "⏳ Phase 3 전환까지 3분 대기..."
sleep 180

echo ""
echo "🔄 Phase 3: V1=0 / V2=100 — 마이그레이션 완료"
set_weights 0 100

# ─────────────────────────────────────────────
# k6 완료 대기
# ─────────────────────────────────────────────
wait $K6_PID
ELAPSED=$(( ($(date +%s) - START_TIME) / 60 ))

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  테스트 완료: ${ELAPSED}분"
echo "  보고서: $SCRIPT_DIR/$REPORT"
echo "  Grafana: http://10.1.0.251:3000/d/v1-v2-migration"
echo "═══════════════════════════════════════════════════════════"
