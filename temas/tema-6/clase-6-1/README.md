# Guía didáctica Tema 6 - Clase 1: Operaciones de inserción y lectura

## Objetivo de la práctica

En esta práctica trabajaremos con una base de datos MongoDB que simula un **exchange de criptomonedas**. El objetivo es que el alumno:

* entienda el modelo de documentos y su relación con el dominio (usuarios, órdenes y trades),
* ejecute consultas reales usando **MongoDB Compass**,
* practique **filtros compuestos** y **operadores de comparación**,
* y realice inserciones masivas con **MongoDB Shell** (dentro de Compass).

## Dónde ejecutar cada cosa en Compass

Usaremos tres zonas de Compass:

1. **Documents → Filter / Sort / Project / Limit**
   Para consultas tipo `find`, filtros, proyección, ordenación y paginación visual.

2. **Aggregations → Pipeline**
   Para análisis con `aggregate` (group, avg, sum, etc.).

3. **MongoDB Shell** (botón “Open MongoDB Shell”)
   Para ejecutar código JS/consultas que conviene lanzar como bloques, por ejemplo `insertMany`, `deleteOne`, scripts, etc.

## Contexto del dominio

Base de datos: `exchange`

Colecciones principales:

* `users` → usuarios del exchange
* `assets` → criptomonedas disponibles
* `orders` → órdenes BUY/SELL
* `trades` → operaciones ejecutadas

## Ejercicio 1 — Exploración inicial del modelo

### Objetivo

Familiarizarse con colecciones y estructura de documentos.

### Compass

* En la base de datos `exchange`, abre:

  * `users` → **Documents**
  * `orders` → **Documents**
  * `trades` → **Documents**
* Abre 2–3 documentos de cada colección.

### Qué observar

* Campos típicos del dominio: `symbol`, `side`, `price`, `amount`, `status`, `createdAt`.
* Cómo se referencian relaciones (por ejemplo `userId` en `orders`).

## Ejercicio 2 — Lecturas simples (find)

### 2.1 Órdenes de BTC

**Compass → orders → Documents → Filter**

```javascript
{ symbol: "BTC" }
```

### 2.2 Órdenes BUY de ETH

**Compass → orders → Documents → Filter**

```javascript
{ symbol: "ETH", side: "BUY" }
```

## Ejercicio 3 — Filtros compuestos (AND/OR) y operadores de comparación

### 3.1 Filtro compuesto (AND) con comparaciones

**Objetivo:** Encontrar órdenes BTC de compra con precio alto y cantidad mínima.
**Compass → orders → Documents → Filter**

```javascript
{
  symbol: "BTC",
  side: "BUY",
  price: { $gte: 20000 },
  amount: { $gte: 0.5 }
}
```

**Qué observar**

* `$gte` significa “mayor o igual que”.
* Este filtro equivale a un AND lógico (todas las condiciones deben cumplirse).

### 3.2 Filtro compuesto con OR

**Objetivo:** Ver órdenes de BTC o ETH, pero solo las que estén OPEN.
**Compass → orders → Documents → Filter**

```javascript
{
  status: "OPEN",
  $or: [
    { symbol: "BTC" },
    { symbol: "ETH" }
  ]
}
```

**Qué observar**

* `$or` permite combinar alternativas.
* El resto de campos fuera de `$or` también se aplican (AND con el OR).

### 3.3 Operadores de comparación útiles (ejemplos rápidos)

**Compass → orders → Documents → Filter**

* Mayor que (`$gt`):

```javascript
{ price: { $gt: 30000 } }
```

* Menor o igual (`$lte`):

```javascript
{ amount: { $lte: 0.1 } }
```

* Rango (`$gte` + `$lte`):

```javascript
{ price: { $gte: 1000, $lte: 2000 } }
```

* Distinto de (`$ne`):

```javascript
{ status: { $ne: "OPEN" } }
```

## Ejercicio 4 — Proyección (devolver solo campos necesarios)

**Objetivo:** Reducir datos devueltos (equivalente a “SELECT columnas”).
**Compass → orders → Documents**

* Filter:

```javascript
{ symbol: "BTC" }
```

* Project:

```javascript
{ _id: 0, symbol: 1, side: 1, price: 1, amount: 1, createdAt: 1 }
```

**Qué observar**

* Una proyección sirve para decidir qué campos quieres que aparezcan en el resultado de una consulta.
* La proyección reduce la carga y suele mejorar eficiencia.
* La proyección es como decir “qué columnas quiero ver”, igual que en SQL.

## Ejercicio 5 — Ordenación y paginación

### 5.1 Últimas 10 órdenes por fecha

**Compass → orders → Documents**

* Sort:

```javascript
{ createdAt: -1 }
```

* Limit:

```text
10
```

### 5.2 Paginación (página 2)

**Compass → orders → Documents**

* Sort:

```javascript
{ createdAt: -1 }
```

* Skip:

```text
10
```

* Limit:

```text
10
```

**Qué observar**

* `skip + limit` simula paginación.
* En producción, para paginación profunda suele usarse “range pagination” (tema avanzado).

## Ejercicio 6 — Consultas analíticas con Aggregations

### 6.1 Total de órdenes por criptomoneda

**Compass → orders → Aggregations → Pipeline**

```javascript
[
  { $group: { _id: "$symbol", totalOrders: { $sum: 1 } } },
  { $sort: { totalOrders: -1 } }
]
```

### 6.2 Precio medio por criptomoneda

**Compass → orders → Aggregations → Pipeline**

```javascript
[
  { $group: { _id: "$symbol", avgPrice: { $avg: "$price" } } },
  { $sort: { avgPrice: -1 } }
]
```

**Qué observar**

* `aggregate` se expresa como un pipeline (etapas).
* `$group` equivale conceptualmente a `GROUP BY` en SQL.

## Ejercicio 7 — Inserción masiva con insertMany (MongoDB Shell)

### Objetivo

Crear varias órdenes nuevas de forma eficiente.

**Compass → Open MongoDB Shell**
Copia y pega este bloque completo:

```javascript
use exchange;

db.orders.insertMany([
  {
    userId: 1,
    symbol: "BTC",
    side: "BUY",
    price: 30500.25,
    amount: 0.15,
    status: "OPEN",
    createdAt: new Date()
  },
  {
    userId: 2,
    symbol: "ETH",
    side: "SELL",
    price: 1850.10,
    amount: 1.20,
    status: "OPEN",
    createdAt: new Date()
  },
  {
    userId: 3,
    symbol: "SOL",
    side: "BUY",
    price: 98.55,
    amount: 10,
    status: "OPEN",
    createdAt: new Date()
  }
]);
```

### Qué observar

* `insertMany` inserta múltiples documentos en una sola operación.
* Es la base de las “inserciones masivas” (bulk insert) en sistemas con alta carga.

## Ejercicio 8 — Eliminación controlada (Delete)

### 8.1 Verificar si existen trades para una orden (ejemplo didáctico)

En esta demo, `trades` no referencia directamente una `orderId` (modelo simplificado).
Aun así, practicaremos una eliminación segura basada en un criterio.

**Compass → orders → Documents → Filter**

```javascript
{ status: "OPEN", userId: 1, symbol: "BTC" }
```

### 8.2 Eliminar una orden OPEN específica

**Compass → Open MongoDB Shell**

```javascript
use exchange;

db.orders.deleteOne({ status: "OPEN", userId: 1, symbol: "BTC" });
```

**Qué observar**

* MongoDB no impone claves foráneas automáticamente.
* En sistemas reales, la integridad se gestiona por:

  * modelado,
  * validación,
  * o lógica de aplicación.
