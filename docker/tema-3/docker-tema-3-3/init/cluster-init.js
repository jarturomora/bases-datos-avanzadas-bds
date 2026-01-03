// cluster-init.js — Distributed Queries Demo (shipping, semi-join, paralelización)
// Basado en el patrón robusto/idempotente que ya te funcionó. :contentReference[oaicite:4]{index=4}

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
    return db.adminCommand(cmd);
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
  // Helpers
  function hello() {
    return db.adminCommand({ hello: 1 });
  }

  function waitWritablePrimary(maxSeconds = 180) {
    for (let i = 0; i < maxSeconds; i++) {
      const h = hello();
      if (h && h.ok === 1 && h.isWritablePrimary === true) return true;
      sleep(1000);
    }
    throw new Error("Timeout esperando cfgRS PRIMARY (hello.isWritablePrimary=true).");
  }

  function tryInitiateOnce() {
    try {
      return rs.initiate({
        _id: "cfgRS",
        configsvr: true,
        members: [{ _id: 0, host: "cfg1:27019" }]
      });
    } catch (e) {
      return { __error: e, errmsg: (e && e.message) ? e.message : String(e) };
    }
  }

  // 1) Si ya está en RS, saltamos initiate
  const h0 = hello();
  if (h0 && h0.ok === 1 && h0.setName === "cfgRS") {
    print("cfgRS: ya tiene setName=cfgRS. Continuando...");
  } else {
    // 2) Intentar initiate con reintentos (idempotente)
    print("cfgRS: intentando rs.initiate (1 miembro)...");
    for (let i = 0; i < 20; i++) {
      const r = tryInitiateOnce();
      if (r && r.__error) {
        const m = r.errmsg || "";
        // Ya iniciado / ya existe
        if (m.includes("already") || m.includes("AlreadyInitialized")) {
          print("cfgRS: ya estaba iniciado.");
          break;
        }
        print(`[WARN] cfgRS initiate fallo: ${m} (reintento ${i + 1}/20)`);
        sleep(1000);
        continue;
      }
      // initiate OK
      break;
    }
  }

  // 3) Esperar PRIMARY real
  waitWritablePrimary(180);
  print("cfgRS: PRIMARY listo.");

  // 4) Reconfig para añadir miembros (solo cuando ya existe config)
  function addMemberIfMissing(host) {
    const cfgRes = db.adminCommand({ replSetGetConfig: 1 });
    if (!cfgRes || cfgRes.ok !== 1 || !cfgRes.config) {
      throw new Error("cfgRS: replSetGetConfig aún no disponible.");
    }

    const cfg = cfgRes.config;
    if (cfg.members.some(m => m.host === host)) {
      print(`cfgRS: ya existe ${host}`);
      return;
    }

    const maxId = cfg.members.reduce((mx, m) => Math.max(mx, m._id), 0);
    cfg.members.push({ _id: maxId + 1, host });
    cfg.version = (cfg.version || 1) + 1;

    const rc = db.adminCommand({ replSetReconfig: cfg });
    if (!rc || rc.ok !== 1) {
      throw new Error(`cfgRS: replSetReconfig falló añadiendo ${host}: ${rc.errmsg || "sin errmsg"}`);
    }
    print(`cfgRS: añadido ${host}`);
  }

  addMemberIfMissing("cfg2:27019");
  addMemberIfMissing("cfg3:27019");

  waitWritablePrimary(180);
  print("cfgRS: listo con 3 miembros.");
};

function hello() {
  return db.adminCommand({ hello: 1 });
}

function waitSetNameAndPrimary(expectedSetName, maxSeconds = 180) {
  for (let i = 0; i < maxSeconds; i++) {
    const h = hello();
    if (h && h.ok === 1 && h.setName === expectedSetName && h.isWritablePrimary === true) return true;
    sleep(1000);
  }
  throw new Error(`Timeout esperando PRIMARY del RS ${expectedSetName}.`);
}

function tryInitiateRSOnce(cfg) {
  try {
    return rs.initiate(cfg);
  } catch (e) {
    return { __error: e, errmsg: (e && e.message) ? e.message : String(e) };
  }
}

