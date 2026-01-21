# Guía didáctica Tema 7 - Clase 1: Seguridad y control de acceso en MongoDB con Compass

## Objetivo de la sesión

Al finalizar, el alumno habrá practicado:

* **Autenticación** (quién es el usuario) y **autorización** (qué puede hacer).
* **Role-Based Access Control (RBAC)** (roles como `read`, `readWrite` y un rol personalizado).
* Pruebas prácticas de permisos en Compass: **leer sí / escribir no**.
* Buenas prácticas: **no exponer 27017 públicamente** y separar cuentas.

## Conceptos clave

### Autenticación vs autorización

* La **autenticación** valida identidad (usuario/contraseña).
* La **autorización** limita acciones por rol (leer, insertar, actualizar, borrar, etc.).

En la demo, todos los usuarios “entran” con credenciales válidas, pero solo algunos pueden modificar datos.

### Role-Based Access Control (RBAC)

Un **rol** es un conjunto de permisos. Ejemplos:

* `read`: puede consultar.
* `readWrite`: puede consultar y modificar.
* `ventasAudit` (rol personalizado): lectura + estadísticas, sin escritura.

### Mínimo privilegio

Cada usuario debe tener **lo mínimo necesario** para su función. Esto reduce impacto si una cuenta se filtra.

## Conexión como administrador

**URI (admin):**

```text
mongodb://admin:StrongPass123!@localhost:27017/?authSource=admin
```

### Qué mostrar

1. Debe aparecer la base de datos **`ventas`**.
2. Deben existir colecciones: `clientes`, `productos`, `pedidos`.

### Consultas de verificación

**(Filtro) Ver productos de la categoría “Sillas”**

```json
{ "categoria": "Sillas" }
```

**MongoDB Sell Contar documentos por colección**

```javascript
use("ventas");

print("clientes:", db.clientes.countDocuments({}));
print("productos:", db.productos.countDocuments({}));
print("pedidos:", db.pedidos.countDocuments({}));
```

## Conexión como usuario de solo lectura (analista)

**URI (solo lectura):**

```text
mongodb://ventas_read:ReadPass_2026!@localhost:27017/ventas?authSource=ventas
```

### Objetivo didáctico

Lectura funciona, escritura debe fallar.

### Consultas (lectura)

**(Filtro) Productos con stock bajo (menos de 10)**

```json
{ "stock": { "$lt": 10 } }
```

**(Filtro) Buscar un producto por SKU**

```json
{ "sku": "SOF-001" }
```

**(Filtro) Pedidos pagados**

```json
{ "estado": "PAGADO" }
```

**MongoDB Sell Top 3 productos más caros**

```javascript
use("ventas");

db.productos
  .find({}, { nombre: 1, categoria: 1, precio: 1 })
  .sort({ precio: -1 })
  .limit(3);
```

### Prueba de permisos (escritura)

**Intento de inserción (debe fallar con ventas_read)**

En `ventas.productos` → **Insert Document**:

```json
{
  "sku": "SIL-999",
  "nombre": "Silla Demo Clase",
  "categoria": "Sillas",
  "precio": 99.99,
  "stock": 20,
  "proveedor": "Demo Clase",
  "activo": true,
  "creadoEn": { "$date": "2026-01-21T00:00:00.000Z" }
}
```

**Mensaje clave**
La autenticación fue correcta (se conectó), pero la autorización impide insertar.

## Conexión como usuario lectura/escritura (operación / backoffice)

**URI (readWrite):**

```text
mongodb://ventas_rw:RWPass_2026!@localhost:27017/ventas?authSource=ventas
```

### Inserción (debe funcionar)

**Opción 1 — Insert Document (JSON)**

```json
{
  "sku": "SIL-999",
  "nombre": "Silla Demo Clase",
  "categoria": "Sillas",
  "precio": 99.99,
  "stock": 20,
  "proveedor": "Demo Clase",
  "activo": true,
  "creadoEn": { "$date": "2026-01-21T00:00:00.000Z" }
}
```

**Opción 2 — Playground**

```javascript
use("ventas");

db.productos.insertOne({
  sku: "SIL-999",
  nombre: "Silla Demo Clase",
  categoria: "Sillas",
  precio: 99.99,
  stock: 20,
  proveedor: "Demo Clase",
  activo: true,
  creadoEn: new Date()
});
```

### Verificación

**(Filtro) Confirmar que existe**

```json
{ "sku": "SIL-999" }
```

### Actualización (subir stock)

**MongoDB Sell Incrementar stock en +5**

```javascript
use("ventas");

db.productos.updateOne(
  { sku: "SIL-999" },
  { $inc: { stock: 5 } }
);
```

**(Filtro) Revisar el stock actualizado**

```json
{ "sku": "SIL-999" }
```

### Mini-demostración de “mantenimiento” (editar datos)

**MongoDB Sell Cambiar proveedor**

```javascript
use("ventas");

db.productos.updateOne(
  { sku: "SIL-999" },
  { $set: { proveedor: "Mueblería Central" } }
);
```

## B4. Conexión como auditor (rol personalizado)

**URI (audit):**

```text
mongodb://ventas_audit:AuditPass_2026!@localhost:27017/ventas?authSource=ventas
```

### Lectura (debe funcionar)

**(Filtro) Listar pedidos pendientes**

```json
{ "estado": "PENDIENTE" }
```

**MongoDB Sell Resumen de pedidos por estado (aggregation)**

```javascript
use("ventas");

db.pedidos.aggregate([
  { $group: { _id: "$estado", totalPedidos: { $sum: 1 } } },
  { $sort: { totalPedidos: -1 } }
]);
```

### Intento de escritura (debe fallar)

**MongoDB Sell Intentar insertar un pedido (debe fallar para audit)**

```javascript
use("ventas");

db.pedidos.insertOne({
  numero: "PED-2026-0999",
  clienteId: null,
  estado: "PENDIENTE",
  fecha: new Date(),
  lineas: [],
  totales: { subtotal: 0, impuestos: 0, total: 0 }
});
```
