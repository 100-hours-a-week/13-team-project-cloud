SHELL := /bin/bash
REGION := ap-northeast-2
NS := moyeobab
ENV ?= prod

.PHONY: help
help: ## 사용 가능한 명령어 목록
	@echo ""
	@echo "  moyeobab v3 운영 도구 (ENV=$(ENV))"
	@echo "  ─────────────────────────────────"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  환경 변경: make <명령> ENV=dev"
	@echo ""

# =============================================================================
# 상태 확인
# =============================================================================
status: ## ArgoCD 앱 + Pod 상태 확인
	@echo "=== ArgoCD Apps ==="
	@kubectl get apps -n argocd
	@echo ""
	@echo "=== Pods ($(NS)) ==="
	@kubectl get pods -n $(NS) -o wide
	@echo ""
	@echo "=== Nodes ==="
	@kubectl get nodes -o wide

logs-be: ## backend 로그 (실시간)
	kubectl logs -f -l app=backend -n $(NS) --tail=100

logs-rc: ## recommend 로그 (실시간)
	kubectl logs -f -l app=recommend -n $(NS) --tail=100

# =============================================================================
# 시크릿 / ESO
# =============================================================================
sync-secrets: ## ExternalSecret 강제 갱신 (backend + recommend)
	@echo "=== ESO 강제 갱신 ==="
	kubectl annotate externalsecret backend-secret force-sync=$$(date +%s) --overwrite -n $(NS)
	kubectl annotate externalsecret recommend-secret force-sync=$$(date +%s) --overwrite -n $(NS)
	@echo "10초 대기..."
	@sleep 10
	@echo "=== Secret 상태 ==="
	kubectl get externalsecret -n $(NS)

sync-and-restart: ## 시크릿 갱신 + Pod 재시작 (키 변경 시)
	@$(MAKE) sync-secrets
	@echo "=== Pod 재시작 ==="
	kubectl rollout restart deployment/backend -n $(NS)
	kubectl rollout restart deployment/recommend -n $(NS)
	kubectl rollout status deployment/backend -n $(NS) --timeout=300s
	kubectl rollout status deployment/recommend -n $(NS) --timeout=300s

ssm-list-be: ## backend SSM 파라미터 목록
	aws ssm get-parameters-by-path --path "/moyeobab/spring/$(ENV)/" --query "Parameters[].Name" --output table --region $(REGION)

ssm-list-rc: ## recommend SSM 파라미터 목록
	aws ssm get-parameters-by-path --path "/moyeobab/recommend/$(ENV)/" --query "Parameters[].Name" --output table --region $(REGION)

ssm-get: ## SSM 파라미터 값 조회 (make ssm-get KEY=/moyeobab/spring/prod/DB_HOST)
	aws ssm get-parameter --name "$(KEY)" --with-decryption --query "Parameter.Value" --output text --region $(REGION)

# =============================================================================
# 배포 / 재시작
# =============================================================================
restart-be: ## backend Pod 재시작
	kubectl rollout restart deployment/backend -n $(NS)
	kubectl rollout status deployment/backend -n $(NS) --timeout=300s

restart-rc: ## recommend Pod 재시작
	kubectl rollout restart deployment/recommend -n $(NS)
	kubectl rollout status deployment/recommend -n $(NS) --timeout=300s

restart-all: ## 전체 Pod 재시작
	@$(MAKE) restart-be
	@$(MAKE) restart-rc

# =============================================================================
# ECR
# =============================================================================
ecr-tags-be: ## backend ECR 이미지 태그 목록
	aws ecr describe-images --repository-name moyeobab/backend --query "sort_by(imageDetails,&imagePushedAt)[-5:].imageTags" --output table --region $(REGION)

ecr-tags-rc: ## recommend ECR 이미지 태그 목록
	aws ecr describe-images --repository-name moyeobab/recommend --query "sort_by(imageDetails,&imagePushedAt)[-5:].imageTags" --output table --region $(REGION)

# =============================================================================
# 디버그
# =============================================================================
describe-be: ## backend Pod describe
	kubectl describe pod -l app=backend -n $(NS)

describe-rc: ## recommend Pod describe
	kubectl describe pod -l app=recommend -n $(NS)

events: ## 최근 이벤트 (에러 디버깅)
	kubectl get events -n $(NS) --sort-by='.lastTimestamp' | tail -20

top: ## 노드/Pod 리소스 사용량
	@echo "=== Node ==="
	@kubectl top nodes 2>/dev/null || echo "metrics-server 미설치"
	@echo ""
	@echo "=== Pods ==="
	@kubectl top pods -n $(NS) 2>/dev/null || echo "metrics-server 미설치"
