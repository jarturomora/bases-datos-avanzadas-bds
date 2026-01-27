#!/usr/bin/env bash
set -euo pipefail

wait_mongo () {
  local uri="$1"
  local name="$2"
  echo "==> Esperando ${name} (${uri})..."
  for i in {1..180}; do
    if mongosh "${uri}" --quiet --eval "db.adminCommand({ping:1}).ok" 2>/dev/null | grep -q 1; then
      echo "==> ${name} listo."
      return 0
    fi
    sleep 1
  done
  echo "ERROR: Timeout esperando ${name}"
  exit 1
}

wait_sharding_ready () {
  local uri="$1"
  echo "==> Esperando a que mongos tenga metadatos de sharding (listShards/config.shards)..."
  for i in {1..240}; do
    # 1) listShards debe devolver shards
    if mongosh "${uri}" --quiet --eval '
      const r=db.adminCommand({listShards:1});
      (r.ok===1 && (r.shards||[]).length>0) ? "OK" : "NO";
    ' 2>/dev/null | grep -q "OK"; then
      # 2) config.shards debe existir y tener docs
      if mongosh "${uri}" --quiet --eval '
        const n=db.getSiblingDB("config").shards.countDocuments();
        n>0 ? "OK" : "NO";
      ' 2>/dev/null | grep -q "OK"; then
        echo "==> Sharding listo (listShards OK y config.shards poblado)."
        return 0
      fi
    fi
    sleep 1
  done
  echo "ERROR: Timeout esperando sharding listo"
  echo "Sugerencia: revisa 'docker logs --tail 200 mongos' y 'mongosh mongodb://mongos:27017/admin --eval \"sh.status()\"'"
  exit 1
}

# Esperar nodos base
wait_mongo "mongodb://s1a:27018/admin" "s1a"
wait_mongo "mongodb://s2a:27018/admin" "s2a"
wait_mongo "mongodb://s3a:27018/admin" "s3a"
wait_mongo "mongodb://mongos:27017/admin" "mongos"

echo "==> 1) Inicializando replica sets de shards y sharding..."
mongosh "mongodb://mongos:27017/admin" /setup/01-init-cluster.js

# Esperar metadatos sharding reales (no config.version)
wait_sharding_ready "mongodb://mongos:27017/admin"

echo "==> 2) Cargando datos de demo (teleco_es)..."
mongosh "mongodb://mongos:27017/admin" /setup/02-seed-teleco.js

echo "==> Setup completado. Conecta Compass a mongodb://localhost:27017"
