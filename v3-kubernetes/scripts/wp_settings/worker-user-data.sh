#!/bin/bash
# =============================================================================
# 워커 노드 user-data 스크립트
# =============================================================================
# 용도: Terraform templatefile()로 주입되어 부팅 시 자동 실행
# 전제: prepare-k8s-ami.sh로 만든 AMI에서 부팅된 인스턴스
#
# 이 스크립트가 하는 일:
#   1. SSM Parameter Store에서 join 토큰/CA hash/CP endpoint 읽기
#   2. CP API 서버 준비 대기
#   3. kubeadm join 실행
#
# Terraform templatefile 변수:
#   - deploy_env: 환경 (prod|dev)
#
# 참조:
#   [1] https://kubernetes.io/ko/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#join-nodes
# =============================================================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

REGION="ap-northeast-2"
DEPLOY_ENV="${deploy_env}"
SSM_PREFIX="/moyeobab/k8s/${DEPLOY_ENV}"

MAX_RETRIES=40
RETRY_INTERVAL=30

echo "============================================="
echo " 워커 노드 자동 join"
echo " 환경: ${DEPLOY_ENV}"
echo "============================================="

# -----------------------------------------------------------------------------
# 1. SSM에서 join 정보 읽기 (CP 준비될 때까지 retry)
# -----------------------------------------------------------------------------
echo "[1/3] SSM에서 join 정보 대기 중..."

for i in $(seq 1 ${MAX_RETRIES}); do
  CP_ENDPOINT=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/cp-endpoint" \
    --query "Parameter.Value" \
    --output text \
    --region ${REGION} 2>/dev/null || echo "")

  if [ -n "$CP_ENDPOINT" ] && [ "$CP_ENDPOINT" != "None" ]; then
    echo "  CP endpoint 확인: ${CP_ENDPOINT} (${i}번째 시도)"
    break
  fi

  echo "  SSM 파라미터 대기 중... (${i}/${MAX_RETRIES}, ${RETRY_INTERVAL}초 후 재시도)"
  sleep ${RETRY_INTERVAL}
done

if [ -z "$CP_ENDPOINT" ] || [ "$CP_ENDPOINT" = "None" ]; then
  echo "ERROR: ${MAX_RETRIES}회 시도 후에도 CP endpoint를 찾을 수 없습니다"
  exit 1
fi

JOIN_TOKEN=$(aws ssm get-parameter \
  --name "${SSM_PREFIX}/join-token" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region ${REGION})

CA_CERT_HASH=$(aws ssm get-parameter \
  --name "${SSM_PREFIX}/ca-cert-hash" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region ${REGION})

echo "  join-token: (loaded)"
echo "  ca-cert-hash: ${CA_CERT_HASH:0:20}..."
echo "  cp-endpoint: ${CP_ENDPOINT}"

# -----------------------------------------------------------------------------
# 2. CP API 서버 포트 대기
# -----------------------------------------------------------------------------
echo ""
echo "[2/3] CP API 서버 (${CP_ENDPOINT}) 대기 중..."

CP_HOST=$(echo ${CP_ENDPOINT} | cut -d: -f1)
CP_PORT=$(echo ${CP_ENDPOINT} | cut -d: -f2)

for i in $(seq 1 ${MAX_RETRIES}); do
  if nc -z -w 5 ${CP_HOST} ${CP_PORT} 2>/dev/null; then
    echo "  API 서버 응답 확인 (${i}번째 시도)"
    break
  fi
  echo "  API 서버 대기 중... (${i}/${MAX_RETRIES})"
  sleep ${RETRY_INTERVAL}
done

# -----------------------------------------------------------------------------
# 3. kubeadm join [1]
# -----------------------------------------------------------------------------
echo ""
echo "[3/3] kubeadm join 실행..."

kubeadm join ${CP_ENDPOINT} \
  --token ${JOIN_TOKEN} \
  --discovery-token-ca-cert-hash ${CA_CERT_HASH}

echo ""
echo "============================================="
echo " 워커 노드 join 완료!"
echo " 로그: /var/log/user-data.log"
echo "============================================="
