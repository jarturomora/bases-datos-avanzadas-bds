// DB: catalogo
db = db.getSiblingDB("catalogo");

// Colecciones
db.categorias.drop();
db.productos.drop();
db.clientes.drop();
db.compras.drop();

// Categorías
const categorias = [];
for (let i = 1; i <= 20; i++) {
  categorias.push({ _id: i, nombre: `Categoria ${i}` });
}
db.categorias.insertMany(categorias);

// Clientes
const clientes = [];
for (let i = 1; i <= 2000; i++) {
  clientes.push({
    _id: i,
    email: `cliente${i}@demo.local`,
    nombre: `Cliente ${i}`,
    creadoEn: new Date()
  });
}
db.clientes.insertMany(clientes);

// Productos
const productos = [];
for (let i = 1; i <= 10000; i++) {
  const categoriaId = (i % 20) + 1;
  productos.push({
    _id: i,
    sku: `SKU-${i}`,
    nombre: `Producto ${i} / ${i % 2 === 0 ? "Premium" : "Base"}`,
    categoriaId,
    precio: 10 + (i % 500),
    stock: 50 + (i % 200),
    actualizadoEn: new Date()
  });
}
db.productos.insertMany(productos);

// Compras (50.000) como documentos de línea
const compras = [];
function randInt(max) { return Math.floor(Math.random() * max) + 1; }

for (let i = 1; i <= 50000; i++) {
  const clienteId = randInt(2000);
  const productoId = randInt(10000);
  const cantidad = randInt(4);
  const precioUnitario = 10 + Math.floor(Math.random() * 500);
  const compradoEn = new Date(Date.now() - Math.floor(Math.random() * 30) * 24*60*60*1000);

  compras.push({
    _id: i,
    clienteId,
    productoId,
    cantidad,
    precioUnitario,
    compradoEn
  });

  if (i % 5000 === 0) {
    db.compras.insertMany(compras);
    compras.length = 0;
  }
}
if (compras.length) db.compras.insertMany(compras);

// Índices equivalentes
db.productos.createIndex({ categoriaId: 1 });
db.productos.createIndex({ nombre: "text" });
db.clientes.createIndex({ email: 1 }, { unique: true });
db.productos.createIndex({ sku: 1 }, { unique: true });
db.compras.createIndex({ clienteId: 1 });
db.compras.createIndex({ productoId: 1 });