function ensureRSByInitiate(cfg, expectedSetName, label) {
  const h0 = hello();

  // Si ya está en RS correcto, solo espera PRIMARY
  if (h0 && h0.ok === 1 && h0.setName === expectedSetName) {
    print(`${label}: ya tiene setName=${expectedSetName}. Esperando PRIMARY...`);
    waitSetNameAndPrimary(expectedSetName, 180);
    print(`${label}: listo (PRIMARY).`);
    return;
  }

  print(`${label}: intentando rs.initiate...`);
  for (let i = 0; i < 25; i++) {
    const r = tryInitiateRSOnce(cfg);
    if (r && r.__error) {
      const m = r.errmsg || "";
      if (m.includes("already") || m.includes("AlreadyInitialized")) {
        print(`${label}: ya estaba iniciado.`);
        break;
      }
      print(`[WARN] ${label} initiate fallo: ${m} (reintento ${i + 1}/25)`);
      sleep(1000);
      continue;
    }
    // initiate OK
    break;
  }

  waitSetNameAndPrimary(expectedSetName, 180);
  print(`${label}: listo (PRIMARY).`);
}

globalThis.initShardEU = function () {
  const cfg = {
    _id: "shardEU",
    members: [{ _id: 0, host: "shard-eu-1:27018" }]
  };
  ensureRSByInitiate(cfg, "shardEU", "shardEU");
};

globalThis.initShardAM = function () {
  const cfg = {
    _id: "shardAM",
    members: [{ _id: 0, host: "shard-am-1:27020" }]
  };
  ensureRSByInitiate(cfg, "shardAM", "shardAM");
};

