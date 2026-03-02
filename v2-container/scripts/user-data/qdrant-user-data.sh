#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

REGION="ap-northeast-2"
DEPLOY_ENV="${deploy_env}"
QDRANT_DIR="/home/ubuntu/qdrant"
SSM_PREFIX="/moyeobab/qdrant/$DEPLOY_ENV"
STORAGE_DIR="/data/qdrant"

echo "=== Qdrant User Data Start ==="

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed"
  exit 1
fi

mkdir -p $QDRANT_DIR
mkdir -p $STORAGE_DIR

# SSM에서 API 키 가져오기
QDRANT_API_KEY=$(aws ssm get-parameter --name $SSM_PREFIX/QDRANT_API_KEY --with-decryption --query "Parameter.Value" --output text --region $REGION | tr -d '\r')

# .env 생성
cat > $QDRANT_DIR/.env <<EOF
QDRANT_API_KEY=$QDRANT_API_KEY
EOF
chmod 600 $QDRANT_DIR/.env

# docker-compose.yml 생성
cat > $QDRANT_DIR/docker-compose.yml <<'COMPOSE'
services:
  qdrant:
    image: qdrant/qdrant:v1.16.3
    container_name: qdrant
    ports:
      - "6333:6333"
    volumes:
      - /data/qdrant:/qdrant/storage
    env_file:
      - .env
    environment:
      - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}
    restart: unless-stopped
COMPOSE

chown -R ubuntu:ubuntu $QDRANT_DIR

# Deploy
cd $QDRANT_DIR && docker compose up -d

# Health check
sleep 5
if curl -sf http://localhost:6333/healthz; then
  echo "=== Qdrant User Data Complete — Health check passed ==="
else
  echo "=== Qdrant User Data Complete — Health check FAILED ==="
fi
