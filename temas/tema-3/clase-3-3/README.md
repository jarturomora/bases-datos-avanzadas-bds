# Guión práctico para el Tema 3 - Clase 3: Consultas Distribuidas en MongoDB

## Objetivo de la práctica

En esta práctica se trabaja sobre un **cluster MongoDB con dos shards** (EU / AM) con **replica sets** y datos de volumen para demostrar lo siguiente:

1. **Paralelización** de consultas en shards.
2. **Semi-join** (dos fases: claves → consulta final).
3. **Shipping / denormalización** (evitar joins costosos).
4. Observación de **latencia**, **uso de CPU** y **fase de merge en mongos**.

> 💡 **Nota:** Todas las consultas están pensadas para ejecutarse desde MongoDB Compass:
>
> * **Aggregations**: pipelines listos para pegar.
> * **Open Mongosh**: bloques autocontenidos (copiar/pegar).

## 1. Arranque y conexión

### 1.1 Levantar el entorno Docker

Utiliza la extensión "Container Tools" de VS Code para iniciar los contenedores, o ejecutar el siguiente comando desde el directorio del proyecto (en Windows se debe utilizar un terminal de WSL -Windows Subsystem Linux-):

```bash
docker compose up -d
```

Espera a que termine la inicialización automática.

### 1.2 Conectarse a `mongos` con MongoDB Compass

1. Abre **MongoDB Compass**
2. Elije la opción **New Connection**
3. Utiliza el siguiente connection string:

    ```text
    mongodb://localhost:27117
    ```

4. Haz clic en **Connect**

Colecciones relevantes en la base de datos: `bank`:

* `accounts` (shards por `region, accountId`)
* `events` (dimensión grande, shards por `region, accountId`)
* `branches` (dimensión pequeña)
* `fees` (dimensión pequeña)
* `transfers`

## 2. Consulta 1 — Paralelización en un cluster shardeado

### 2.1 Objetivo de esta consulta

Queremos demostrar que, en un **cluster con shards**, una consulta de agregación:

* se ejecuta **en paralelo en cada shard**,
* y luego el resultado se **fusiona en el router (`mongos`)**.

Este patrón se llama **scatter–gather + merge**.

### 2.2 Qué idea representa

Los datos (`events`) están distribuidos entre varios shards (EU y AM).
Cuando hacemos una agregación global:

* cada shard procesa **su parte local de los datos**,
* `mongos` recopila los resultados parciales,
* y devuelve el resultado final al cliente.

### 2.3 Qué ejecutar (Compass → Aggregations)

Selecciona la colección `bank.events` y pega este pipeline:

```javascript
[
  {
    $match: {
      ts: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) }
    }
  },
  {
    $group: {
      _id: "$region",
      numeroEventos: { $sum: 1 },
      importeTotal: { $sum: "$amount" }
    }
  }
]
```

#### Qué hace la consulta (paso a paso)

1. **`$match`**
   Filtra los eventos del último día (reduce el volumen de datos).

2. **`$group`**
   Agrupa por región (`EU` y `AM`) y calcula:

   * número total de eventos
   * importe total

#### Qué resultado deben ver en pantalla

Algo similar a esto:

```json
[
  { "_id": "EU", "numeroEventos": 50000, "importeTotal": 12500000 },
  { "_id": "AM", "numeroEventos": 50000, "importeTotal": 12480000 }
]
```

> 💡 **Nota:** Los valores exactos pueden variar, pero siempre habrá una fila por región.

### 2.4 Qué deben observar (muy importante)

#### Paralelización

Mientras ejecutan la consulta:

* ejecuta en otra terminal:

  ```bash
  docker stats
  ```

* observarán actividad **simultánea** en:

  * `dq-shard-eu-1`
  * `dq-shard-am-1`

#### Rol de `mongos`

* `mongos` **no almacena datos**
* solo:

  * coordina la consulta
  * fusiona resultados parciales
  * devuelve el resultado final

### 2.5 Idea clave que deben aprender

En un cluster con shards, las agregaciones globales **no se ejecutan en un solo nodo**, sino **en paralelo en todos los shards**.

## 3. Consulta 2 — Semi-Join (consulta en dos fases)

### 3.1 Objetivo de esta consulta

Queremos responder a una pregunta compleja sin hacer un join grande:

> 🙋 “¿Qué tipos de operaciones se han realizado recientemente en cuentas EU que han operado en una sucursal concreta?”

Para hacerlo de forma eficiente, usamos un **semi-join**:

1. Primero obtenemos **solo las claves relevantes**.
2. Luego usamos esas claves para la consulta final.

### 3.2 Qué idea representa

En sistemas distribuidos:

