db = db.getSiblingDB("exchange");

/* =========================
   Colecciones
========================= */

db.users.drop();
db.assets.drop();
db.orders.drop();
db.trades.drop();

/* =========================
   Usuarios
========================= */

const users = [];
for (let i = 1; i <= 2000; i++) {
  users.push({
    _id: i,
    email: `user${i}@exchange.com`,
    country: i % 2 === 0 ? "ES" : "US",
    createdAt: new Date()
  });
}
db.users.insertMany(users);

/* =========================
   Criptoactivos
========================= */

db.assets.insertMany([
  { symbol: "BTC", name: "Bitcoin" },
  { symbol: "ETH", name: "Ethereum" },
  { symbol: "SOL", name: "Solana" },
  { symbol: "ADA", name: "Cardano" }
]);

/* =========================
   Órdenes (volumen grande)
========================= */

const orders = [];
const symbols = ["BTC", "ETH", "SOL", "ADA"];
const sides = ["BUY", "SELL"];

for (let i = 1; i <= 50000; i++) {
  orders.push({
    userId: Math.floor(Math.random() * 2000) + 1,
    symbol: symbols[i % symbols.length],
    side: sides[i % 2],
    price: Number((Math.random() * 50000 + 10).toFixed(2)),
    amount: Number((Math.random() * 5).toFixed(4)),
    status: "OPEN",
    createdAt: new Date(Date.now() - Math.random() * 1000 * 60 * 60 * 24)
  });

  if (i % 1000 === 0) {
    db.orders.insertMany(orders);
    orders.length = 0;
  }
}
if (orders.length) db.orders.insertMany(orders);

/* =========================
   Trades
========================= */

const trades = [];
for (let i = 1; i <= 20000; i++) {
  trades.push({
    symbol: symbols[i % symbols.length],
    price: Number((Math.random() * 50000 + 10).toFixed(2)),
    amount: Number((Math.random() * 2).toFixed(4)),
    executedAt: new Date(Date.now() - Math.random() * 1000 * 60 * 60)
  });

  if (i % 1000 === 0) {
    db.trades.insertMany(trades);
    trades.length = 0;
  }
}
if (trades.length) db.trades.insertMany(trades);

/* =========================
   Índices (lecturas eficientes)
========================= */

db.users.createIndex({ email: 1 }, { unique: true });

db.orders.createIndex({ symbol: 1, price: 1 });
db.orders.createIndex({ userId: 1 });
db.orders.createIndex({ createdAt: -1 });

db.trades.createIndex({ symbol: 1, executedAt: -1 });
