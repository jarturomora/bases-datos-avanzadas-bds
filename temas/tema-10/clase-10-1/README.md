# Guía Didáctica Tema 10 - Clase 1: Cassandra - modelo columnar y consistencia

## 1) Idea clave antes de comenzar

### Cassandra no se diseña “como SQL”

En Cassandra **no modelas “entidades y relaciones”** para luego preguntar cualquier cosa.

En Cassandra **diseñas tablas para responder consultas concretas** (query-based modeling).

### Qué es una partición

En una tabla Cassandra, la **partition key** decide:

* **en qué nodo(s)** vive el dato
* **cómo se agrupan** filas relacionadas
* el rendimiento: Cassandra es rápida cuando consultas **por partición**

Una partición es “el cajón” donde Cassandra guarda juntas filas que comparten la misma _partition key_.

## 2) Por qué tener varios nodos

Con 3 nodos y `replication_factor = 3`:

1. **Alta disponibilidad**: si cae un nodo, el sistema puede seguir atendiendo (según consistencia).
2. **Tolerancia a fallos**: hay copias del dato en varios nodos.
3. **Escalabilidad horizontal**: más nodos → más capacidad (lecturas/escrituras repartidas).
4. **Consistencia configurable (tunable consistency)**: puedes elegir entre rapidez o garantías (`ONE`, `QUORUM`, `ALL`).

## 3) Arranque del entorno

```bash
docker compose up -d
docker compose ps
```

## 4) Verificar clúster (3 nodos)

```bash
docker exec -it cass1 nodetool status
```

Debes ver **3 nodos `UN`**.

## 5) Entrar a Cassandra

```bash
docker exec -it cass1 cqlsh
```

### Parte A — Entender las tablas y sus particiones

El siguiente diagrama, ilustra la base de datos que utilizaremos:

* **Partition Key:** agrupa y decide dónde se guarda el dato (la “partición”).
* **Clustering Key:** ordena filas dentro de esa partición.
* **Las flechas** son relaciones lógicas (Cassandra no aplica foreign keys).

```mermaid
flowchart LR
  subgraph KS["Keyspace: ecommerce"]
    P["products_by_id
PK (Partition Key): product_id
cols: name, category, price, stock"]

    C["customers_by_id
PK (Partition Key): customer_id
cols: full_name, email, city, created_at"]

    O["orders_by_id
Partition Key: customer_id
Clustering Key: order_id
cols: order_ts, status, total"]

    I["order_items_by_order
Partition Key: order_id
Clustering Key: line_no
cols: product_id, qty, unit_price, line_total"]
  end

  C -->|"customer_id (mis pedidos)"| O
  O -->|"order_id (detalle del pedido)"| I
  P -->|"product_id (referencia lógica)"| I
```

Por otro lado, las particiones son nodos dentro la estructura como muestra la siguiente figure:

```mermaid
flowchart TB
  subgraph EX[" "]
    direction LR

    EX_T["Ejemplo de particiones en Cassandra (Keyspace: ecommerce)"]:::title

    subgraph S1[" "]
      direction TB
      S1_T["Partición en orders_by_id (Partition Key = customer_id)"]:::subtitle

      PKC["customer_id = cust_001"]:::pk
      O1["order_id = order_001\nstatus=PAID\ntotal=45.50"]:::row
      O2["order_id = order_002\nstatus=PAID\ntotal=78.50"]:::row
      O3["order_id = order_003\nstatus=PAID\ntotal=32.50"]:::row

      PKC --> O1
      PKC --> O2
      PKC --> O3

      NOTE1["Clustering Key: order_id (Ordena las filas dentro de la partición)"]:::note
    end

    subgraph S2[" "]
      direction TB
      S2_T["Partición en order_items_by_order (Partition Key = order_id)"]:::subtitle

      PKO["order_id = order_001"]:::pk
      L1["line_no = 1\nproduct_id=prod_001\nqty=1\nunit_price=15.99\nline_total=15.99"]:::row
      L2["line_no = 2\nproduct_id=prod_007\nqty=2\nunit_price=9.99\nline_total=19.98"]:::row
      L3["line_no = 3\nproduct_id=prod_012\nqty=1\nunit_price=9.53\nline_total=9.53"]:::row

      PKO --> L1
      PKO --> L2
      PKO --> L3

      NOTE2["Clustering Key: line_no (Ordena las líneas dentro del pedido)"]:::note
    end
  end

  %% Conexión lógica: un pedido (order_01) referencia la partición de sus líneas
  O1 -->|"order_id"| PKO

  %% Estilos (sin colores explícitos para máxima compatibilidad)
  classDef title font-weight:bold,font-size:16px;
  classDef subtitle font-weight:bold,font-size:13px;
  classDef pk font-weight:bold;
  classDef note font-style:italic;
  classDef row font-weight:normal;
```

Vamos a comenzar utilizando el keyspace:

```sql
USE ecommerce;
```

#### A1) Tabla `products_by_id`

```sql
DESCRIBE TABLE products_by_id;
```

* **Partition key**: `product_id` (porque es la PRIMARY KEY)
* Cada producto es una partición distinta (particiones pequeñas, acceso directo).

✅ Consulta ideal:

```sql
SELECT * FROM products_by_id WHERE product_id='prod_0001';
```

**Qué aprenden**: Cassandra vuela cuando preguntas por **PK/partition key**.

