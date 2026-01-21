print("==> Seed de base de datos 'ventas' (mueblería)");

const ventasDB = db.getSiblingDB("ventas");

// Limpieza idempotente (para reinicios con volumen vacío no hace falta, pero ayuda si cambias el init)
ventasDB.clientes.drop();
ventasDB.productos.drop();
ventasDB.pedidos.drop();

// Colecciones
const clientes = ventasDB.clientes;
const productos = ventasDB.productos;
const pedidos = ventasDB.pedidos;

// Datos: Productos (muebles)
const productosDocs = [
  { sku: "SOF-001", nombre: "Sofá 3 plazas Oslo", categoria: "Sofás", precio: 799.99, stock: 12, proveedor: "NordicHome", activo: true },
  { sku: "MES-010", nombre: "Mesa comedor Roble 160cm", categoria: "Mesas", precio: 649.00, stock: 7, proveedor: "Maderas Iberia", activo: true },
  { sku: "SIL-120", nombre: "Silla Tapizada Verona", categoria: "Sillas", precio: 129.50, stock: 48, proveedor: "Verona Design", activo: true },
  { sku: "CAM-200", nombre: "Cama Queen Lina con canapé", categoria: "Dormitorio", precio: 899.00, stock: 5, proveedor: "Descanso Plus", activo: true },
  { sku: "ARM-300", nombre: "Armario 2 puertas Blanco", categoria: "Dormitorio", precio: 499.00, stock: 9, proveedor: "LineaHogar", activo: true },
  { sku: "EST-050", nombre: "Estantería Modular Metro", categoria: "Almacenaje", precio: 259.00, stock: 15, proveedor: "UrbanWood", activo: true }
];

productos.insertMany(productosDocs);

// Datos: Clientes
const clientesDocs = [
  { dni: "12345678A", nombre: "Lucía Pérez", email: "lucia.perez@example.com", telefono: "+34 600 111 222", ciudad: "Madrid", vip: true, creadoEn: new Date() },
  { dni: "87654321B", nombre: "Carlos Gómez", email: "carlos.gomez@example.com", telefono: "+34 600 333 444", ciudad: "Valencia", vip: false, creadoEn: new Date() },
  { dni: "11223344C", nombre: "Marta Ruiz", email: "marta.ruiz@example.com", telefono: "+34 600 555 666", ciudad: "Barcelona", vip: false, creadoEn: new Date() }
];

const clientesRes = clientes.insertMany(clientesDocs);

// Helpers para referenciar IDs insertados
const clienteLuciaId = clientesRes.insertedIds["0"];
const clienteCarlosId = clientesRes.insertedIds["1"];

// Buscar productos por SKU para armar pedidos
function prodBySku(sku) {
  return productos.findOne({ sku }, { projection: { _id: 1, sku: 1, nombre: 1, precio: 1 } });
}

const pSofa = prodBySku("SOF-001");
const pMesa = prodBySku("MES-010");
const pSilla = prodBySku("SIL-120");

// Datos: Pedidos
const pedidosDocs = [
  {
    numero: "PED-2026-0001",
    clienteId: clienteLuciaId,
    estado: "PAGADO",
    fecha: new Date(),
    lineas: [
      { productoId: pSofa._id, sku: pSofa.sku, nombre: pSofa.nombre, cantidad: 1, precioUnitario: pSofa.precio },
      { productoId: pSilla._id, sku: pSilla.sku, nombre: pSilla.nombre, cantidad: 4, precioUnitario: pSilla.precio }
    ],
    totales: { subtotal: 1 * pSofa.precio + 4 * pSilla.precio, impuestos: 0, total: 1 * pSofa.precio + 4 * pSilla.precio },
    pago: { metodo: "TARJETA", referencia: "TPV-9A12", pagadoEn: new Date() }
  },
  {
    numero: "PED-2026-0002",
    clienteId: clienteCarlosId,
    estado: "PENDIENTE",
    fecha: new Date(),
    lineas: [
      { productoId: pMesa._id, sku: pMesa.sku, nombre: pMesa.nombre, cantidad: 1, precioUnitario: pMesa.precio }
    ],
    totales: { subtotal: 1 * pMesa.precio, impuestos: 0, total: 1 * pMesa.precio },
    pago: { metodo: "TRANSFERENCIA", referencia: null, pagadoEn: null }
  }
];

pedidos.insertMany(pedidosDocs);

// Índices útiles para demo
clientes.createIndex({ dni: 1 }, { unique: true });
clientes.createIndex({ email: 1 }, { unique: true });
productos.createIndex({ sku: 1 }, { unique: true });
productos.createIndex({ categoria: 1 });
pedidos.createIndex({ numero: 1 }, { unique: true });
pedidos.createIndex({ clienteId: 1, fecha: -1 });

print("==> Seed completado. DB 'ventas' creada con colecciones: clientes, productos, pedidos");
