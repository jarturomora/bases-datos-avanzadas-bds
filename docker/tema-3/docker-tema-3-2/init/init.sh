#!/usr/bin/env bash
set -euo pipefail

wait_ping () {
  local uri="$1" name="$2"
  echo "Esperando ping de ${name} (${uri})..."
  for i in {1..120}; do
    if mongosh "$uri" --eval "db.runCommand({ ping: 1 }).ok" --quiet >/dev/null 2>&1; then
      echo "OK: ${name} responde a ping."
      return 0
    fi
    sleep 1
  done
  echo "ERROR: timeout esperando ping de ${name}" >&2
  mongosh "$uri" --eval "db.runCommand({ ping: 1 })" || true
  exit 1
}

run_js () {
  local uri="$1" expr="$2"
  for i in {1..20}; do
    echo "Ejecutando: ${expr} (intento ${i}/20) en ${uri}"
    if mongosh "$uri" --eval "load('/init/cluster-init.js'); ${expr}" ; then
      echo "OK: ${expr}"
      return 0
    fi
    echo "WARN: fallo ejecutando ${expr}. Reintentando en 3s..."
    sleep 3
  done
  echo "ERROR: no se pudo ejecutar: ${expr} después de 20 intentos" >&2
  exit 1
}

# 1) Esperar a que TODOS los mongod respondan
wait_ping "mongodb://cfg1:27019" "cfg1"
wait_ping "mongodb://cfg2:27019" "cfg2"
wait_ping "mongodb://cfg3:27019" "cfg3"
wait_ping "mongodb://shard-eu-1:27018" "shard-eu-1"
wait_ping "mongodb://shard-am-1:27020" "shard-am-1"

# 2) Inicializar cfgRS (3 nodos) desde cfg1
run_js "mongodb://cfg1:27019" "initConfigRS()"

# 3) Inicializar shards (RS de 1 nodo, suficiente para transacciones)
run_js "mongodb://shard-eu-1:27018" "initShardEU()"
run_js "mongodb://shard-am-1:27020" "initShardAM()"

# 4) Esperar a mongos y configurar el cluster
wait_ping "mongodb://mongos:27017" "mongos"
run_js "mongodb://mongos:27017" "configureClusterAndData()"

echo "Inicialización completada."
