#!/usr/bin/env bash
set -euo pipefail

echo "==> mongos-entrypoint: esperando cfg1:27019..."
for i in {1..180}; do
  if mongosh "mongodb://cfg1:27019/admin" --quiet --eval "db.adminCommand({ping:1}).ok" 2>/dev/null | grep -q 1; then
    break
  fi
  sleep 1
done

echo "==> mongos-entrypoint: esperando cfgRS PRIMARY..."
for i in {1..180}; do
  if mongosh "mongodb://cfg1:27019/admin" --quiet --eval "rs.status().myState" 2>/dev/null | grep -q 1; then
    break
  fi
  sleep 1
done

echo "==> mongos-entrypoint: arrancando mongos..."
exec mongos --configdb "cfgRS/cfg1:27019" --port 27017 --bind_ip_all