// ---------- Cluster config + datos ----------
globalThis.configureClusterAndData = function () {
  const bank = db.getSiblingDB("bank");

  // 1) Sharding base (mismo enfoque que ya te funcionó) :contentReference[oaicite:5]{index=5}
  safe(() => sh.addShard("shardEU/shard-eu-1:27018"), "addShard shardEU");
  safe(() => sh.addShard("shardAM/shard-am-1:27020"), "addShard shardAM");

  safe(() => sh.enableSharding("bank"), "enableSharding(bank)");

  // accounts shardeada por region+accountId (clave didáctica)
  safe(() => bank.accounts.createIndex({ region: 1, accountId: 1 }), "createIndex accounts");
  safe(() => sh.shardCollection("bank.accounts", { region: 1, accountId: 1 }), "shardCollection accounts");

  // Zonas (opcional didáctico; mantiene la narrativa de “EU vive en shardEU”)
  safe(() => sh.addShardToZone("shardEU", "ZONE_EU"), "addShardToZone shardEU");
  safe(() => sh.addShardToZone("shardAM", "ZONE_AM"), "addShardToZone shardAM");

  safe(() => sh.updateZoneKeyRange(
    "bank.accounts",
    { region: "EU", accountId: MinKey },
    { region: "EU", accountId: MaxKey },
    "ZONE_EU"
  ), "updateZoneKeyRange accounts EU");

  safe(() => sh.updateZoneKeyRange(
    "bank.accounts",
    { region: "AM", accountId: MinKey },
    { region: "AM", accountId: MaxKey },
    "ZONE_AM"
  ), "updateZoneKeyRange accounts AM");

  // 2) Limpieza (idempotente)
  bank.accounts.deleteMany({});
  bank.transfers.deleteMany({});
  bank.branches.deleteMany({});
  bank.fees.deleteMany({});
  bank.events.deleteMany({});

  // 3) Cuentas (100)
  const accounts = [];
  let accountId = 1000;

  for (let i = 0; i < 50; i++) {
    accounts.push({
      accountId: accountId++,
      owner: `EU_User_${String(i + 1).padStart(2, "0")}`,
      region: "EU",
      balance: 500 + ((i * 37) % 4500)
    });
  }

  for (let i = 0; i < 50; i++) {
    accounts.push({
      accountId: accountId++,
      owner: `AM_User_${String(i + 1).padStart(2, "0")}`,
      region: "AM",
      balance: 500 + ((i * 53) % 4500)
    });
  }

  bank.accounts.insertMany(accounts);

  const euIds = accounts.filter(a => a.region === "EU").map(a => a.accountId);
  const amIds = accounts.filter(a => a.region === "AM").map(a => a.accountId);
  function pick(arr, idx) { return arr[idx % arr.length]; }

  // 4) Transferencias (1000) — se mantiene tu patrón por lotes/transacción :contentReference[oaicite:6]{index=6}
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
        if (debit.matchedCount !== 1) throw new Error(`Saldo insuficiente en cuenta ${op.from}`);

        const credit = acc.updateOne(
          { accountId: op.to },
          { $inc: { balance: op.amount } }
        );
        if (credit.matchedCount !== 1) throw new Error(`Cuenta destino no existe: ${op.to}`);

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

  const totalTransfers = 1000;
  const batchSize = 50;
  const opsAll = [];

  for (let i = 0; i < totalTransfers; i++) {
    const cross = (i < 600);
    const flip = (i % 2 === 0);

    let from, to, type;
    if (cross) {
      if (flip) {
        from = pick(euIds, i);
        to   = pick(amIds, i + 7);
        type = "CROSS_EU_TO_AM";
      } else {
        from = pick(amIds, i);
        to   = pick(euIds, i + 11);
        type = "CROSS_AM_TO_EU";
      }
    } else {
      if (flip) {
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

    const amount = 1 + ((i * 19) % 200); // 1..200 determinista
    opsAll.push({
      ts: new Date(Date.now() - (totalTransfers - i) * 1000),
      from, to, amount, type
    });
  }

  print(`Generando ${totalTransfers} transferencias en lotes de ${batchSize}...`);
  let committedBatches = 0;
  for (let i = 0; i < opsAll.length; i += batchSize) {
    const res = transferBatch(opsAll.slice(i, i + batchSize));
    if (res.ok) committedBatches++;
    else print(`[WARN] Batch fallido: ${res.reason}`);
  }

  // 5) Colecciones para la “imagen”: branches (pequeña), fees (pequeña), events (grande)
  bank.branches.insertMany([
    { branchId: 1, region: "EU", name: "Santander Centro" },
    { branchId: 2, region: "EU", name: "Madrid Norte" },
    { branchId: 3, region: "AM", name: "CDMX Reforma" },
    { branchId: 4, region: "AM", name: "Bogotá Chicó" }
  ]);
  bank.branches.createIndex({ region: 1, branchId: 1 });

  bank.fees.insertMany([
    { type: "TRANSFER", feePct: 0.01 },
    { type: "PAYMENT",  feePct: 0.015 },
    { type: "CASHOUT",  feePct: 0.02 }
  ]);
  bank.fees.createIndex({ type: 1 });

  // events (grande): para shipping/semi-join/paralelización
  safe(() => bank.events.createIndex({ region: 1, accountId: 1, ts: -1 }), "createIndex events");
  safe(() => bank.events.createIndex({ branchId: 1, ts: -1 }), "createIndex events (branch)");
  safe(() => sh.shardCollection("bank.events", { region: 1, accountId: 1 }), "shardCollection events");

  // Zonas para events (mismo patrón que accounts)
  safe(() => sh.updateZoneKeyRange(
    "bank.events",
    { region: "EU", accountId: MinKey },
    { region: "EU", accountId: MaxKey },
    "ZONE_EU"
  ), "updateZoneKeyRange events EU");

  safe(() => sh.updateZoneKeyRange(
    "bank.events",
    { region: "AM", accountId: MinKey },
    { region: "AM", accountId: MaxKey },
    "ZONE_AM"
  ), "updateZoneKeyRange events AM");

  // Ajusta N para aula: 100k suele ser un buen equilibrio
    // events (grande): para shipping/semi-join/paralelización
  const N = 100000;
  const flushEvery = 2000;
  const types = ["TRANSFER", "PAYMENT", "CASHOUT"];

  print(`Generando ${N} events...`);

  let bulk = bank.events.initializeUnorderedBulkOp();
  let pending = 0;

  for (let i = 0; i < N; i++) {
    const isEU = (i % 2 === 0);
    const region = isEU ? "EU" : "AM";
    const accountIdEv = isEU ? pick(euIds, i) : pick(amIds, i);
    const typeEv = types[i % types.length];
    const branchId = isEU ? ((i % 4) < 2 ? 1 : 2) : ((i % 4) < 2 ? 3 : 4);
    const amountEv = 10 + (i % 500);

    bulk.insert({
      ts: new Date(Date.now() - (N - i) * 1000),
      region,
      accountId: accountIdEv,
      branchId,
      type: typeEv,
      amount: amountEv
    });

    pending++;

    if (pending >= flushEvery) {
      bulk.execute();
      bulk = bank.events.initializeUnorderedBulkOp();
      pending = 0;
    }
  }

  if (pending > 0) {
    bulk.execute();
  }


  // 6) Resumen para clase
  print("=== Resumen (Distributed Queries Demo) ===");
  print(`Cuentas: ${bank.accounts.countDocuments({})}`);
  print(`Transferencias COMMITTED: ${bank.transfers.countDocuments({ status: "COMMITTED" })}`);
  print(`Branches: ${bank.branches.countDocuments({})}`);
  print(`Fees: ${bank.fees.countDocuments({})}`);
  print(`Events: ${bank.events.countDocuments({})}`);

  print("=== sh.status() ===");
  sh.status();
};
