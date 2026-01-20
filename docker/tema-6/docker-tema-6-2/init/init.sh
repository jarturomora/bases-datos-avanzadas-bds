#!/usr/bin/env bash
set -euo pipefail

MONGO_URI="mongodb://mongodb:27017"

echo "Esperando a MongoDB..."
for i in {1..60}; do
  if mongosh "$MONGO_URI" --quiet --eval "db.adminCommand('ping').ok" | grep -q "1"; then
    echo "MongoDB OK"
    break
  fi
  sleep 2
done

echo "Inicializando replica set (si aplica)..."
mongosh "$MONGO_URI" --quiet <<'JS'
try {
  const st = rs.status();
  if (st.ok === 1) {
    print("rs0 ya inicializado");
  }
} catch (e) {
  print("Iniciando rs0...");
  rs.initiate({
    _id: "rs0",
    members: [{ _id: 0, host: "mongodb:27017" }]
  });
}
JS

echo "Esperando PRIMARY..."
mongosh "$MONGO_URI" --quiet <<'JS'
for (let i=0; i<60; i++) {
  try {
    const st = rs.status();
    if (st.ok === 1 && st.members && st.members.some(m => m.stateStr === "PRIMARY")) {
      print("PRIMARY listo");
      quit(0);
    }
  } catch (e) {}
  sleep(1000);
}
throw new Error("Timeout esperando PRIMARY");
JS

echo "Cargando datos (seed)..."
mongosh "$MONGO_URI" --quiet /init/seed.js

echo "Init completado."
