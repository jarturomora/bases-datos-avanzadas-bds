# Caso 2: API CRUD y analítica de ventas con MongoDB

En este caso práctico, se simula un escenario de negocio de una tienda de alimentación ecológica empleando MongoDB.

## 1. Estructura del proyecto

Antes de empezar, es importante entender **qué contiene el proyecto y para qué sirve cada parte**.

```text
eco-store-api/
├─ docker-compose.yml        # Orquestación de MongoDB, mongo-init y API
├─ .env                      # Variables de entorno (URI Mongo, DB_NAME)
│
├─ api/                      # API REST (FastAPI)
│  ├─ Dockerfile
│  ├─ requirements.txt       # Librerías requeridas para la API
│  └─ app/
│     ├─ main.py             # Punto de entrada de la API
│     ├─ db.py               # Conexión a MongoDB
│     ├─ models.py           # Modelos Pydantic (validación API)
│     └─ routers/
│        ├─ products.py          # CRUD de productos
│        ├─ orders.py            # Pedidos + transacciones
│        └─ analytics.py         # Endpoints de analítica
│
└─ mongo/
   ├─ mongod.conf                # Configuración de MongoDB (replica set)
   └─ init/
      ├─ mongo-init.sh           # Inicialización del RS + seed
      ├─ 10-schema-validation.js # Definición del esquema
      └─ 20-seed-data.js         # Creación de datos
```

### Qué debes entender de esta estructura

* **MongoDB** se inicializa automáticamente (replica set + datos).
* La **API no crea la base de datos**, solo la consume.
* **MongoDB Compass** se usa para ver y analizar datos.
* **Postman** se usa para consumir la API como cliente HTTP.

