#!/usr/bin/env bash
# =============================================================================
# Traefik Helm 설치
# =============================================================================
# 용도: Traefik Ingress Controller를 Helm으로 설치
# 전제: kubectl, Gateway API CRD, AWS LB Controller 설치 완료
#
# 이 스크립트가 하는 일:
#   1. Helm 설치 (없으면)
#   2. Traefik Helm repo 추가
#   3. Traefik 설치 (values-dev.yaml 참조)
#
# 사용법:
#   bash install-traefik.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/../../k8s/charts/traefik/values-dev.yaml"

echo "============================================="
echo " Traefik Helm 설치"
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
# 2. Traefik Helm repo 추가
# -----------------------------------------------------------------------------
echo ""
echo "[2/3] Traefik Helm repo 추가..."
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update

# -----------------------------------------------------------------------------
# 3. Traefik 설치
#    --skip-crds: Gateway API CRD 이미 설치됨
# -----------------------------------------------------------------------------
echo ""
echo "[3/3] Traefik 설치..."
helm install traefik traefik/traefik \
  -n traefik --create-namespace \
  --skip-crds \
  -f "${VALUES_FILE}"

echo ""
echo "============================================="
echo " Traefik 설치 완료!"
echo "============================================="
echo ""
kubectl get pods -n traefik
echo ""
kubectl get svc -n traefik
