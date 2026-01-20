// seed.js — Demo e-commerce tipo Amazon (MongoDB)
// SOLO datos + índices (sin rs.initiate)
// Diseñado para practicar: $set, $inc, $push, $pull, updateOne/updateMany,
// borrado físico/lógico y transacciones (habilitadas por el RS externo).

function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pick(arr) { return arr[randInt(0, arr.length - 1)]; }
function round2(x) { return Math.round(x * 100) / 100; }

// DB
db = db.getSiblingDB("shop");

db.products.drop();
db.customers.drop();
db.orders.drop();

// Parámetros de tamaño
const N_PRODUCTS  = 5000;
const N_CUSTOMERS = 600;
const N_ORDERS    = 12000;

// Dominios
const categories = [
  "Electronics", "Books", "Home", "Toys", "Fashion",
  "Sports", "Beauty", "Grocery", "Gaming", "Pets"
];
const brands = [
  "Acme", "Globex", "Initech", "Umbrella", "Soylent",
  "Stark", "Wayne", "Wonka", "Cyberdyne", "Tyrell"
];
const countries = ["ES", "PT", "FR", "DE", "IT", "US", "MX"];
const sizes = ["XS", "S", "M", "L", "XL", "XXL"];
const orderStatuses = ["PAID", "SHIPPED", "DELIVERED", "CANCELLED"];

/* =========================
   PRODUCTS
========================= */

print(`[seed] Insertando ${N_PRODUCTS} productos...`);
const productsBatch = [];

for (let i = 1; i <= N_PRODUCTS; i++) {
  const cat = pick(categories);
  const brand = pick(brands);
  const price = round2(randInt(5, 500) + Math.random());
  const stock = randInt(0, 200);
  const rating = round2(Math.random() * 5);

  const tags = [];
  if (Math.random() < 0.4) tags.push("featured");
  if (Math.random() < 0.3) tags.push("sale");
  if (Math.random() < 0.2) tags.push("new");

  const hasSizes = (cat === "Fashion");
  const availableSizes = hasSizes
    ? [...new Set([pick(sizes), pick(sizes)])]
    : [];

  productsBatch.push({
    _id: i,
    sku: `SKU-${String(i).padStart(6, "0")}`,
    name: `${brand} ${cat} Product ${i} ${Math.random() < 0.5 ? "Premium" : "Base"}`,
    category: cat,
    brand,
    price,
    stock,
    rating,
    tags,
    availableSizes,
    active: true,
    createdAt: new Date(Date.now() - randInt(0, 90) * 86400000),
    updatedAt: new Date()
  });

  if (productsBatch.length === 1000) {
    db.products.insertMany(productsBatch);
    productsBatch.length = 0;
  }
}
if (productsBatch.length) db.products.insertMany(productsBatch);

/* =========================
   CUSTOMERS
========================= */

print(`[seed] Insertando ${N_CUSTOMERS} clientes...`);
const custBatch = [];

for (let i = 1; i <= N_CUSTOMERS; i++) {
  custBatch.push({
    _id: i,
    email: `customer${i}@shop.com`,
    name: `Customer ${i}`,
    country: pick(countries),
    loyaltyPoints: randInt(0, 2000),
    active: true,
    createdAt: new Date(Date.now() - randInt(0, 365) * 86400000),
    updatedAt: new Date()
  });
}
db.customers.insertMany(custBatch);

/* =========================
   ORDERS (items embebidos)
========================= */

print(`[seed] Insertando ${N_ORDERS} pedidos...`);
const ordersBatch = [];

for (let i = 1; i <= N_ORDERS; i++) {
  const customerId = randInt(1, N_CUSTOMERS);
  const nItems = randInt(1, 5);
  const items = [];
  let subtotal = 0;

  for (let j = 0; j < nItems; j++) {
    const productId = randInt(1, N_PRODUCTS);
    const qty = randInt(1, 3);
    const unitPrice = round2(randInt(5, 500) + Math.random());
    subtotal += unitPrice * qty;

    items.push({ productId, qty, unitPrice });
  }

  const shipping = round2(Math.random() < 0.7 ? randInt(0, 7) + Math.random() : 0);
  const total = round2(subtotal + shipping);

  ordersBatch.push({
    _id: i,
    customerId,
    status: pick(orderStatuses),
    items,
    subtotal: round2(subtotal),
    shipping,
    total,
    createdAt: new Date(Date.now() - randInt(0, 60) * 86400000),
    updatedAt: new Date(),
    active: true
  });

  if (ordersBatch.length === 1000) {
    db.orders.insertMany(ordersBatch);
    ordersBatch.length = 0;
  }
}
if (ordersBatch.length) db.orders.insertMany(ordersBatch);

/* =========================
   INDEXES
========================= */

print("[index] Creando índices...");

db.products.createIndex({ sku: 1 }, { unique: true });
db.products.createIndex({ category: 1, price: 1 });
db.products.createIndex({ name: "text" });
db.products.createIndex({ active: 1, stock: 1 });

db.customers.createIndex({ email: 1 }, { unique: true });
db.customers.createIndex({ country: 1, loyaltyPoints: -1 });

db.orders.createIndex({ customerId: 1, createdAt: -1 });
db.orders.createIndex({ status: 1, createdAt: -1 });
db.orders.createIndex({ "items.productId": 1 });

print("[seed] DB 'shop' inicializada correctamente.");
print(` - products:  ${db.products.countDocuments({})}`);
print(` - customers: ${db.customers.countDocuments({})}`);
print(` - orders:    ${db.orders.countDocuments({})}`);
