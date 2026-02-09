#!/usr/bin/env bash
set -euo pipefail

MONGO_HOST="eco_mongo"
MONGO_PORT="27017"
RS_NAME="rs0"

MONGO_URI="mongodb://${MONGO_HOST}:${MONGO_PORT}"
MONGO_URI_RS="mongodb://${MONGO_HOST}:${MONGO_PORT}/?replicaSet=${RS_NAME}"

echo "==> [mongo-init] Ping Mongo..."
mongosh "$MONGO_URI" --quiet --eval 'db.adminCommand({ping:1})' >/dev/null
echo "==> [mongo-init] Mongo OK."

echo "==> [mongo-init] Initiate replica set (${RS_NAME}) if needed..."
mongosh "$MONGO_URI" --quiet --eval "
  try { rs.status(); }
  catch(e) { rs.initiate({_id:\"${RS_NAME}\", members:[{_id:0, host:\"${MONGO_HOST}:${MONGO_PORT}\"}]}); }
" >/dev/null
echo "==> [mongo-init] rs.status() reachable (or initiated)."

echo "==> [mongo-init] Wait for PRIMARY..."
mongosh "$MONGO_URI_RS" --quiet --eval '
  function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
  (async()=>{
    for (let i=0;i<60;i++){
      const h=db.adminCommand({hello:1});
      if(h.isWritablePrimary){ print("PRIMARY ok"); quit(0); }
      await sleep(1000);
    }
    print("Timeout waiting PRIMARY"); quit(1);
  })();
'

echo "==> [mongo-init] Run schema validation..."
mongosh "$MONGO_URI_RS" --quiet /mongo-init/10-schema-validation.js
echo "==> [mongo-init] Schema OK."

echo "==> [mongo-init] Run seed data..."
mongosh "$MONGO_URI_RS" --quiet /mongo-init/20-seed-data.js
echo "==> [mongo-init] Seed OK."

echo "==> [mongo-init] Done."
