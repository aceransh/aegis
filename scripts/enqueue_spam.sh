#!/usr/bin/env bash

BROKER_URL="${BROKER_URL:-http://localhost:8080}"
URL="$BROKER_URL/enqueue"

while true; do
    curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d '{"payload":"spam"}' > /dev/null

  echo "[enqueue_spam] job submitted"
  sleep 0.2
done