print("==> Creando roles y usuarios para 'ventas'...");

const ventasDB = db.getSiblingDB("ventas");

// Rol personalizado de auditoría: lectura + stats
try {
  ventasDB.createRole({
    role: "ventasAudit",
    privileges: [
      { resource: { db: "ventas", collection: "" }, actions: ["find", "collStats"] }
    ],
    roles: []
  });
} catch (e) {
  // Si el rol ya existe (poco probable en init limpio), no bloqueamos la demo
  print("Aviso: ventasAudit no creado (posible duplicado).");
}

// Usuarios (se crean en el DB 'ventas', por eso authSource=ventas)
try {
  ventasDB.createUser({
    user: "ventas_read",
    pwd: "ReadPass_2026!",
    roles: [{ role: "read", db: "ventas" }]
  });
} catch (e) {
  print("Aviso: ventas_read no creado (posible duplicado).");
}

try {
  ventasDB.createUser({
    user: "ventas_rw",
    pwd: "RWPass_2026!",
    roles: [{ role: "readWrite", db: "ventas" }]
  });
} catch (e) {
  print("Aviso: ventas_rw no creado (posible duplicado).");
}

try {
  ventasDB.createUser({
    user: "ventas_audit",
    pwd: "AuditPass_2026!",
    roles: [{ role: "ventasAudit", db: "ventas" }]
  });
} catch (e) {
  print("Aviso: ventas_audit no creado (posible duplicado).");
}

print("==> Listo: ventas_read, ventas_rw, ventas_audit");
