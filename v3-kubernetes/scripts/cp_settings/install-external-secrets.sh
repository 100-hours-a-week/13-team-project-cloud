#!/usr/bin/env bash
# =============================================================================
# External Secrets Operator Helm 설치
# =============================================================================
# 용도: ESO를 Helm으로 설치 (SSM Parameter Store → K8s Secret 자동 sync)
# 전제: kubectl, Helm 설치 완료
#
# 이 스크립트가 하는 일:
#   1. Helm 설치 확인
#   2. ESO Helm repo 추가
#   3. ESO 설치 (values-dev.yaml 참조)
#
# 사용법:
#   bash install-external-secrets.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALUES_FILE=""
# 레포 클론에서 실행 시 상대경로로 values 파일 탐색
CANDIDATE="${SCRIPT_DIR}/../../k8s/charts/external-secrets/values-dev.yaml"
if [ -f "${CANDIDATE}" ]; then
  VALUES_FILE="$(cd "$(dirname "${CANDIDATE}")" && pwd)/values-dev.yaml"
fi

echo "============================================="
echo " External Secrets Operator Helm 설치"
echo "============================================="

# -----------------------------------------------------------------------------
# 1. Helm 설치 확인
# -----------------------------------------------------------------------------
if ! command -v helm &>/dev/null; then
  echo "[1/3] Helm 설치..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "[1/3] Helm 이미 설치됨: $(helm version --short)"
fi

# -----------------------------------------------------------------------------
# 2. ESO Helm repo 추가
# -----------------------------------------------------------------------------
echo ""
echo "[2/3] External Secrets Helm repo 추가..."
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

# -----------------------------------------------------------------------------
# 3. ESO 설치
# -----------------------------------------------------------------------------
echo ""
echo "[3/3] External Secrets Operator 설치..."
if [ -n "${VALUES_FILE}" ] && [ -f "${VALUES_FILE}" ]; then
  echo "  values 파일: ${VALUES_FILE}"
  helm install external-secrets external-secrets/external-secrets \
    -n external-secrets --create-namespace \
    -f "${VALUES_FILE}"
else
  echo "  values 파일 없음 — --set 옵션으로 설치"
  helm install external-secrets external-secrets/external-secrets \
    -n external-secrets --create-namespace \
    --set webhook.create=false \
    --set certController.create=false \
    --set replicaCount=1
fi

# Pod Ready 대기
echo "  Pod Ready 대기 중..."
kubectl wait --for=condition=Ready pods --all -n external-secrets --timeout=120s

echo ""
echo "============================================="
echo " External Secrets Operator 설치 완료!"
echo "============================================="
echo ""
kubectl get pods -n external-secrets
echo ""
echo " SecretStore + ExternalSecret은 앱 배포 시 kustomize로 적용됩니다."
echo "============================================="
