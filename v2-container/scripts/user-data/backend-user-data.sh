#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

REGION="ap-northeast-2"
DEPLOY_ENV="${deploy_env}"
COMPOSE_DIR="/home/ubuntu/backend"
SSM_PREFIX="/moyeobab/spring/${DEPLOY_ENV}"

echo "=== Backend User Data Start ==="

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed"
  exit 1
fi

mkdir -p ${COMPOSE_DIR}

# S3에서 docker-compose.yml 등 설정 파일 가져오기
aws s3 sync s3://moyeobab-${DEPLOY_ENV}-config/backend/ ${COMPOSE_DIR}/ --exclude '.env' --region ${REGION}

# Parameter Store → .env 생성
> ${COMPOSE_DIR}/.env
for param in DB_URL DB_USERNAME DB_PASSWORD REDIS_HOST REDIS_PORT REDIS_PASSWORD JWT_SECRET JWT_ISSUER JWT_ACCESS_TOKEN_EXPIRE_MINUTES JWT_COOKIE_NAME JWT_COOKIE_SAME_SITE JWT_COOKIE_SECURE JWT_REFRESH_COOKIE_NAME JWT_REFRESH_TOKEN_EXPIRE_DAYS KAKAO_CLIENT_ID KAKAO_CLIENT_SECRET KAKAO_ADMIN_KEY KAKAO_REDIRECT_URI KAKAO_FRONTEND_REDIRECT_URL KAKAO_UNLINK_URL CSRF_COOKIE_DOMAIN AI_RECOMMENDATION_BASE_URL IMAGE_TAG; do
  val=$(aws ssm get-parameter --name ${SSM_PREFIX}/${param} --with-decryption --query "Parameter.Value" --output text --region ${REGION})
  echo "${param}=${val}" >> ${COMPOSE_DIR}/.env
done

# ECR login
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${REGION}.amazonaws.com
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
echo "ECR_REGISTRY=${ECR_REGISTRY}" >> ${COMPOSE_DIR}/.env

# Deploy
cd ${COMPOSE_DIR} && docker compose pull && docker compose up -d

# Health check
sleep 30
if curl -sf --retry 10 --retry-delay 5 --retry-all-errors http://localhost:8080/actuator/health; then
  echo "=== Backend User Data Complete — Health check passed ==="
  docker image prune -f
else
  echo "=== Backend User Data Complete — Health check FAILED ==="
fi
