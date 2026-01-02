// cluster-init.js (robusto e idempotente, sin helpers rs.*)

function sleepMs(ms) { sleep(ms); }

function msg(err) {
  return (err && err.message) ? err.message : String(err);
}

function isNoReplsetConfigMessage(m) {
  return m.includes("no replset config has been received") ||
         m.includes("not yet initialized") ||
         m.includes("NotYetInitialized");
}

function isAlreadyInitializedMessage(m) {
  return m.includes("already initialized") ||
         m.includes("already been initiated") ||
         m.includes("already exists") ||
         m.includes("already set");
}

function admin(cmd) {
  try {
    const res = db.adminCommand(cmd);
    return res;
  } catch (e) {
    return { ok: 0, __error: e, errmsg: msg(e) };
  }
}

function safe(fn, label) {
  try { return fn(); }
  catch (e) { print(`[WARN] ${label}: ${e.message}`); return null; }
}

function waitForPrimary(maxSeconds = 180) {
  for (let i = 0; i < maxSeconds; i++) {
    const st = admin({ replSetGetStatus: 1 });

    if (st && st.ok === 1 && Array.isArray(st.members)) {
      if (st.members.some(m => m.stateStr === "PRIMARY")) return true;
    }

    if (st && st.ok === 0) {
      const em = st.errmsg || "";
      if (!isNoReplsetConfigMessage(em)) {
        throw new Error(`replSetGetStatus error: ${em}`);
      }
    }

    sleepMs(1000);
  }
  throw new Error("Timeout esperando PRIMARY del replica set.");
}

function replSetInitiate(cfg, label) {
  for (let i = 0; i < 15; i++) {
    const res = admin({ replSetInitiate: cfg });

    if (res.ok === 1) {
      print(`${label}: replSetInitiate OK.`);
      return;
    }

    const em = res.errmsg || "";
    if (isAlreadyInitializedMessage(em)) {
      print(`${label}: ya estaba inicializado.`);
      return;
    }

    print(`[WARN] ${label}: replSetInitiate fallo: ${em} (reintento ${i + 1}/15)`);
    sleepMs(1000);
  }

  throw new Error(`${label}: no se pudo iniciar el replica set (replSetInitiate).`);
}

function ensureReplSet(cfg, label) {
  const st = admin({ replSetGetStatus: 1 });
  if (st.ok === 1) {
    print(`${label}: replica set ya configurado. Esperando PRIMARY...`);
    waitForPrimary(180);
    print(`${label}: listo (PRIMARY).`);
    return;
  }

  if (st.ok === 0 && !isNoReplsetConfigMessage(st.errmsg || "")) {
    throw new Error(`${label}: replSetGetStatus error inesperado: ${st.errmsg}`);
  }

  print(`${label}: no hay config de replSet. Iniciando...`);
  replSetInitiate(cfg, label);

  waitForPrimary(180);
  print(`${label}: listo (PRIMARY).`);
}

// ---------- Funciones expuestas ----------

globalThis.initConfigRS = function () {
  const cfg = {
    _id: "cfgRS",
    configsvr: true,
    members: [
      { _id: 0, host: "cfg1:27019" },
      { _id: 1, host: "cfg2:27019" },
      { _id: 2, host: "cfg3:27019" }
    ]
  };
  ensureReplSet(cfg, "cfgRS");
};

globalThis.initShardEU = function () {
  const cfg = {
    _id: "shardEU",
    members: [{ _id: 0, host: "shard-eu-1:27018" }]
  };
  ensureReplSet(cfg, "shardEU");
};

globalThis.initShardAM = function () {
  const cfg = {
    _id: "shardAM",
    members: [{ _id: 0, host: "shard-am-1:27020" }]
  };
  ensureReplSet(cfg, "shardAM");
};