> 📣 **Nota:** Si no tienes instalado _Postman_, puedes descargarlo desde [este enlace](https://www.postman.com/downloads/).

## 2. Objetivos de aprendizaje

Al finalizar la práctica serás capaz de:

* Comprender un **modelo documental real**
* Analizar **validación de datos** en MongoDB
* Usar **índices** y justificar su necesidad
* Construir **Aggregation Pipelines**
* Consumir una **API REST** usando Postman (configuración manual)
* Entender **transacciones multi-documento**
* Relacionar operaciones CRUD con métricas de negocio

## 3. Arranque del entorno

### Actividad 3.1 — Levantar Docker

Levanta el contenedor utilizando la extensión Container Tools de Visual Studio Code (VSCode) o ejecutando el siguiente comando desde la terminal.

```bash
docker compose up -d --build
```

### Actividad 3.2 — Verificar API

Abre en el navegador y valida las siguientes URLs.

* Swagger: <http://localhost:3000/docs>
* Health check: <http://localhost:3000/health>

**Resultado**

* Deberás poder ver la documentación.
* El endpoint `/health` devuelve:

    ```json
    { "ok": true }
    ```

## 4. MongoDB Compass

### Actividad 4.1 — Conexión a MongoDB

En MongoDB Compass, conéctate a la instancia con la siguiente dirección:

* URI:

    ```text
    mongodb://localhost:27017/?directConnection=true
    ```

* Base de datos: `eco_store`

**Resultado**
Visualizas las colecciones:

* `products`
* `customers`
* `orders`
* `inventory_movements`

## 5. Exploración del modelo documental (Compass)

### Actividad 5.1 — Colección `products`

Desde Compass, abre un documento de la colección `products`.

Observa:

* Campos obligatorios (`sku`, `price`, `category`)
* Campos opcionales (`origin`, `nutrition`)
* Arrays (`tags`)
* Subdocumentos

**Resultado**
Entiendes que MongoDB permite **estructuras flexibles**, pero **controladas por validación**.

### Actividad 5.2 — Validación de datos

En `products` → pestaña **Validation**.

**Resultado**
Compruebas reglas como:

* `price >= 0`
* `tax <= 0.25`
* valores cerrados para `category`

### Actividad 5.3 — Probar validación manual

Inserta manualmente este documento desde Compass:

```json
{
  "sku": "ECO-FAIL",
  "name": "Producto inválido",
  "category": "despensa",
  "price": -5,
  "tax": 0.1,
  "isOrganic": true,
  "active": true
}
```

**Resultado**
MongoDB rechaza el documento por incumplir el esquema.

## 6. Índices y rendimiento (Compass)

### Actividad 6.1 — Ver índices

Desde Compass → `products` → **Indexes**

Localiza:

```json
{ category: 1, price: 1 }
```

**Resultado**
Identificas el índice que acelera filtros por categoría y precio.

### Actividad 6.2 — Explain Plan

Filtro:

```json
{ category: "fruta", price: { $lte: 3 }, active: true }
```

Pulsa **Explain Plan**.

**Resultado**
MongoDB usa el índice y reduce documentos examinados.

## 7. Analítica con Aggregation Pipeline (Compass)

### Actividad 7.1 — Ventas diarias

Pipeline en `orders`:

```js
[
  { $match: { status: { $in: ["paid", "shipped"] } } },
  {
    $group: {
      _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
      orders: { $sum: 1 },
      revenue: { $sum: "$totals.total" }
    }
  },
  { $sort: { _id: 1 } }
]
```

**Resultado**
Ventas agregadas por día.

### Actividad 7.2 — Top productos vendidos

Pipeline en `orders`:

```js
[
  { $unwind: "$items" },
  {
    $group: {
      _id: "$items.sku",
      units: { $sum: "$items.qty" },
      revenue: { $sum: { $multiply: ["$items.qty", "$items.unitPrice"] } }
    }
  },
  { $sort: { units: -1 } },
  { $limit: 10 }
]
```

**Resultado**
Top 10 productos más vendidos.

## 8. Postman

### Actividad 8.1 — Configuración inicial

En Postman:

1. Crear Environment `Eco API Local`
2. Variable:

   * `baseUrl` → `http://localhost:3000`

3. En requests con body:

   * Header: `Content-Type: application/json`

## 9. CRUD de productos vía API (Postman)

### Actividad 9.1 — Listar productos

**Método:** `GET`
**URL:**

```text
{{baseUrl}}/api/products?category=verdura&minPrice=1.5&maxPrice=4
```

**Resultado**
Listado filtrado (usa índices internamente).

### Actividad 9.2 — Crear producto

**Método:** `POST`
**URL:**

```text
{{baseUrl}}/api/products
```

```json
{
  "sku": "ECO-9999",
  "name": "Miel cruda BIO 500g",
  "category": "despensa",
  "tags": ["eco", "artesanal"],
  "price": 8.95,
  "tax": 0.1,
  "isOrganic": true,
  "active": true
}
```

**Resultado**
Producto creado y visible en Compass.

### Actividad 9.3 — Actualizar producto

**Método:** `PATCH`
**URL:**

```text
{{baseUrl}}/api/products/ECO-9999
```

```json
{
  "price": 9.25,
  "tagsAdd": ["nuevo"]
}
```

### Actividad 9.4 — Borrado lógico

**Método:** `DELETE`
**URL:**

```text
{{baseUrl}}/api/products/ECO-9999
```

**Resultado**
`active = false`, el documento no se elimina.

## 10. Transacción multi-documento (Postman)

### Actividad 10.1 — Crear pedido

**Método:** `POST`
**URL:**

```text
{{baseUrl}}/api/orders
```

```json
{
  "customerEmail": "cliente1@mail.com",
  "channel": "web",
  "items": [
    { "sku": "ECO-1000", "qty": 2 },
    { "sku": "ECO-1010", "qty": 1 }
  ],
  "payment": { "method": "card" }
}
```

**Resultado**

* Pedido creado
* Movimientos de inventario creados en la misma transacción

## 11. Analítica vía API (Postman)

### Actividad 11.1 — Ventas diarias

**Método:** `GET`

```text
{{baseUrl}}/api/analytics/sales/daily?days=30
```

### Actividad 11.2 — Top productos

**Método:** `GET`

```text
{{baseUrl}}/api/analytics/top-products?limit=10
```

### Actividad 11.3 — Ventas por canal

**Método:** `GET`

```text
{{baseUrl}}/api/analytics/sales/by-channel?months=6
```
