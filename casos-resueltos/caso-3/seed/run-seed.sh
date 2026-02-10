#!/bin/sh
set -eu

NEO4J_CONTAINER="${NEO4J_CONTAINER:-neo4j_fraude_pagos}"
NEO4J_USER="${NEO4J_USER:-neo4j}"
NEO4J_PASS="${NEO4J_PASS:-neo4j1234}"
CYPHER_FILE="${CYPHER_FILE:-/seed/seed.cypher}"

echo "==> Seeder: esperando a que el contenedor ${NEO4J_CONTAINER} esté listo..."
for i in $(seq 1 60); do
  if docker exec "${NEO4J_CONTAINER}" sh -lc "wget -qO- http://localhost:7474 >/dev/null 2>&1"; then
    echo "==> Neo4j Browser responde."
    break
  fi
  sleep 1
done

echo "==> Localizando cypher-shell dentro de ${NEO4J_CONTAINER}..."

CYPHER_SHELL_PATH="$(docker exec "${NEO4J_CONTAINER}" sh -lc '
  for p in \
    /var/lib/neo4j/bin/cypher-shell \
    /var/lib/neo4j/bin/cypher-shell-admin \
    /opt/neo4j/bin/cypher-shell \
    /usr/bin/cypher-shell \
    /bin/cypher-shell
  do
    if [ -x "$p" ]; then echo "$p"; exit 0; fi
  done
  # fallback: intentar encontrarlo (puede tardar un poco, pero es una sola vez)
  found=$(find /var/lib/neo4j -maxdepth 3 -type f -name cypher-shell -perm -111 2>/dev/null | head -n 1 || true)
  if [ -n "$found" ]; then echo "$found"; exit 0; fi
  exit 1
' 2>/dev/null || true)"

if [ -z "${CYPHER_SHELL_PATH}" ]; then
  echo "ERROR: no he podido encontrar un binario ejecutable de cypher-shell dentro de ${NEO4J_CONTAINER}."
  echo "Prueba: docker exec ${NEO4J_CONTAINER} ls -la /var/lib/neo4j/bin"
  exit 127
fi

echo "==> cypher-shell encontrado en: ${CYPHER_SHELL_PATH}"

echo "==> Ejecutando seed.cypher dentro de ${NEO4J_CONTAINER}..."
docker exec -i "${NEO4J_CONTAINER}" sh -lc \
  "'${CYPHER_SHELL_PATH}' -a bolt://localhost:7687 -u '${NEO4J_USER}' -p '${NEO4J_PASS}'" < "${CYPHER_FILE}"

echo "==> Seed completado."
