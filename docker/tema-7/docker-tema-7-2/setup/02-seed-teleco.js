// setup/02-seed-teleco.js
// Genera teleco_es con miles de usuarios, lineas (1..3 por usuario) y llamadas.

use("teleco_es");

// Ajustables para clase
const N_USUARIOS = 5000;
const MIN_LINEAS_POR_USUARIO = 1;
const MAX_LINEAS_POR_USUARIO = 3;
const N_LLAMADAS = 30000;

const PROVINCIAS = [
  "A_CORUNA","ALAVA","ALBACETE","ALICANTE","ALMERIA","ASTURIAS","AVILA","BADAJOZ","BALEARES","BARCELONA",
  "BURGOS","CACERES","CADIZ","CANTABRIA","CASTELLON","CEUTA","CIUDAD_REAL","CORDOBA","CUENCA","GIRONA",
  "GRANADA","GUADALAJARA","GIPUZKOA","HUELVA","HUESCA","JAEN","LA_RIOJA","LAS_PALMAS","LEON","LLEIDA",
  "LUGO","MADRID","MALAGA","MELILLA","MURCIA","NAVARRA","OURENSE","PALENCIA","PONTEVEDRA","SALAMANCA",
  "SANTA_CRUZ_TENERIFE","SEGOVIA","SEVILLA","SORIA","TARRAGONA","TERUEL","TOLEDO","VALENCIA","VALLADOLID",
  "BIZKAIA","ZAMORA","ZARAGOZA"
];

function randInt(a, b) { return Math.floor(Math.random() * (b - a + 1)) + a; }
function pick(arr) { return arr[randInt(0, arr.length - 1)]; }
function pad(n, w) { return ("" + n).padStart(w, "0"); }

function randomNIF(i) {
  // Simplificación didáctica
  return pad(10000000 + (i % 89999999), 8) + "Z";
}

const nombres = ["Lucia","Carlos","Marta","Javier","Sofia","Diego","Paula","Hugo","Valeria","Alvaro"];
const apellidos = ["Garcia","Gomez","Lopez","Sanchez","Perez","Martin","Ruiz","Hernandez","Diaz","Moreno"];

function randomNombre() { return pick(nombres) + " " + pick(apellidos) + " " + pick(apellidos); }
function randomEmail(i) { return `user${i}@teleco-demo.es`; }

// MSISDN España (simplificado): 6xxxxxxxx / 7xxxxxxxx
let msisdnCounter = 600000000;
function nextMsisdn() { return "" + (msisdnCounter++); }

print("==> Limpiando colecciones (si existen)...");
db.usuarios.drop();
db.lineas.drop();
db.llamadas.drop();

print("==> Creando índices...");
db.usuarios.createIndex({ provincia: 1, _id: 1 });
db.usuarios.createIndex({ nif: 1 }, { unique: true });

db.lineas.createIndex({ provincia: 1, _id: 1 });
db.lineas.createIndex({ msisdn: 1 }, { unique: true });
db.lineas.createIndex({ usuarioId: 1 });

db.llamadas.createIndex({ provincia: 1, _id: 1 });
db.llamadas.createIndex({ origenMsisdn: 1, inicio: -1 });
db.llamadas.createIndex({ usuarioId: 1, inicio: -1 });

print("==> Insertando usuarios y líneas...");

const allLines = []; // para generar llamadas
let userBatch = [];
let lineBatch = [];

for (let i = 1; i <= N_USUARIOS; i++) {
  const prov = pick(PROVINCIAS);
  const usuarioId = new ObjectId();

  const alta = new Date(Date.now() - randInt(0, 365) * 86400000);

  userBatch.push({
    _id: usuarioId,
    nif: randomNIF(i),
    nombre: randomNombre(),
    email: randomEmail(i),
    provincia: prov,
    ciudad: "CIUDAD_" + prov,
    altaFecha: alta,
    estado: pick(["ACTIVO","ACTIVO","ACTIVO","SUSPENDIDO"])
  });

  const nLineas = randInt(MIN_LINEAS_POR_USUARIO, MAX_LINEAS_POR_USUARIO);
  for (let k = 0; k < nLineas; k++) {
    const msisdn = nextMsisdn();
    lineBatch.push({
      _id: new ObjectId(),
      msisdn,
      usuarioId,
      provincia: prov,
      plan: pick(["PREPAGO","POSTPAGO_20","POSTPAGO_50","ILIMITADO"]),
      activa: true,
      altaFecha: alta
    });
    allLines.push({ msisdn, usuarioId, provincia: prov });
  }

  if (userBatch.length >= 1000) {
    db.usuarios.insertMany(userBatch, { ordered: false });
    userBatch = [];
  }
  if (lineBatch.length >= 2000) {
    db.lineas.insertMany(lineBatch, { ordered: false });
    lineBatch = [];
  }
}

if (userBatch.length) db.usuarios.insertMany(userBatch, { ordered: false });
if (lineBatch.length) db.lineas.insertMany(lineBatch, { ordered: false });

print(`==> Total líneas generadas: ${allLines.length}`);
print("==> Insertando llamadas...");

let callBatch = [];
for (let c = 1; c <= N_LLAMADAS; c++) {
  const origen = pick(allLines);
  let destino = pick(allLines);
  if (destino.msisdn === origen.msisdn) destino = pick(allLines);

  const dur = randInt(5, 1800);
  const coste = Math.round((dur * 0.002 + Math.random() * 0.05) * 100) / 100;
  const start = new Date(Date.now() - randInt(0, 30) * 86400000 - randInt(0, 86400) * 1000);

  callBatch.push({
    _id: new ObjectId(),
    provincia: origen.provincia,   // shard por provincia del origen (modelo docente)
    usuarioId: origen.usuarioId,
    origenMsisdn: origen.msisdn,
    destinoMsisdn: destino.msisdn,
    inicio: start,
    duracionSeg: dur,
    costeEUR: coste,
    tipo: pick(["VOZ","VOZ","VOZ","VOZ","VIDEO","DATOS"])
  });

  if (callBatch.length >= 2000) {
    db.llamadas.insertMany(callBatch, { ordered: false });
    callBatch = [];
  }
}
if (callBatch.length) db.llamadas.insertMany(callBatch, { ordered: false });

print("==> Seed completado: teleco_es (usuarios, lineas, llamadas).");
