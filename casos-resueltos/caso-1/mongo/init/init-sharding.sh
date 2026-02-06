#!/usr/bin/env bash
set -euo pipefail

echo "==> Esperando a mongos..."
for i in {1..60}; do
  mongosh --host mongos --port 27117 --eval 'db.runCommand({ping:1})' >/dev/null 2>&1 && break
  sleep 2
done

echo "==> Iniciando replica set config server (cfgRS)..."
mongosh --host rbnb_mongo_config --port 27019 --eval '
  rs.initiate({
    _id:"cfgRS",
    configsvr:true,
    members:[{_id:0, host:"rbnb_mongo_config:27019"}]
  });
' || true

echo "==> Iniciando replica set shard1 (shard1RS)..."
mongosh --host rbnb_mongo_shard1 --port 27018 --eval '
  rs.initiate({
    _id:"shard1RS",
    members:[{_id:0, host:"rbnb_mongo_shard1:27018"}]
  });
' || true

echo "==> Iniciando replica set shard2 (shard2RS)..."
mongosh --host rbnb_mongo_shard2 --port 27017 --eval '
  rs.initiate({
    _id:"shard2RS",
    members:[{_id:0, host:"rbnb_mongo_shard2:27017"}]
  });
' || true

echo "==> Esperando estabilización de los RS..."
sleep 6

echo "==> Añadiendo shards a mongos..."
mongosh --host mongos --port 27117 --eval '
  try { sh.addShard("shard1RS/rbnb_mongo_shard1:27018"); } catch(e) { print(e); }
  try { sh.addShard("shard2RS/rbnb_mongo_shard2:27017"); } catch(e) { print(e); }
'

echo "==> Habilitando sharding en db rbnb y shardCollection..."
mongosh --host mongos --port 27117 --eval '
  sh.enableSharding("rbnb");

  // disponibilidad_cache: ciudad (rango) + id_apartamento (hashed)
  db.getSiblingDB("rbnb").disponibilidad_cache.createIndex({ciudad:1, id_apartamento:1, dia:1});
  sh.shardCollection("rbnb.disponibilidad_cache", { ciudad: 1, id_apartamento: "hashed" });

  // anuncios_busqueda: ciudad + ordenaciones típicas (precio/valoracion)
  db.getSiblingDB("rbnb").anuncios_busqueda.createIndex({ciudad:1, precio:1, valoracion:-1});
  sh.shardCollection("rbnb.anuncios_busqueda", { ciudad: 1, id_anuncio: "hashed" });

  // eventos_reserva: serie temporal (si empiezas a poblarla)
  db.getSiblingDB("rbnb").eventos_reserva.createIndex({ts:1});
  sh.shardCollection("rbnb.eventos_reserva", { ts: 1 });

  print("Sharding listo ✅");
'

echo "==> OK"
