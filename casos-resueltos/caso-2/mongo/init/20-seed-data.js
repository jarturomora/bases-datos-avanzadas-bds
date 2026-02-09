db = db.getSiblingDB("eco_store");

function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pick(arr) { return arr[randInt(0, arr.length - 1)]; }
function round2(n) { return Math.round(n * 100) / 100; }

const categories = [
  { c: "fruta", names: ["Manzana", "Plátano", "Pera", "Naranja", "Kiwi"] },
  { c: "verdura", names: ["Tomate", "Lechuga", "Zanahoria", "Calabacín", "Espinaca"] },
  { c: "lacteos", names: ["Leche", "Yogur", "Queso fresco", "Kéfir"] },
  { c: "panaderia", names: ["Pan integral", "Pan masa madre", "Galletas avena"] },
  { c: "despensa", names: ["Lentejas", "Garbanzos", "Arroz integral", "Avena"] },
  { c: "bebidas", names: ["Kombucha", "Zumo naranja", "Infusión"] },
  { c: "higiene", names: ["Jabón natural", "Champú sólido", "Pasta dientes"] }
];

const regions = ["Navarra", "Cataluña", "Valencia", "Andalucía", "Galicia", "Madrid"];
const farms = ["Huerta Viva", "BioSol", "VerdeRaíz", "EcoCampo", "La Colmena"];

const products = [];
let skuCounter = 1000;

for (const group of categories) {
  const baseTax = (group.c === "higiene") ? 0.21 : 0.10;
  for (const baseName of group.names) {
    for (let i = 0; i < 6; i++) {
      const sku = `ECO-${skuCounter++}`;
      const name = `${baseName} ${pick(["BIO", "Eco", "KM0", "Premium", "Familiar", "Granel"])}`;
      const price = round2(randInt(120, 999) / 100);
      products.push({
        sku,
        name,
        category: group.c,
        tags: [group.c, "eco", pick(["sin_gluten", "vegano", "local", "temporada", "artesanal"])],
        price,
        tax: baseTax,
        isOrganic: true,
        origin: { country: "España", region: pick(regions), farm: pick(farms) },
        nutrition: (group.c === "fruta" || group.c === "verdura")
          ? { kcal_100g: randInt(15, 90), fiber_g: randInt(1, 8) }
          : { kcal_100g: randInt(80, 450) },
        active: true
      });
    }
  }
}

db.products.insertMany(products);

// Índices compuestos y clave
db.products.createIndex({ sku: 1 }, { unique: true });
db.products.createIndex({ category: 1, price: 1 });
db.products.createIndex({ "origin.region": 1, category: 1 });

const customerDomains = ["mail.com", "eco.net", "example.org"];
const customers = [];
for (let i = 1; i <= 120; i++) {
  customers.push({
    email: `cliente${i}@${pick(customerDomains)}`,
    name: `Cliente ${i}`,
    phone: `6${randInt(10000000, 99999999)}`,
    loyalty: { level: pick(["bronze", "silver", "gold"]), points: randInt(0, 2500) },
    addresses: [{
      city: pick(["Madrid", "Barcelona", "Valencia", "Sevilla", "Bilbao"]),
      zip: `${randInt(10000, 52999)}`,
      street: `Calle ${randInt(1, 200)}`
    }],
    createdAt: new Date(Date.now() - randInt(1, 500) * 86400000)
  });
}
db.customers.insertMany(customers);
db.customers.createIndex({ email: 1 }, { unique: true });

const customerIds = db.customers.find({}, { _id: 1 }).toArray().map(d => d._id);

const orderCount = 900;
const startDaysAgo = 120;

const orders = [];
const moves = [];

for (let o = 1; o <= orderCount; o++) {
  const createdAt = new Date(Date.now() - randInt(0, startDaysAgo) * 86400000 - randInt(0, 86400) * 1000);
  const channel = pick(["store", "web", "subscription"]);
  const status = pick(["paid", "paid", "paid", "shipped", "created", "cancelled"]);
  const customerId = pick(customerIds);

  const itemsN = randInt(1, 6);
  const items = [];
  let subtotal = 0;
  let tax = 0;

  for (let k = 0; k < itemsN; k++) {
    const p = pick(products);
    const qty = randInt(1, 4);
    const discount = (Math.random() < 0.15) ? round2(randInt(5, 30) / 100) : 0;
    const line = round2(p.price * qty * (1 - discount));
    subtotal += line;
    tax += line * p.tax;

    items.push({
      sku: p.sku,
      name: p.name,
      qty,
      unitPrice: p.price,
      taxRate: p.tax,
      discount
    });

    moves.push({
      sku: p.sku,
      type: "out",
      qty: -qty,
      ts: createdAt,
      ref: { orderNo: `ORD-${String(o).padStart(5, "0")}` }
    });
  }

  subtotal = round2(subtotal);
  tax = round2(tax);
  const total = round2(subtotal + tax);

  orders.push({
    orderNo: `ORD-${String(o).padStart(5, "0")}`,
    customerId,
    createdAt,
    status,
    channel,
    items,
    totals: { subtotal, tax, total },
    payment: (status === "paid" || status === "shipped")
      ? { method: pick(["card", "bizum", "cash"]), paidAt: createdAt }
      : { method: null }
  });
}

db.orders.insertMany(orders);
db.inventory_movements.insertMany(moves);

// Índices para analítica
db.orders.createIndex({ orderNo: 1 }, { unique: true });
db.orders.createIndex({ createdAt: -1, status: 1 });
db.orders.createIndex({ channel: 1, createdAt: -1 });
db.orders.createIndex({ "items.sku": 1, createdAt: -1 });

print("Seed completado: eco_store listo.");
