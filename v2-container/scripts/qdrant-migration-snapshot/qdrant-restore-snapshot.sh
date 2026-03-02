#!/bin/bash

PUBLIC_QDRANT="http://43.202.64.29:6333"
COLLECTION="meetup_requests_v2"
SNAPSHOT_PATH="/home/ubuntu/qdrant/snap-migrate.snapshot"
APIKEY=$(grep "QDRANT_API_KEY" /home/ubuntu/qdrant/.env | cut -d'=' -f2-)

echo "APIKEY=[${APIKEY:0:8}...]"
if [ -z "$APIKEY" ]; then echo "ERROR: APIKEY empty"; exit 1; fi

echo "=== 1. 퍼블릭 Qdrant에서 스냅샷 생성 ==="
SNAP_NAME=$(curl -sf -X POST "$PUBLIC_QDRANT/collections/$COLLECTION/snapshots" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
echo "Snapshot: $SNAP_NAME"
if [ -z "$SNAP_NAME" ]; then echo "ERROR: snapshot creation failed"; exit 1; fi

echo "=== 2. 스냅샷 다운로드 ==="
curl -sf -o "$SNAPSHOT_PATH" "$PUBLIC_QDRANT/collections/$COLLECTION/snapshots/$SNAP_NAME"
echo "Downloaded: $SNAPSHOT_PATH ($(du -sh $SNAPSHOT_PATH | cut -f1))"

echo "=== 3. 내부 Qdrant에 업로드 ==="
curl -s -X POST \
  -H "api-key: $APIKEY" \
  -H "Content-Type: multipart/form-data" \
  -F "snapshot=@$SNAPSHOT_PATH" \
  http://localhost:6333/collections/$COLLECTION/snapshots/upload

echo ""
echo "=== 4. 컬렉션 확인 ==="
curl -s -H "api-key: $APIKEY" http://localhost:6333/collections
