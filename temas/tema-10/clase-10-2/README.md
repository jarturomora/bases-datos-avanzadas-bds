# Guía Didáctica Tema 10 - Clase 2: Operaciones y escalado en Cassandra

## Objetivos

En esta demo vas a aprender **cómo funciona Cassandra por dentro** cuando trabajamos con un clúster:

* Que Cassandra es **peer-to-peer** (no hay “servidor principal”).
* Que los datos se guardan en **varios nodos** gracias a la **replicación**.
* Que puedes elegir el nivel de **consistencia** (`ONE`, `QUORUM`, `ALL`) según lo que te interese.
* Qué herramientas usar para **ver el estado del clúster** y hacer **mantenimiento** (`nodetool`).

> Importante: **usaremos la misma base `ecommerce`** y los mismos datos (~1000 filas) que en el tema anterior.

## 1) Arranca el entorno

Abre una terminal en la carpeta donde está tu `docker-compose.yml` e inicia los contenedores desde la herramienta Container Tools, o ejecuta los siguientes comandos:

```bash
docker compose up -d
docker compose ps
```

✅ Debes ver:

* `cass1`, `cass2`, `cass3` en estado `Up (healthy)`.
* Ten en cuenta que el arranque puede tardar hasta 10 minutos.

## 2) Comprueba que el clúster (el “ring”) está operando correctamente

Ejecuta:

```bash
docker exec -it cass1 nodetool status
```

✅ Debes ver 3 nodos con estado `UN` (Up/Normal).

**¿Qué significa esto?**

* Cassandra funciona como un **anillo (ring)**.
* No hay “master”: **los 3 nodos son iguales**.

## 3) Accede a Cassandra con CQL (cqlsh)

Entra al intérprete:

```bash
docker exec -it cass1 cqlsh
```

Ahora escribe:

```sql
USE ecommerce;
```

## 4) Comprueba que estamos en 1 datacenter (DC) y con replicación

Dentro de `cqlsh`:

```sql
DESCRIBE KEYSPACE ecommerce;
```

Qué debes buscar:

* Que use `SimpleStrategy` (típico en local).
* Que tenga `replication_factor` (normalmente 3).

**Interpretación**

* Si el RF es 3, Cassandra guarda **copias** de los datos en **3 nodos**.

## 5) Prueba el “peer-to-peer”: consulta desde nodos distintos

Vamos a lanzar la **misma consulta** desde nodos diferentes.
Sal de `cqlsh` (`EXIT;`) o abre otra terminal.

### 5.1 Consulta desde cass1

```bash
docker exec -it cass1 cqlsh -e "CONSISTENCY QUORUM; USE ecommerce; SELECT * FROM orders_by_id WHERE customer_id='cust_0001' LIMIT 5;"
```

### 5.2 Consulta desde cass2

```bash
docker exec -it cass2 cqlsh -e "CONSISTENCY QUORUM; USE ecommerce; SELECT * FROM orders_by_id WHERE customer_id='cust_0001' LIMIT 5;"
```

✅ Debes obtener resultados similares.

**Qué estás viendo**

* Cualquier nodo puede actuar como **coordinador**.
* El coordinador habla con las réplicas y te devuelve el resultado.

## 6) Ver “en qué nodos” vive una partición (replicación real)

Vamos a elegir una partición concreta. Usaremos un producto, por ejemplo `prod_01`.

Ejecuta:

```bash
docker exec -it cass1 nodetool getendpoints ecommerce products_by_id prod_01
```

✅ Te saldrá una lista de nodos.

**Qué significa**

* Esos nodos son los que guardan la **partición** `prod_01`.
* Si RF=3, lo normal es que salgan **3 nodos**.

## 7) Consistencia: ONE vs QUORUM vs ALL (lo importante)

Ahora vas a crear un pedido nuevo y ver cómo cambia el comportamiento según la consistencia.

### 7.1 Inserta un pedido con QUORUM (equilibrio)

Accede nuevamente a `cqlsh` en cass1.

```bash
docker exec -it cass1 cqlsh
```

Ahora inserta un nuevo pedido:

```sql
CONSISTENCY QUORUM;
USE ecommerce;
INSERT INTO orders_by_id (customer_id, order_id, order_ts, status, total)
VALUES ('cust_0001','order_99',toTimestamp(now()),'PAID',120.00);
```

### 7.2 Lée el nuevo pedido con CONSISTENCY ONE (más rápido)

```sql
CONSISTENCY ONE;
USE ecommerce;
SELECT * FROM orders_by_id WHERE customer_id='cust_0001' AND order_id='order_99';
```

**Idea clave**

* `ONE`: responde con **1 réplica** (rápido).
* `QUORUM`: exige **mayoría** (en RF=3 suele ser 2/3).
* `ALL`: exige **todas** las réplicas (máxima consistencia, menos tolerancia a fallos).

## 8) Simula un fallo: para un nodo y mira qué pasa

### 8.1 Para el contenedor de cass3

Abre una nueva ventana de terminal, y ejecuta estos comandos:

```bash
docker stop cass3
docker exec -it cass1 nodetool status
```

Ahora el clúster tiene un nodo caído.

### 8.2 Intenta escribir con ALL (esto debería fallar)

Regresa al terminal donde tienes iniciado `cqlsh` en cass1, e intenta lo siguiente:

```sql
CONSISTENCY ALL;
USE ecommerce;
INSERT INTO orders_by_id (customer_id, order_id, order_ts, status, total)
VALUES ('cust_0001','order_98',toTimestamp(now()),'PAID',88.00);
```

✅ Si falla, es correcto.

**Por qué falla**

* `ALL` necesita 3/3 nodos.
* Si uno está caído, no se puede cumplir.

### 8.3 Ahora prueba con QUORUM (esto debería funcionar)

```bash
CONSISTENCY QUORUM;
USE ecommerce;
INSERT INTO orders_by_id (customer_id, order_id, order_ts, status, total)
VALUES ('cust_0001','order_98',toTimestamp(now()),'PAID',88.00);
```

Y lo compruebas, abre una terminal más y conéctate a `cqlsh` en cass2:

```bash
docker exec -it cass2 cqlsh
```

Ahora, ejecuta la siguiente consulta:

```sql
CONSISTENCY ONE;
USE ecommerce;
SELECT * FROM orders_by_id WHERE customer_id='cust_0001' AND order_id='order_98';
```

## 9) Vuelve a levantar el nodo (recuperación)

```bash
docker start cass3
docker exec -it cass1 nodetool status
```

✅ Debes volver a ver los 3 nodos `UN`.

**Qué debes entender**

* Cassandra está pensada para seguir funcionando aunque un nodo caiga.
* La replicación + consistencia tunable te permite elegir el equilibrio.

## 10) Mantenimiento: “repair” (reparación de réplicas)

Para finalizar, ejecuta un repair del keyspace:

```bash
docker exec -it cass1 nodetool repair ecommerce
```

**Qué significa**

* Cassandra compara réplicas y corrige diferencias (anti-entropy repair).
* No es algo que hagas cada minuto, pero es importante saber que existe.