// ---------- Cluster config + datos (ejecutar en mongos) ----------
globalThis.configureClusterAndData = function () {
  const bank = db.getSiblingDB("bank");

  // 1) Sharding
  safe(() => sh.addShard("shardEU/shard-eu-1:27018"), "addShard shardEU");
  safe(() => sh.addShard("shardAM/shard-am-1:27020"), "addShard shardAM");

  safe(() => sh.enableSharding("bank"), "enableSharding(bank)");

  safe(() => bank.accounts.createIndex({ region: 1, accountId: 1 }), "createIndex accounts");
  safe(() => sh.shardCollection("bank.accounts", { region: 1, accountId: 1 }), "shardCollection accounts");

  safe(() => sh.addShardToZone("shardEU", "ZONE_EU"), "addShardToZone shardEU");
  safe(() => sh.addShardToZone("shardAM", "ZONE_AM"), "addShardToZone shardAM");

  safe(() => sh.updateZoneKeyRange(
    "bank.accounts",
    { region: "EU", accountId: MinKey },
    { region: "EU", accountId: MaxKey },
    "ZONE_EU"
  ), "updateZoneKeyRange EU");

  safe(() => sh.updateZoneKeyRange(
    "bank.accounts",
    { region: "AM", accountId: MinKey },
    { region: "AM", accountId: MaxKey },
    "ZONE_AM"
  ), "updateZoneKeyRange AM");

  // 2) Limpieza + carga de datos
  bank.accounts.deleteMany({});
  bank.transfers.deleteMany({});

  // 100 cuentas: 50 EU, 50 AM (balances variados)
  const accounts = [];
  let accountId = 1000;

  // EU: 1000..1049
  for (let i = 0; i < 50; i++) {
    accounts.push({
      accountId: accountId++,
      owner: `EU_User_${String(i + 1).padStart(2, "0")}`,
      region: "EU",
      balance: 500 + ((i * 37) % 4500)  // 500..4999 aprox
    });
  }

  // AM: 1050..1099
  for (let i = 0; i < 50; i++) {
    accounts.push({
      accountId: accountId++,
      owner: `AM_User_${String(i + 1).padStart(2, "0")}`,
      region: "AM",
      balance: 500 + ((i * 53) % 4500)
    });
  }

  bank.accounts.insertMany(accounts);

  // Helpers para generar transferencias
  const euIds = accounts.filter(a => a.region === "EU").map(a => a.accountId);
  const amIds = accounts.filter(a => a.region === "AM").map(a => a.accountId);

  function pick(arr, idx) { return arr[idx % arr.length]; }

  // Ejecuta un lote de transferencias dentro de UNA transacción para acelerar init
  function transferBatch(ops) {
    const session = db.getMongo().startSession();
    const sdb = session.getDatabase("bank");
    const acc = sdb.accounts;
    const tr = sdb.transfers;

    session.startTransaction();
    try {
      for (const op of ops) {
        const debit = acc.updateOne(
          { accountId: op.from, balance: { $gte: op.amount } },
          { $inc: { balance: -op.amount } }
        );
        if (debit.matchedCount !== 1) {
          // Si falla por saldo, registramos ABORTED y abortamos el lote completo (atomicidad del batch)
          throw new Error(`Saldo insuficiente en cuenta ${op.from}`);
        }

        const credit = acc.updateOne(
          { accountId: op.to },
          { $inc: { balance: op.amount } }
        );
        if (credit.matchedCount !== 1) {
          throw new Error(`Cuenta destino no existe: ${op.to}`);
        }

        tr.insertOne({
          ts: op.ts,
          from: op.from,
          to: op.to,
          amount: op.amount,
          type: op.type,
          status: "COMMITTED"
        });
      }
      session.commitTransaction();
      return { ok: true };
    } catch (e) {
      safe(() => tr.insertOne({
        ts: new Date(),
        status: "ABORTED_BATCH",
        reason: e.message,
        batchSize: ops.length
      }), "log aborted batch");

      session.abortTransaction();
      return { ok: false, reason: e.message };
    } finally {
      session.endSession();
    }
  }

  // 3) Generar 1000 transferencias:
  //    - 600 cross-shard (EU->AM y AM->EU alternando)
  //    - 400 intra-shard (EU->EU y AM->AM alternando)
  const totalTransfers = 1000;
  const batchSize = 50; // 20 batches aprox
  const opsAll = [];

  for (let i = 0; i < totalTransfers; i++) {
    const cross = (i < 600);
    const directionFlip = (i % 2 === 0);

    let from, to, type;
    if (cross) {
      if (directionFlip) {
        from = pick(euIds, i);
        to   = pick(amIds, i + 7);
        type = "CROSS_EU_TO_AM";
      } else {
        from = pick(amIds, i);
        to   = pick(euIds, i + 11);
        type = "CROSS_AM_TO_EU";
      }
    } else {
      // intra
      if (directionFlip) {
        from = pick(euIds, i);
        to   = pick(euIds, i + 13);
        if (to === from) to = pick(euIds, i + 14);
        type = "INTRA_EU";
      } else {
        from = pick(amIds, i);
        to   = pick(amIds, i + 17);
        if (to === from) to = pick(amIds, i + 18);
        type = "INTRA_AM";
      }
    }

    // cantidad determinista (evita Math.random() para reproducibilidad)
    const amount = 1 + ((i * 19) % 200); // 1..200
    opsAll.push({
      ts: new Date(Date.now() - (totalTransfers - i) * 1000), // timestamps escalonados
      from, to, amount, type
    });
  }

  // Ejecutar por lotes
  print(`Generando ${totalTransfers} transferencias en lotes de ${batchSize}...`);
  let committedBatches = 0;
  for (let i = 0; i < opsAll.length; i += batchSize) {
    const batch = opsAll.slice(i, i + batchSize);
    const res = transferBatch(batch);
    if (res.ok) committedBatches++;
    else print(`[WARN] Batch fallido: ${res.reason}`);
  }

  print(`Batches COMMITTED: ${committedBatches}/${Math.ceil(totalTransfers / batchSize)}`);

  // 4) Resumen para clase
  print("=== Resumen ===");
  print(`Cuentas: ${bank.accounts.countDocuments({})}`);
  print(`Transferencias: ${bank.transfers.countDocuments({ status: "COMMITTED" })}`);

  print("=== Top 5 cuentas por balance ===");
  bank.accounts.find({}, { _id: 0, accountId: 1, region: 1, balance: 1 })
    .sort({ balance: -1 }).limit(5).forEach(printjson);

  print("=== Ejemplo de transferencias cross-shard ===");
  bank.transfers.find({ type: { $regex: "^CROSS" }, status: "COMMITTED" }, { _id: 0 })
    .sort({ ts: -1 }).limit(5).forEach(printjson);

  print("=== sh.status() ===");
  sh.status();
};
// fin de cluster-init.js