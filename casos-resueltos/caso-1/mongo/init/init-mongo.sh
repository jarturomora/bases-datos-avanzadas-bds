#!/usr/bin/env bash
set -euo pipefail

MONGO_HOST="${MONGO_HOST:-mongo}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_DB="${MONGO_DB:-rbnb}"

echo "==> Esperando ping de Mongo (${MONGO_HOST}:${MONGO_PORT})..."
for i in {1..60}; do
  if mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" --quiet --eval 'db.runCommand({ ping: 1 }).ok' 2>/dev/null | grep -q '^1$'; then
    break
  fi
  sleep 2
done

echo "==> Creando índices en Mongo (db: ${MONGO_DB})..."
mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" --eval "
  const dbx = db.getSiblingDB('${MONGO_DB}');

  // Colección para listados/búsqueda
  dbx.anuncios_busqueda.createIndex({ ciudad: 1, precio: 1, valoracion: -1 });
  dbx.anuncios_busqueda.createIndex({ ciudad: 1, valoracion: -1 });

  // Colección de disponibilidad “cache”
  dbx.disponibilidad_cache.createIndex({ ciudad: 1, dia: 1, disponible: 1 });
  dbx.disponibilidad_cache.createIndex({ id_apartamento: 1, dia: 1 });

  // Eventos (si los usas más adelante)
  dbx.eventos_reserva.createIndex({ ts: 1 });

  print('Mongo init OK ✅');
"

echo "==> OK"
