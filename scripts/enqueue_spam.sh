#!/usr/bin/env bash

BROKER_URL="${BROKER_URL:-http://localhost:8080}"
URL="$BROKER_URL/enqueue"

if [[ -z "$AUTH_TOKEN" ]]; then
    echo "[enqueue_spam] AUTH_TOKEN must be set" >&2
    exit 1
fi

while true; do
    curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{"payload":"spam"}' > /dev/null

  echo "[enqueue_spam] job submitted"
  sleep 0.2
done