#!/usr/bin/env bash
# 카나리 마이그레이션 부하테스트 실행 스크립트 (Route53 weighted routing 방식)
#
# ALB 방식과의 차이:
#   ALB   → HTTP 요청 레벨 분산 (DNS 캐시 무관)
#   Route53 → DNS 레벨 분산 (OS DNS 캐시 영향 받음)
#
# OS DNS 캐시 우회 방법:
#   1. 실행 전 OS DNS 캐시 초기화 (sudo 필요)
#   2. GODEBUG=netdns=go — Go 순수 DNS 리졸버 사용 → mDNSResponder 캐시 우회
#   3. canary-migration-route53.js 의 dns.ttl=0s — k6 내부 DNS 캐시 비활성화
#
# 사전 준비:
#   1. terraform apply 완료 (dns.tf: api_v1 weight, api_v2 alias 레코드 존재)
#   2. V1 EC2 서비스 정상 동작 확인 (V1_IP는 AWS CLI로 자동 조회)
#   3. V2 ALB → V2 backend healthy 확인
#
# 실행:
#   chmod +x run-canary-route53.sh
#   ./v2-container/tests/canary/run-canary-route53.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN="api.dev.moyeobab.com"
ALB_NAME="moyeoBab-dev-ALB-v2"
V1_TG_NAME="moyeoBab-dev-WAS-v1"
V2_TG_NAME="moyeoBab-dev-WAS-v2"

# ─────────────────────────────────────────────
# AWS 리소스 동적 조회
# ─────────────────────────────────────────────
echo "AWS 리소스 정보 조회 중..."

ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "dev.moyeobab.com" \
  --query "HostedZones[0].Id" --output text --no-cli-pager | sed 's|/hostedzone/||')

V1_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=moyeoBab-dev-v1-app" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text --no-cli-pager)

ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text --no-cli-pager)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].DNSName" \
  --output text --no-cli-pager)

ALB_ZONE=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].CanonicalHostedZoneId" \
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

echo "  ALB DNS  : $ALB_DNS"
echo "  ALB Zone : $ALB_ZONE"
echo "  V1 TG    : $V1_TG_ARN"
echo "  V2 TG    : $V2_TG_ARN"

# ─────────────────────────────────────────────
# 가중치 변경 함수 (Route53 UPSERT)
# V1: 일반 A 레코드 / V2: ALB alias 레코드
#
# TTL 파라미터:
#   테스트 중: TTL=1s → 외부 리졸버(8.8.8.8)도 매초 Route53 재질의
#              → GODEBUG=netdns=go + dns.ttl=0s 와 결합 시 요청 레벨 분산 가능
#   테스트 후: TTL=60s 복원
# ─────────────────────────────────────────────
set_weights() {
  local v1_weight=$1
  local v2_weight=$2
  local ttl=${3:-1}   # 기본값 1s (테스트 중 외부 리졸버 캐시 최소화)

  aws route53 change-resource-record-sets \
    --no-cli-pager \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "SetIdentifier": "v1",
        "Weight": ${v1_weight},
        "TTL": ${ttl},
        "ResourceRecords": [{"Value": "${V1_IP}"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "SetIdentifier": "v2",
        "Weight": ${v2_weight},
        "AliasTarget": {
          "HostedZoneId": "${ALB_ZONE}",
          "DNSName": "${ALB_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF
)" > /dev/null

  echo "✅ Route53 가중치 변경: V1=$v1_weight / V2=$v2_weight (TTL=${ttl}s)"
}

# ─────────────────────────────────────────────
# 테스트 종료 시 TTL 복원 (trap)
# ─────────────────────────────────────────────
restore_ttl() {
  echo ""
  echo "  TTL 복원 중 (1s → 60s)..."
  set_weights 0 100 60   # 마지막 상태(V2=100) 유지하며 TTL만 복원
  echo "  ✅ TTL 복원 완료"
}
trap restore_ttl EXIT

# ─────────────────────────────────────────────
# ALB 가중치 고정 함수
# Route53 카나리에서 ALB는 V2=100으로 고정:
#   Route53 V2 레코드 → ALB → V2 백엔드 (고정)
#   Route53 V1 레코드 → V1 EC2 직접 (ALB 미경유)
# ─────────────────────────────────────────────
set_alb_weights() {
  local v1_weight=$1
  local v2_weight=$2

  aws elbv2 modify-listener \
    --no-cli-pager \
    --listener-arn "$LISTENER_ARN" \
    --default-actions '[{"Type":"forward","ForwardConfig":{"TargetGroups":[{"TargetGroupArn":"'"$V1_TG_ARN"'","Weight":'"$v1_weight"'},{"TargetGroupArn":"'"$V2_TG_ARN"'","Weight":'"$v2_weight"'}],"TargetGroupStickinessConfig":{"Enabled":false,"DurationSeconds":1}}}]' \
    > /dev/null

  echo "✅ ALB 가중치 고정: V1=$v1_weight / V2=$v2_weight"
}

# ─────────────────────────────────────────────
# 사전 설정: ALB V2=100 고정
# Route53 → ALB 경로로 오는 트래픽은 무조건 V2 백엔드로
# (Route53 V1 레코드 → V1 EC2 직접, Route53 V2 레코드 → ALB → V2)
# ─────────────────────────────────────────────
echo ""
echo "  ALB V2=100 고정 중... (Route53 V2 레코드 경로 전용)"
set_alb_weights 0 100

# ─────────────────────────────────────────────
# Phase 1: V1=100, V2=0 (기준선 — 모두 V1 EC2 직접)
# ─────────────────────────────────────────────
echo ""
echo "  Phase 1 시작 전 Route53 V1=100 설정..."
set_weights 100 0

# OS DNS 캐시 초기화 (macOS) — sudo 필요
echo ""
echo "  OS DNS 캐시 초기화 중... (sudo 필요)"
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder 2>/dev/null || {
  echo "  ⚠️  캐시 초기화 실패 (sudo 없음). DNS TTL 만료(60초) 후 진행 권장."
}

echo "  DNS 전파 대기 (5초)..."
sleep 5

# ─────────────────────────────────────────────
# k6 실행 (백그라운드)
# GODEBUG=netdns=go : Go 순수 DNS 리졸버 → macOS mDNSResponder 캐시 완전 우회
# ─────────────────────────────────────────────
REPORT="canary-migration-route53-$(date +%Y%m%d-%H%M).html"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Route53 카나리 마이그레이션 테스트 시작"
echo "  DNS 방식: GODEBUG=netdns=go (Go 순수 리졸버, OS 캐시 우회)"
echo "  보고서: $SCRIPT_DIR/$REPORT"
echo "═══════════════════════════════════════════════════════════"
echo ""

GODEBUG=netdns=go \
K6_WEB_DASHBOARD=true \
K6_WEB_DASHBOARD_EXPORT="$SCRIPT_DIR/$REPORT" \
k6 run "$SCRIPT_DIR/canary-migration-route53.js" &

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
