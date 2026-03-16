#!/usr/bin/env bash
# =============================================================================
# ArgoCD Helm 설치
# =============================================================================
# 용도: ArgoCD를 Helm으로 설치
# 전제: kubectl, Helm 설치 완료
#
# 이 스크립트가 하는 일:
#   1. Helm 설치 확인
#   2. ArgoCD Helm repo 추가
#   3. ArgoCD 설치 (values-dev.yaml 참조)
#   4. 초기 admin 비밀번호 출력
#
# 사용법:
#   bash install-argocd.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALUES_FILE=""
# 레포 클론에서 실행 시 상대경로로 values 파일 탐색
CANDIDATE="${SCRIPT_DIR}/../../k8s/charts/argocd/values-dev.yaml"
if [ -f "${CANDIDATE}" ]; then
  VALUES_FILE="$(cd "$(dirname "${CANDIDATE}")" && pwd)/values-dev.yaml"
fi

echo "============================================="
echo " ArgoCD Helm 설치"
echo "============================================="

# -----------------------------------------------------------------------------
# 1. Helm 설치 확인
# -----------------------------------------------------------------------------
if ! command -v helm &>/dev/null; then
  echo "[1/4] Helm 설치..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "[1/4] Helm 이미 설치됨: $(helm version --short)"
fi

# -----------------------------------------------------------------------------
# 2. ArgoCD Helm repo 추가
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] ArgoCD Helm repo 추가..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

# -----------------------------------------------------------------------------
# 3. ArgoCD 설치
# -----------------------------------------------------------------------------
echo ""
echo "[3/4] ArgoCD 설치..."
if [ -n "${VALUES_FILE}" ] && [ -f "${VALUES_FILE}" ]; then
  echo "  values 파일: ${VALUES_FILE}"
  helm install argocd argo/argo-cd \
    -n argocd --create-namespace \
    -f "${VALUES_FILE}"
else
  echo "  values 파일 없음 — --set 옵션으로 설치"
  helm install argocd argo/argo-cd \
    -n argocd --create-namespace \
    --set server.service.type=NodePort \
    --set server.service.nodePortHttp=30090 \
    --set server.service.nodePortHttps=30091 \
    --set dex.enabled=false \
    --set applicationSet.enabled=false \
    --set notifications.enabled=true \
    --set 'configs.params.server\.insecure=true'
fi

# Pod Ready 대기
echo "  Pod Ready 대기 중..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# -----------------------------------------------------------------------------
# 4. 초기 admin 비밀번호 출력
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] 초기 admin 비밀번호..."
ADMIN_PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "============================================="
echo " ArgoCD 설치 완료!"
echo "============================================="
echo ""
echo " 접속: http://<NODE_IP>:30090"
echo " ID: admin"
echo " PW: ${ADMIN_PW}"
echo ""
echo " CLI 로그인:"
echo "   argocd login <NODE_IP>:30090 --insecure --username admin --password '${ADMIN_PW}'"
echo ""
echo " 비밀번호 변경 후 초기 secret 삭제:"
echo "   argocd account update-password"
echo "   kubectl -n argocd delete secret argocd-initial-admin-secret"
echo "============================================="