#### A2) Tabla `customers_by_id`

```sql
DESCRIBE TABLE customers_by_id;
```

* **Partition key**: `customer_id`
* Igual: acceso directo.

✅ Consulta ideal:

```sql
SELECT * FROM customers_by_id WHERE customer_id='cust_0001';
```

#### A3) Tabla `orders_by_id` (ojo, aquí está la “magia”)

```sql
DESCRIBE TABLE orders_by_id;
```

Estructura (resumen):

* **Partition key**: `customer_id`
* **Clustering key**: `order_id`

**¿Qué significa esto?**

* Cassandra guarda **todos los pedidos de un cliente juntos**, en la misma partición.
* Dentro de esa partición, ordena/organiza por `order_id` (clustering).

✅ Consulta para “ver pedidos de un cliente”:

```sql
SELECT * FROM orders_by_id WHERE customer_id='cust_0001';
```

**Por qué es bueno**:

* Es una consulta típica de e-commerce (“mis pedidos”).
* Se resuelve leyendo **una sola partición**, muy rápido.

**Limitación típica**:

* No es buena para: “dame todos los pedidos del sistema” sin partition key.
* En Cassandra, eso se modela con otra tabla si lo necesitas.

#### A4) Tabla `order_items_by_order`

```sql
DESCRIBE TABLE order_items_by_order;
```

* **Partition key**: `order_id`
* **Clustering key**: `line_no`

✅ Consulta típica “líneas de un pedido”:

```sql
SELECT * FROM order_items_by_order WHERE order_id='order_0001';
```

**Idea clave**: si tu pantalla/endpoint necesita “ver detalle del pedido”, esta tabla está hecha exactamente para esa consulta.

### Parte B — Verificar datos (los ~1000 registros)

```sql
SELECT count(*) FROM products_by_id;
SELECT count(*) FROM customers_by_id;
SELECT count(*) FROM orders_by_id;
SELECT count(*) FROM order_items_by_order;
```

Esperado: **300 + 200 + 200 + 300 = 1000**

### Parte C — Operaciones básicas (CRUD)

#### C1) Insertar un producto

```sql
INSERT INTO products_by_id (product_id,name,category,price,stock)
VALUES ('prod_demo','Demo Product','electronics',99.99,20);

SELECT * FROM products_by_id WHERE product_id='prod_demo';
```

#### C2) Actualizar stock

```sql
UPDATE products_by_id SET stock = 15 WHERE product_id='prod_demo';
SELECT product_id,stock FROM products_by_id WHERE product_id='prod_demo';
```

#### C3) Borrar

```sql
DELETE FROM products_by_id WHERE product_id='prod_demo';
```

### Parte D — Por qué 3 nodos importa (consistencia + caída)

#### D1) Cambiar consistencia en cqlsh

```sql
CONSISTENCY;
CONSISTENCY ONE;
```

Prueba lectura:

```sql
SELECT * FROM customers_by_id WHERE customer_id='cust_0001';
```

Cambia a QUORUM:

```sql
CONSISTENCY QUORUM;
SELECT * FROM customers_by_id WHERE customer_id='cust_0001';
```

##### Qué significa (explicación corta)

Con RF=3:

* `ONE`: responde con 1 réplica (más rápido, menos garantías)
* `QUORUM`: responde con mayoría (2 de 3) → equilibrio típico
* `ALL`: exige las 3 réplicas → máxima garantía, peor tolerancia a fallos

#### D2) Simular caída de un nodo

En otra terminal:

```bash
docker stop cass3
```

Verifica:

```bash
docker exec -it cass1 nodetool status
```

Ahora prueba:

```sql
CONSISTENCY ONE;
SELECT * FROM customers_by_id WHERE customer_id='cust_0001';
```

Luego:

```sql
CONSISTENCY ALL;
SELECT * FROM customers_by_id WHERE customer_id='cust_0001';
```

**Resultado esperado**:

* Con `ONE` normalmente funciona (queda al menos 1 réplica)
* Con `ALL` puede fallar porque no están las 3 réplicas disponibles

Levanta el nodo:

```bash
docker start cass3
```

### Parte E — Stargate + Swagger (mínimo viable)

#### E1) Swagger UI

* `http://localhost:8082/swagger-ui/`

#### E2) Obtener token (Auth API)

En PowerShell:

```powershell
$body = @{ username="cassandra"; password="cassandra" } | ConvertTo-Json
$resp = Invoke-RestMethod -Method Post -Uri "http://localhost:8081/v1/auth" -ContentType "application/json" -Body $body
$resp.authToken
```

En WSL o Git Bash:

```bash
curl -L -X POST "http://localhost:8081/v1/auth" \
  -H "Content-Type: application/json" \
  --data-raw '{"username":"cassandra","password":"cassandra"}'
```

#### E3) Usar token en Swagger

1. Abre: <http://localhost:8082/swagger-ui/>

2. En cualquier endpoint, añade el header:

    * Header name: _X-Cassandra-Token_
    * Value: (pega el token)

## Conclusiones

* **Partición** = grupo de filas con la misma partition key (se guardan juntas).
* Cassandra es rápida si consultas por **partition key**.
* Con **varios nodos + replicación**, ganas disponibilidad y puedes ajustar consistencia (`ONE/QUORUM/ALL`).
