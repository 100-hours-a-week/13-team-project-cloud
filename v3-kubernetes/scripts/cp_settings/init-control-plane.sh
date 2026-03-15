#!/usr/bin/env bash
# =============================================================================
# 컨트롤 플레인 초기화 스크립트
# =============================================================================
# 용도: CP 인스턴스에 SSH 접속 후 수동 실행
# 전제: prepare-k8s-ami.sh로 만든 AMI에서 부팅된 인스턴스
#
# 이 스크립트가 하는 일:
#   1. kubeadm init (Flannel CIDR 10.244.0.0/16)
#   2. kubeconfig 설정
#   3. Flannel CNI 설치
#   4. join 토큰 + CA hash를 SSM Parameter Store에 저장
#
# 참조:
#   [1] https://kubernetes.io/ko/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
#   [2] https://github.com/flannel-io/flannel#deploying-flannel-manually
#
# 사용법:
#   sudo bash init-control-plane.sh <ENVIRONMENT>
#   예: sudo bash init-control-plane.sh prod
# =============================================================================

set -euo pipefail
exec > >(tee /var/log/init-control-plane.log) 2>&1

# -----------------------------------------------------------------------------
# 인자 확인
# -----------------------------------------------------------------------------
DEPLOY_ENV="${1:-}"
if [ -z "$DEPLOY_ENV" ]; then
  echo "ERROR: 환경을 지정하세요"
  echo "  사용법: sudo bash $0 <prod|dev>"
  exit 1
fi

REGION="ap-northeast-2"
SSM_PREFIX="/moyeobab/k8s/${DEPLOY_ENV}"
POD_NETWORK_CIDR="10.244.0.0/16"

echo "============================================="
echo " 컨트롤 플레인 초기화"
echo " 환경: ${DEPLOY_ENV}"
echo " Pod CIDR: ${POD_NETWORK_CIDR}"
echo "============================================="

# -----------------------------------------------------------------------------
# 0. 사전 확인
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: root 권한으로 실행하세요 (sudo bash $0 ${DEPLOY_ENV})"
  exit 1
fi

if kubectl get nodes &>/dev/null; then
  echo "ERROR: 이미 클러스터가 초기화되어 있습니다"
  echo "  리셋하려면: sudo kubeadm reset -f"
  exit 1
fi

# -----------------------------------------------------------------------------
# 1. kubeadm init [1]
# -----------------------------------------------------------------------------
echo ""
echo "[1/4] kubeadm init..."
kubeadm init --pod-network-cidr=${POD_NETWORK_CIDR}

# -----------------------------------------------------------------------------
# 2. kubeconfig 설정 [1]
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] kubeconfig 설정..."

# root용
export KUBECONFIG=/etc/kubernetes/admin.conf

# ubuntu 사용자용
KUBE_USER="ubuntu"
KUBE_HOME="/home/${KUBE_USER}"
mkdir -p ${KUBE_HOME}/.kube
cp /etc/kubernetes/admin.conf ${KUBE_HOME}/.kube/config
chown -R $(id -u ${KUBE_USER}):$(id -g ${KUBE_USER}) ${KUBE_HOME}/.kube

echo "  - root: KUBECONFIG=/etc/kubernetes/admin.conf"
echo "  - ${KUBE_USER}: ${KUBE_HOME}/.kube/config"

# -----------------------------------------------------------------------------
# 3. Flannel CNI 설치 [2]
#    이걸 안 하면 노드가 NotReady 상태로 남음
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] Flannel CNI 설치..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 노드 Ready 대기
echo "  노드 Ready 대기 중..."
for i in $(seq 1 60); do
  STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
  if [ "$STATUS" = "True" ]; then
    echo "  노드 Ready (${i}초)"
    break
  fi
  sleep 1
done

# -----------------------------------------------------------------------------
# 4. join 정보를 SSM Parameter Store에 저장
#    워커 노드 user-data에서 이 값을 읽어 자동 join
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] join 정보 SSM 저장..."

# join 토큰 생성 (만료 없음 — dev 환경, ASG 자동 join용)
JOIN_TOKEN=$(kubeadm token create --ttl 0)

# CA cert hash
CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex \
  | sed 's/^.* //')

# CP endpoint (자기 자신의 private IP)
CP_ENDPOINT=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'):6443

# SSM에 저장
aws ssm put-parameter \
  --name "${SSM_PREFIX}/join-token" \
  --type "SecureString" \
  --value "${JOIN_TOKEN}" \
  --overwrite \
  --region ${REGION}

aws ssm put-parameter \
  --name "${SSM_PREFIX}/ca-cert-hash" \
  --type "SecureString" \
  --value "sha256:${CA_CERT_HASH}" \
  --overwrite \
  --region ${REGION}

aws ssm put-parameter \
  --name "${SSM_PREFIX}/cp-endpoint" \
  --type "String" \
  --value "${CP_ENDPOINT}" \
  --overwrite \
  --region ${REGION}

echo "  - ${SSM_PREFIX}/join-token (SecureString)"
echo "  - ${SSM_PREFIX}/ca-cert-hash (SecureString)"
echo "  - ${SSM_PREFIX}/cp-endpoint (String): ${CP_ENDPOINT}"

# -----------------------------------------------------------------------------
# 결과 출력
# -----------------------------------------------------------------------------
echo ""
echo "============================================="
echo " 컨트롤 플레인 초기화 완료!"
echo "============================================="
echo ""
kubectl get nodes -o wide
echo ""
kubectl get pods -n kube-system
echo ""
echo " join 정보가 SSM에 저장되었습니다."
echo " 워커 노드는 user-data에서 자동으로 join합니다."
echo ""
echo " 수동 join이 필요하면:"
echo "   sudo kubeadm join ${CP_ENDPOINT} \\"
echo "     --token ${JOIN_TOKEN} \\"
echo "     --discovery-token-ca-cert-hash sha256:${CA_CERT_HASH}"
echo ""
echo " 토큰 만료 시 재생성:"
echo "   sudo kubeadm token create --print-join-command"
echo "============================================="