* mover documentos grandes entre nodos es caro,
* mover **listas de IDs** es mucho más barato.

El semi-join explota esta idea.

### 3.3 Parte A — Fase 1: obtener solo las claves

Utilizando la opción _Open MongoDB shell_ en Compass, copia y ejecuta el siguiente bloque:

```javascript
{
  const bank = db.getSiblingDB("bank");
  const since = new Date(Date.now() - 6 * 60 * 60 * 1000);

  const t0 = Date.now();

  const accountIds = bank.events.distinct(
    "accountId",
    {
      region: "EU",
      branchId: 1,
      ts: { $gte: since }
    }
  );

  print("Número de cuentas encontradas:", accountIds.length);
  print("Tiempo fase 1 (ms):", Date.now() - t0);
  print("Ejemplo de IDs:");
  printjson(accountIds.slice(0, 10));
}
```

#### Qué hace esta fase

* Busca **qué cuentas EU** han tenido actividad reciente en una sucursal.
* Devuelve **solo los `accountId`**, no documentos completos.

#### Qué deben ver en pantalla

Algo parecido a:

```text
Número de cuentas encontradas: 24
Tiempo fase 1 (ms): 45
Ejemplo de IDs:
[1001, 1007, 1012, 1020, 1033, 1041, 1050, 1062, 1074, 1080]
```

### 3.4 Parte B — Fase 2: consulta final usando las claves

Utilizando la opción _Open MongoDB shell_ en Compass, copia y ejecuta el siguiente bloque:

```javascript
{
  const bank = db.getSiblingDB("bank");
  const since = new Date(Date.now() - 6 * 60 * 60 * 1000);

  const accountIds = bank.events.distinct(
    "accountId",
    {
      region: "EU",
      branchId: 1,
      ts: { $gte: since }
    }
  );

  const t0 = Date.now();

  const resultado = bank.events.aggregate([
    {
      $match: {
        accountId: { $in: accountIds },
        ts: { $gte: since }
      }
    },
    {
      $group: {
        _id: "$type",
        numeroOperaciones: { $sum: 1 },
        importeTotal: { $sum: "$amount" }
      }
    }
  ]).toArray();

  print("Tiempo fase 2 (ms):", Date.now() - t0);
  printjson(resultado);
}
```

#### Qué resultado deben ver en pantalla

Algo similar a:

```json
[
  { "_id": "TRANSFER", "numeroOperaciones": 120, "importeTotal": 32000 },
  { "_id": "PAYMENT",  "numeroOperaciones": 95,  "importeTotal": 21000 },
  { "_id": "CASHOUT",  "numeroOperaciones": 60,  "importeTotal": 18000 }
]
```

### 3.5 Qué deben observar y comparar en las dos fases

#### Separación en dos fases

* Fase 1 → obtiene **pocas claves**
* Fase 2 → consulta solo lo necesario

#### Eficiencia

* No hay `$lookup`
* No se mueven documentos grandes entre nodos
* El patrón escala bien cuando los datos crecen

### 3.6 Idea clave que deben aprender

En sistemas distribuidos, **consultar primero las claves y luego los datos** suele ser más eficiente que hacer un join grande directamente.

## 4. Consulta 3 — Shipping / Denormalización

### 4.1 Objetivo de esta consulta

Queremos calcular el **importe total con comisión** de las operaciones bancarias.

La comisión depende del **tipo de operación** y está almacenada en una colección pequeña (`fees`).
Los eventos (`events`) son muchos (100.000+ documentos).

Vamos a comparar **dos formas de hacerlo**:

1. **Sin shipping** → usando `$lookup` (join en tiempo de consulta)
2. **Con shipping** → copiando la comisión dentro de cada evento (denormalización)

### 4.2 Parte A — SIN shipping (JOIN en tiempo de consulta)

#### Qué idea representa

Cada vez que consultamos los eventos:

* MongoDB tiene que **buscar la comisión en otra colección** (`fees`)
* y combinarla con cada evento.

Esto es cómodo, pero en sistemas distribuidos **puede ser más costoso**.

#### Qué ejecutar (Compass → Aggregations)

Selecciona la colección `bank.events` y pega este pipeline:

```javascript
[
  { 
    $match: { region: "EU" } 
  },
  {
    $lookup: {
      from: "fees",
      localField: "type",
      foreignField: "type",
      as: "fee"
    }
  },
  {
    $set: {
      feePct: { $first: "$fee.feePct" }
    }
  },
  {
    $set: {
      total: {
        $add: [
          "$amount",
          { $multiply: ["$amount", "$feePct"] }
        ]
      }
    }
  },
  {
    $group: {
      _id: "$type",
      numeroOperaciones: { $sum: 1 },
      importeTotalConComision: { $sum: "$total" }
    }
  }
]
```

