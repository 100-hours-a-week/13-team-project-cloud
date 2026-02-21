#!/usr/bin/env bash
# Route53 가중치 전환 테스트 (k6 없이 전환만 확인)
#
# 사용법:
#   ./v2-container/tests/canary/test-switch.sh phase2   # v1=50, v2=50
#   ./v2-container/tests/canary/test-switch.sh phase3   # v1=0, v2=100
#   ./v2-container/tests/canary/test-switch.sh check    # 현재 가중치 확인
#   ./v2-container/tests/canary/test-switch.sh restore  # v1=100, v2=0 (롤백)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PHASE="${1:-check}"
DOMAIN="api.dev.moyeobab.com"
ALB_NAME="moyeoBab-dev-ALB-v2"

# ─────────────────────────────────────────────
# AWS 리소스 동적 조회
# ─────────────────────────────────────────────
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "dev.moyeobab.com" \
  --query "HostedZones[0].Id" --output text --no-cli-pager | sed 's|/hostedzone/||')

V1_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=moyeoBab-dev-v1-app" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text --no-cli-pager)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].DNSName" \
  --output text --no-cli-pager)

ALB_ZONE=$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].CanonicalHostedZoneId" \
  --output text --no-cli-pager)

# ─────────────────────────────────────────────
# 인라인 change-batch 생성 함수
# ─────────────────────────────────────────────
make_change_batch() {
  local v1_weight=$1
  local v2_weight=$2
  local comment=$3
  cat <<EOF
{
  "Comment": "${comment}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "SetIdentifier": "v1",
        "Weight": ${v1_weight},
        "TTL": 60,
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
}

case "$PHASE" in
  check)
    echo "현재 Route53 가중치 확인 중..."
    aws route53 list-resource-record-sets \
      --hosted-zone-id "$ZONE_ID" \
      --output json \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data['ResourceRecordSets']:
    if 'api.dev.moyeobab.com' in r.get('Name', ''):
        sid = r.get('SetIdentifier', '-')
        w   = r.get('Weight', '-')
        print(f'  {sid}: weight={w}')
"
    ;;

  phase2)
    echo "Phase 2 전환: v1=50, v2=50"
    aws route53 change-resource-record-sets \
      --no-cli-pager \
      --hosted-zone-id "$ZONE_ID" \
      --change-batch "$(make_change_batch 50 50 'Canary Phase 2: v1=50, v2=50')"
    echo "완료. DNS 반영 최대 60초."
    ;;

  phase3)
    echo "Phase 3 전환: v1=0, v2=100"
    aws route53 change-resource-record-sets \
      --no-cli-pager \
      --hosted-zone-id "$ZONE_ID" \
      --change-batch "$(make_change_batch 0 100 'Canary Phase 3: v1=0, v2=100')"
    echo "완료. DNS 반영 최대 60초."
    ;;

  restore)
    echo "롤백: v1=100, v2=0"
    aws route53 change-resource-record-sets \
      --no-cli-pager \
      --hosted-zone-id "$ZONE_ID" \
      --change-batch "$(make_change_batch 100 0 'Canary Restore: v1=100, v2=0')"
    echo "완료. DNS 반영 최대 60초."
    ;;

  *)
    echo "사용법: $0 {check|phase2|phase3|restore}"
    exit 1
    ;;
esac
