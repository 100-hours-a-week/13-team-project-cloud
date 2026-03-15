#!/usr/bin/env bash
# =============================================================================
# Gateway API CRD 설치
# =============================================================================
# 용도: Kubernetes Gateway API 표준 CRD 설치
# 전제: kubeconfig 설정 완료 (kubectl 사용 가능)
#
# 이 스크립트가 하는 일:
#   1. Gateway API 표준 CRD 설치 (GatewayClass, Gateway, HTTPRoute 등)
#
# 사용법:
#   bash install-gateway-api.sh
# =============================================================================

set -euo pipefail

echo "============================================="
echo " Gateway API CRD 설치"
echo "============================================="

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml

echo ""
echo "============================================="
echo " Gateway API CRD 설치 완료!"
echo "============================================="
echo ""
kubectl get crd | grep gateway