#### Qué resultado deben ver

En pantalla aparecerá algo parecido a:

```json
[
  { "_id": "TRANSFER", "numeroOperaciones": 16667, "importeTotalConComision": 4200000 },
  { "_id": "PAYMENT",  "numeroOperaciones": 16666, "importeTotalConComision": 4350000 },
  { "_id": "CASHOUT",  "numeroOperaciones": 16667, "importeTotalConComision": 4600000 }
]
```

> 💡**Nota:** Los números exactos pueden variar, pero la estructura será esta.

#### Qué deben entender

* Se está haciendo un **join (`$lookup`)** entre `events` y `fees`.
* La comisión **no está en el evento**, se obtiene dinámicamente.
* En un cluster:

  * este join puede implicar más trabajo de CPU,
  * y más coordinación entre nodos.

### 4.3 Parte B — CON shipping (denormalización)

#### Qué idea representa

En lugar de buscar la comisión cada vez:

* **copiamos la comisión dentro de cada evento**
* y luego las consultas son mucho más simples.

Esto es un patrón típico en sistemas distribuidos.

#### Paso 1 — Copiar la comisión dentro de los eventos

Utilizando la opción _Open MongosDB shell_ en Compass, ejecuta el siguiente bloque:

```javascript
{
  const bank = db.getSiblingDB("bank");

  // Leemos la tabla pequeña (fees)
  const fees = Object.fromEntries(
    bank.fees.find({}, { _id: 0, type: 1, feePct: 1 })
      .toArray()
      .map(f => [f.type, f.feePct])
  );

  const t0 = Date.now();

  // Para cada tipo de operación, copiamos la comisión en events
  for (const [type, feePct] of Object.entries(fees)) {
    bank.events.updateMany(
      { type },
      { $set: { feePct } }
    );
  }

  print("Tiempo de materialización (ms):", Date.now() - t0);
}
```

##### Qué resultado deben ver

En la consola aparecerá algo como:

```text
Tiempo de materialización (ms): 350
```

> 💡**Nota:** El tiempo depende del equipo, pero será un único coste.

Además, si inspeccionan un documento de `events`, ahora verán:

```json
{
  "type": "TRANSFER",
  "amount": 120,
  "feePct": 0.01
}
```

#### Paso 2 — Consulta SIN join

En Compass → Aggregations, pega este pipeline en `bank.events`:

```javascript
[
  { 
    $match: { region: "EU" } 
  },
  {
    $set: {
      total: {
        $add: [
          "$amount",
          { $multiply: ["$amount", "$feePct"] }
        ]
      }
    }
  },
  {
    $group: {
      _id: "$type",
      numeroOperaciones: { $sum: 1 },
      importeTotalConComision: { $sum: "$total" }
    }
  }
]
```

##### Qué resultado deben ver

El **resultado final será equivalente** al de la Parte A:

```json
[
  { "_id": "TRANSFER", "numeroOperaciones": 16667, "importeTotalConComision": 4200000 },
  { "_id": "PAYMENT",  "numeroOperaciones": 16666, "importeTotalConComision": 4350000 },
  { "_id": "CASHOUT",  "numeroOperaciones": 16667, "importeTotalConComision": 4600000 }
]
```

Pero:

* sin `$lookup`
* con una consulta más simple
* y normalmente más rápida.

### 4.4 Qué deben comparar y anotar (muy importante)

#### Diferencias técnicas

| Sin shipping          | Con shipping           |
| --------------------- | ---------------------- |
| Usa `$lookup`         | No hay join            |
| Datos normalizados    | Datos duplicados       |
| Más coste en consulta | Más coste previo (ETL) |

#### Observaciones de rendimiento

Mientras ejecutan ambas versiones:

* Mirar `docker stats`
* Comparar:

  * uso de CPU en `mongos`
  * uso de CPU en shards
* Anotar si la segunda versión:

  * tarda menos
  * es más estable

### 4.5 Conclusión final sobre la Consulta 3

En sistemas distribuidos, **mover el dato pequeño hacia el dato grande** (shipping) suele mejorar el rendimiento de las consultas, a cambio de duplicar información y complicar las actualizaciones.

Este es un **trade-off clásico** entre:

* eficiencia en lectura
* y simplicidad del modelo de datos.

## 5. Resumen comparativo de las tres consultas

| Consulta   | Patrón         | Qué demuestra                    |
| ---------- | -------------- | -------------------------------- |
| Consulta 1 | Paralelización | Ejecución en paralelo + merge    |
| Consulta 2 | Semi-join      | Reducción de tráfico y coste     |
| Consulta 3 | Shipping       | Evitar joins con denormalización |
