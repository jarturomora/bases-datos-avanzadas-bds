#!/bin/sh
set -eu

ES="http://elasticsearch:9200"
INDEX="imdb_reviews"
MAPPING="/setup/imdb_reviews_mapping.json"

echo "Checking Elasticsearch..."
curl -s "$ES" >/dev/null

echo "Creating index (if missing): $INDEX"
STATUS="$(curl -s -o /dev/null -w "%{http_code}" "$ES/$INDEX")"

if [ "$STATUS" = "200" ]; then
  echo "Index already exists: $INDEX"
  exit 0
fi

curl -sS -X PUT "$ES/$INDEX" \
  -H "Content-Type: application/json" \
  --data-binary "@$MAPPING"

echo "Index created: $INDEX"