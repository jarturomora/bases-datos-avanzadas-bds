# Entorno Docker de la demo (Cassandra + Stargate)

Este proyecto levanta un **clúster Apache Cassandra** en Docker y un servicio **Stargate** para acceder a Cassandra mediante **APIs** y **Swagger UI**. La idea es que puedas practicar:

* CQL (consultas y modelado por particiones)
* Replicación y clúster (varios nodos)
* Acceso vía API (sin necesidad de drivers en tu PC)

## Servicios que se levantan

### 1) cass1, cass2, cass3 (Cassandra oficial)

* Son **tres nodos** Cassandra dentro del mismo clúster.
* Forman un **anillo (ring)** y se comunican entre sí por la red interna de Docker.
* El keyspace `ecommerce` se crea con replicación para clúster (típicamente `replication_factor = 3`), lo que significa que **los datos se replican en los 3 nodos**.

**Puertos:**

* Solo `cass1` expone **9042** a tu máquina (`localhost:9042`) para que puedas entrar fácilmente con `cqlsh`.
* `cass2` y `cass3` no exponen puertos al host (solo red interna), porque para la práctica basta con entrar por `cass1`.

### 2) stargate (APIs + Swagger UI)

* Stargate es una “capa” encima de Cassandra que permite trabajar con Cassandra usando **HTTP APIs**.
* Incluye **Swagger UI**, que te permite probar endpoints desde el navegador.

**Puertos típicos:**

* `8081`: Auth API (para obtener token)
* `8082`: Swagger UI / API gateway (para probar endpoints)

## Datos de ejemplo (e-commerce ~1000 filas)

Al arrancar el entorno, se carga un dataset de práctica en el keyspace `ecommerce` con tablas pensadas para aprender Cassandra “como se debe”: **diseño por consulta** y uso de **particiones**.

Tablas principales:

* `products_by_id`

  * **Partition Key:** `product_id`
  * Uso típico: buscar un producto por su id.

* `customers_by_id`

  * **Partition Key:** `customer_id`
  * Uso típico: buscar un cliente por su id.

* `orders_by_id`

  * **Partition Key:** `customer_id`
  * **Clustering Key:** `order_id`
  * Uso típico: ver *todos los pedidos de un cliente* (una partición = un cliente).

* `order_items_by_order`

  * **Partition Key:** `order_id`
  * **Clustering Key:** `line_no`
  * Uso típico: ver *las líneas de un pedido* (una partición = un pedido).

Conteos orientativos del dataset:

* 300 productos
* 200 clientes
* 200 pedidos
* 300 líneas de pedido
* Total ≈ **1000 filas**
