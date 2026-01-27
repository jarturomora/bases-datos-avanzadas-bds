// setup/01-init-cluster.js
// Inicia RS de shards, añade shards, habilita sharding y shardCollection.

function sleep(ms) { const t = Date.now() + ms; while (Date.now() < t) {} }

function waitForPrimary(connStr, rsName, timeoutSec) {
  const deadline = Date.now() + timeoutSec * 1000;
  while (Date.now() < deadline) {
    try {
      const c = new Mongo(connStr);
      const admin = c.getDB("admin");
      const st = admin.runCommand({ replSetGetStatus: 1 });
      if (st.ok === 1) {
        const primary = (st.members || []).find(m => m.stateStr === "PRIMARY");
        if (primary) return true;
      }
    } catch (e) {}
    sleep(2000);
  }
  throw new Error(`Timeout esperando PRIMARY en ${rsName}`);
}

function ensureReplicaSetInitiated(connStr, rsInitiateDoc, rsName) {
  const c = new Mongo(connStr);
  const admin = c.getDB("admin");

  try {
    const st = admin.runCommand({ replSetGetStatus: 1 });
    if (st.ok === 1) {
      print(`==> ${rsName} ya estaba iniciado.`);
      return;
    }
  } catch (e) {}

  print(`==> Iniciando ${rsName}...`);
  const res = admin.runCommand({ replSetInitiate: rsInitiateDoc });
  printjson(res);
}

function ensureShardRS(primaryConnStr, rsName, members) {
  ensureReplicaSetInitiated(primaryConnStr, { _id: rsName, members }, rsName);
  waitForPrimary(primaryConnStr, rsName, 240);
}

// ------------------
// 1) Shard RS (3 data nodes)
// ------------------
ensureShardRS("mongodb://s1a:27018/admin", "rsShard1", [
  { _id: 0, host: "s1a:27018", priority: 2 },
  { _id: 1, host: "s1b:27018", priority: 1 },
  { _id: 2, host: "s1c:27018", priority: 1 }
]);

ensureShardRS("mongodb://s2a:27018/admin", "rsShard2", [
  { _id: 0, host: "s2a:27018", priority: 2 },
  { _id: 1, host: "s2b:27018", priority: 1 },
  { _id: 2, host: "s2c:27018", priority: 1 }
]);

ensureShardRS("mongodb://s3a:27018/admin", "rsShard3", [
  { _id: 0, host: "s3a:27018", priority: 2 },
  { _id: 1, host: "s3b:27018", priority: 1 },
  { _id: 2, host: "s3c:27018", priority: 1 }
]);

// ------------------
// 2) Configurar sharding en mongos
// ------------------
const mongos = new Mongo("mongodb://mongos:27017");
const admin = mongos.getDB("admin");

function addShardIfMissing(rsName, hosts) {
  const current = admin.runCommand({ listShards: 1 });
  const exists = (current.shards || []).some(s => s._id === rsName);
  if (!exists) {
    print(`==> Añadiendo shard ${rsName}...`);
    printjson(admin.runCommand({ addShard: rsName + "/" + hosts.join(",") }));
  } else {
    print(`==> Shard ${rsName} ya existe.`);
  }
}

addShardIfMissing("rsShard1", ["s1a:27018","s1b:27018","s1c:27018"]);
addShardIfMissing("rsShard2", ["s2a:27018","s2b:27018","s2c:27018"]);
addShardIfMissing("rsShard3", ["s3a:27018","s3b:27018","s3c:27018"]);

print("==> Habilitando sharding en teleco_es...");
printjson(admin.runCommand({ enableSharding: "teleco_es" }));

print("==> Configurando shard keys...");
printjson(admin.runCommand({ shardCollection: "teleco_es.usuarios",  key: { provincia: 1, _id: 1 } }));
printjson(admin.runCommand({ shardCollection: "teleco_es.lineas",   key: { provincia: 1, _id: 1 } }));
printjson(admin.runCommand({ shardCollection: "teleco_es.llamadas", key: { provincia: 1, _id: 1 } }));

print("==> Sharding OK.");
