# Guía didáctica Tema 6 - Clase 2: Actualizaciones, borrado y transacciones

## Objetivo de la práctica

Practicar operaciones de **actualización, borrado y transacciones** en MongoDB usando una base de datos realista de comercio electrónico.

Al finalizar, el alumno sabrá:

* modificar documentos con `$set` y `$inc`,
* trabajar con arrays usando `$push` y `$pull`,
* diferenciar `updateOne` vs `updateMany`,
* aplicar **borrado lógico** y **borrado físico**,
* ejecutar una **transacción multi-documento** (pedido + stock).

## Conexión (IMPORTANTE)

Usa **MongoDB Compass** con esta URI:

```text
mongodb://localhost:27017/?directConnection=true
```

Base de datos: `shop`

## Dónde ejecutar cada ejercicio en Compass

* **Documents → Filter / Update**
  Para `find`, `updateOne`, `updateMany`, `deleteOne`, `deleteMany`.

* **MongoDB Shell**
  Para bloques JS más largos y **transacciones**.

## `$set` — Actualización directa de campos

### Ejemplo 1: Cambiar el precio de un producto

**Objetivo:** modificar un campo concreto.

**Compass → products → Documents → Filter**

```javascript
{ sku: "SKU-000010" }
```

**Update**

```javascript
{
  $set: { price: 299.99, updatedAt: new Date() }
}
```

> 📌 Observa que **solo cambia el precio**, no el resto del documento.

### Ejemplo 2: Actualizar la categoría de varios productos

**Compass → products → Documents → Filter**

```javascript
{ category: "Electronics", price: { $lt: 20 } }
```

**Update (updateMany)**

```javascript
{
  $set: { category: "Clearance", updatedAt: new Date() }
}
```

## `$inc` — Incrementos y decrementos numéricos

### Ejemplo 1: Incrementar puntos de fidelidad

**Compass → customers → Documents → Filter**

```javascript
{ _id: 10 }
```

**Update**

```javascript
{
  $inc: { loyaltyPoints: 100 }
}
```

### Ejemplo 2: Reducir stock tras una venta

**Compass → products → Documents → Filter**

```javascript
{ _id: 25 }
```

**Update**

```javascript
{
  $inc: { stock: -1 }
}
```

> 📌 `$inc` evita leer-modificar-escribir manualmente.

## `$push` — Añadir elementos a arrays

### Ejemplo 1: Añadir una etiqueta a un producto

**Compass → products → Documents → Filter**

```javascript
{ _id: 100 }
```

**Update**

```javascript
{
  $push: { tags: "popular" }
}
```

### Ejemplo 2: Añadir un ítem a un pedido existente

**Compass → orders → Documents → Filter**

```javascript
{ _id: 50 }
```

**Update**

```javascript
{
  $push: {
    items: { productId: 200, qty: 1, unitPrice: 49.99 }
  }
}
```

## `$pull` — Eliminar elementos de arrays

### Ejemplo 1: Quitar una etiqueta

**Compass → products → Documents → Filter**

```javascript
{ tags: "sale" }
```

**Update**

```javascript
{
  $pull: { tags: "sale" }
}
```

### Ejemplo 2: Eliminar un ítem de un pedido

**Compass → orders → Documents → Filter**

```javascript
{ "items.productId": 200 }
```

**Update**

```javascript
{
  $pull: { items: { productId: 200 } }
}
```

## `updateOne` vs `updateMany`

### Ejemplo 1: `updateOne`

Actualiza **solo un documento**.

```javascript
{ _id: 1 }
```

```javascript
{
  $set: { active: false }
}
```

### Ejemplo 2: `updateMany`

Actualiza **muchos documentos**.

```javascript
{ stock: 0 }
```

```javascript
{
  $set: { active: false }
}
```

> 📌 Ideal para reglas globales (productos sin stock).

## Borrado lógico

### Ejemplo 1: Desactivar un cliente

```javascript
{ _id: 5 }
```

```javascript
{
  $set: { active: false, updatedAt: new Date() }
}
```

---

### Ejemplo 2: Desactivar pedidos cancelados

```javascript
{ status: "CANCELLED" }
```

```javascript
{
  $set: { active: false }
}
```

> 📌 Los datos **siguen existiendo**, solo se excluyen en consultas.

## Borrado físico (`deleteOne`, `deleteMany`)

### Ejemplo 1: Borrar un producto inactivo sin stock

**Compass → products → Documents → Filter**

```javascript
{ active: false, stock: 0 }
```

**Delete**

```javascript
deleteOne
```

### Ejemplo 2: Borrar pedidos antiguos cancelados

```javascript
{ status: "CANCELLED", createdAt: { $lt: new Date("2024-01-01") } }
```

```javascript
deleteMany
```

> ⚠️ En sistemas reales, se usa con cautela.

## Transacción multi-documento (pedido + stock)

**MongoDB Shell** (en Compass)

### Objetivo

* Crear un pedido
* Reducir stock
* Todo **atómicamente**

```javascript
use shop;

const session = db.getMongo().startSession();
const sdb = session.getDatabase("shop");

try {
  session.startTransaction();

  sdb.products.updateOne(
    { _id: 1, stock: { $gte: 1 } },
    { $inc: { stock: -1 } }
  );

  sdb.orders.insertOne({
    customerId: 1,
    status: "PAID",
    items: [{ productId: 1, qty: 1, unitPrice: 99.99 }],
    subtotal: 99.99,
    shipping: 0,
    total: 99.99,
    createdAt: new Date(),
    active: true
  });

  session.commitTransaction();
  print("TRANSACCIÓN CONFIRMADA");
} catch (e) {
  session.abortTransaction();
  print("TRANSACCIÓN ABORTADA:", e.message);
} finally {
  session.endSession();
}
```

> 📌 Si falla el stock → **no se crea el pedido**.
