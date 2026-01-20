# Guía didáctica Tema 6 - Clase 3: Aggregation Pipeline y Map-Reduce en MongoDB

## Objetivo de la práctica

En esta práctica aprenderemos a realizar **análisis de datos complejos directamente en MongoDB**, sin exportar información a herramientas externas, utilizando:

* **Aggregation Pipeline**
* **Map-Reduce**
* Técnicas de **optimización** (`$match`, índices, `explain()`)

Todo ello sobre una base de datos realista de **comercio electrónico tipo Amazon**.

## Conexión a MongoDB

Usa **MongoDB Compass** con la siguiente URI:

```text
mongodb://localhost:27017/?directConnection=true
```

Base de datos: `shop`
Colecciones principales:

* `products`
* `customers`
* `orders`

## Dónde ejecutar cada ejercicio en Compass

* **Aggregations** → para Aggregation Pipeline
* **MongoDB Shell** → para Map-Reduce y `explain()`

## Introducción al Aggregation Pipeline

El **Aggregation Pipeline** funciona como una **tubería de etapas**, donde:

* cada etapa transforma los documentos,
* y pasa el resultado a la siguiente.

📌 Ventajas clave:

* Modular y legible
* Muy eficiente
* Optimizable con índices

## Pipeline básico: conteo de documentos

### Ejercicio 1 — Número total de productos

**Compass → products → Aggregations**

```javascript
[
  { $count: "totalProducts" }
]
```

### Qué observar

* `$count` es una forma simplificada de `$group + $sum`.
* MongoDB realiza el cálculo sin mover datos fuera del motor.

## `$match` + `$group`: análisis por categoría

### Ejercicio 1 — Número de productos por categoría

**Compass → products → Aggregations**

```javascript
[
  {
    $group: {
      _id: "$category",
      totalProducts: { $sum: 1 }
    }
  },
  { $sort: { totalProducts: -1 } }
]
```

### Qué observar

* `$group` equivale conceptualmente a un `GROUP BY` en SQL.
* `_id` representa la clave de agrupación.

### Ejercicio 2 — Precio medio por categoría

```javascript
[
  {
    $group: {
      _id: "$category",
      avgPrice: { $avg: "$price" }
    }
  },
  { $sort: { avgPrice: -1 } }
]
```

## `$match` antes de `$group` (optimización clave)

### Ejercicio 1 — Precio medio solo para productos activos

```javascript
[
  { $match: { active: true } },
  {
    $group: {
      _id: "$category",
      avgPrice: { $avg: "$price" }
    }
  }
]
```

### Punto clave para el alumno

Filtrar **antes** de agrupar reduce datos y mejora el rendimiento.

## `$project`: control del resultado

### Ejercicio 1 — Reformatear el resultado

```javascript
[
  {
    $group: {
      _id: "$category",
      avgPrice: { $avg: "$price" }
    }
  },
  {
    $project: {
      _id: 0,
      category: "$_id",
      avgPrice: 1
    }
  }
]
```

### Qué observar

* `$project` permite renombrar campos.
* Mejora la legibilidad del resultado final.

## `$lookup`: combinando colecciones

### Ejercicio 1 — Pedidos con datos del cliente

**Compass → orders → Aggregations**

```javascript
[
  {
    $lookup: {
      from: "customers",
      localField: "customerId",
      foreignField: "_id",
      as: "customer"
    }
  },
  { $unwind: "$customer" },
  {
    $project: {
      _id: 0,
      orderId: "$_id",
      customer: "$customer.name",
      country: "$customer.country",
      total: 1,
      status: 1
    }
  }
]
```

### Qué observar

* `$lookup` es el equivalente a un **JOIN** en SQL.
* `$unwind` convierte arrays en documentos individuales.

## Análisis de ventas

### Ejercicio 1 — Total vendido por cliente

```javascript
[
  {
    $group: {
      _id: "$customerId",
      totalSpent: { $sum: "$total" }
    }
  },
  { $sort: { totalSpent: -1 } },
  { $limit: 10 }
]
```

### Ejercicio 2 — Número de pedidos por estado

```javascript
[
  {
    $group: {
      _id: "$status",
      totalOrders: { $sum: 1 }
    }
  }
]
```

## `explain()` y análisis de rendimiento

### Ejercicio 1 — Analizar uso de índices

**MongoDB Shell**

```javascript
db.orders.explain("executionStats").aggregate([
  { $match: { status: "PAID" } },
  { $group: { _id: "$customerId", total: { $sum: "$total" } } }
]);
```

**Compass → orders → Aggregations**

```javascript
[
  { $match: { status: "PAID" } },
  { $group: { _id: "$customerId", total: { $sum: "$total" } } }
]
```

Hacer click en "Explain".

### Qué observar

* `COLLSCAN` vs `IXSCAN`
* Número de documentos examinados

## Map-Reduce (comparación)

📍 **MongoDB Shell**

### Ejercicio 1 — Conteo de productos por categoría (Map-Reduce)

```javascript
db.products.mapReduce(
  function () {
    emit(this.category, 1);
  },
  function (key, values) {
    return Array.sum(values);
  },
  {
    out: "products_by_category"
  }
);
```

Consulta el resultado:

```javascript
db.products_by_category.find();
```

## Comparación conceptual Agregación Vs. Map-Reduce

| Aspecto         | Aggregation Pipeline | Map-Reduce          |
| --------------- | -------------------- | ------------------- |
| Rendimiento     | Muy alto             | Más lento           |
| Legibilidad     | Alta                 | Media               |
| Optimización    | Excelente            | Limitada            |
| Uso recomendado | ✅ Por defecto       | ⚠️ Casos especiales |

> 📌 **Reflexión importante:**
> Siempre que sea posible, **usar Aggregation Pipeline** en lugar de Map-Reduce.

## Cierre

Esta práctica demuestra que MongoDB no es solo un almacén de documentos, sino un **motor analítico potente**, capaz de realizar análisis complejos **dentro de la base de datos**, de forma eficiente y escalable.
