#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

REGION="ap-northeast-2"
DEPLOY_ENV="${deploy_env}"
COMPOSE_DIR="/home/ubuntu/recommend"
SSM_PREFIX="/moyeobab/recommend/$DEPLOY_ENV"

echo "=== Recommend User Data Start ==="

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed"
  exit 1
fi

mkdir -p $COMPOSE_DIR

# S3에서 docker-compose.yml 등 설정 파일 가져오기
aws s3 sync s3://moyeobab-$DEPLOY_ENV-config/recommend/ $COMPOSE_DIR/ --exclude '.env' --region $REGION

# Parameter Store → .env 생성
> $COMPOSE_DIR/.env
for param in PG_HOST PG_PORT PG_USER PG_PASSWORD PG_DB QDRANT_URL QDRANT_API_KEY QDRANT_COLLECTION IMAGE_TAG; do
  val=$(aws ssm get-parameter --name $SSM_PREFIX/$param --with-decryption --query "Parameter.Value" --output text --region $REGION | tr -d '\r')
  echo "$param=$val" >> $COMPOSE_DIR/.env
done

# ECR login
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
echo "ECR_REGISTRY=$ECR_REGISTRY" >> $COMPOSE_DIR/.env
echo "ENV=$DEPLOY_ENV" >> $COMPOSE_DIR/.env

# Deploy
cd $COMPOSE_DIR && docker compose pull && docker compose up -d

# Health check
sleep 5
if curl -sf --retry 8 --retry-delay 3 http://localhost:8000/health; then
  echo "=== Recommend User Data Complete — Health check passed ==="
  docker image prune -f
else
  echo "=== Recommend User Data Complete — Health check FAILED ==="
fi
