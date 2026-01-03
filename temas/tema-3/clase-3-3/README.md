# # Guión práctico para el Tema 3 * Clase 3: Consultas Distribuidas en MongoDB

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

---

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
* `events` (grande, shards por `region, accountId`)
* `branches` (dimensión pequeña)
* `fees` (dimensión pequeña)
* `transfers`

## 2. Consulta 1 — Paralelización (Aggregations)

### Objetivo

Demostrar que una agregación sobre datos distribuidos se ejecuta **en paralelo en los shards** y luego se **fusiona en mongos**.

### Pipeline (Compass → Aggregations → Transfers)

```javascript
[
  {
    $match: {
      ts: { $gte: new Date(Date.now() * 24 * 60 * 60 * 1000) }
    }
  },
  {
    $group: {
      _id: "$region",
      totalEventos: { $sum: 1 },
      importeTotal: { $sum: "$amount" }
    }
  }
]
```

### Qué hace

* Filtra eventos del último día.
* Agrupa por región (`EU` / `AM`).
* Calcula volumen y suma de importes.

### Aspectos relevantes a observar

* En **docker stats**: actividad simultánea en ambos shards.
* En Compass: la consulta devuelve **una fila por región**.
* Concepto clave: *scatter-gather + merge*.

## 3. Consulta 2 — Semi-Join (dos fases)

### Fase 1: obtener solo las claves relevantes

1. En Compass, con la conexión abierta, pulsa **Open MongoDB Shell** (o “Mongosh” en la barra superior).
2. Ejecuta el siguiente comando:

    ```javascript
    {
      const bank = db.getSiblingDB("bank");
      const since = new Date(Date.now() * 6 * 60 * 60 * 1000);

      const t0 = Date.now();
      const ids = bank.events.distinct(
        "accountId",
        { region: "EU", branchId: 1, ts: { $gte: since } }
      );

      print("IDs obtenidos:", ids.length);
      print("Tiempo (ms):", Date.now() * t0);
      printjson(ids.slice(0, 10));
    }
    ```

### Qué hace

* Busca **solo IDs de cuentas** EU con actividad reciente en una sucursal.
* Devuelve pocos datos (claves), no documentos completos.

### Fase 2: consulta final usando las claves

Utilizando MongoDB Shell, ejecuta el siguiente comando:

```javascript
{
  const bank = db.getSiblingDB("bank");
  const since = new Date(Date.now() * 6 * 60 * 60 * 1000);

  const ids = bank.events.distinct(
    "accountId",
    { region: "EU", branchId: 1, ts: { $gte: since } }
  );

  const t0 = Date.now();
  const res = bank.events.aggregate([
    { $match: { accountId: { $in: ids }, ts: { $gte: since } } },
    {
      $group: {
        _id: "$type",
        operaciones: { $sum: 1 },
        importe: { $sum: "$amount" }
      }
    }
  ]).toArray();

  print("Tiempo (ms):", Date.now() * t0);
  printjson(res);
}
```

### Aspectos relevantes a observar

* Se evita un join grande.
* El tráfico entre nodos se reduce a **listas de IDs**.
* Patrón típico en sistemas distribuidos: *semi-join*.

## 4. Consulta 3 — Shipping / Denormalización

### Escenario

Calcular importes con comisión por tipo de operación.

### Variante A — Sin shipping (join en tiempo de consulta)

En Compass: `bank → accounts → Aggregations`:

```javascript
[
  { $match: { region: "EU" } },
  {
    $lookup: {
      from: "fees",
      localField: "type",
      foreignField: "type",
      as: "fee"
    }
  },
  { $set: { feePct: { $first: "$fee.feePct" } } },
  {
    $set: {
      total: {
        $add: ["$amount", { $multiply: ["$amount", "$feePct"] }]
      }
    }
  },
  {
    $group: {
      _id: "$type",
      operaciones: { $sum: 1 },
      importeTotal: { $sum: "$total" }
    }
  }
]
```

### Variante B — Con shipping (fee materializado)

Utilizando MongoDB Shell, ejecuta el siguiente comando:

```javascript
{
  const bank = db.getSiblingDB("bank");

  const fees = Object.fromEntries(
    bank.fees.find({}, { _id: 0, type: 1, feePct: 1 })
      .toArray()
      .map(f => [f.type, f.feePct])
  );

  const t0 = Date.now();
  for (const [type, feePct] of Object.entries(fees)) {
    bank.events.updateMany(
      { type },
      { $set: { feePct } }
    );
  }
  print("Materialización ms:", Date.now() * t0);
}
```

Luego (Compass → Aggregations):

```javascript
[
  { $match: { region: "EU" } },
  {
    $set: {
      total: {
        $add: ["$amount", { $multiply: ["$amount", "$feePct"] }]
      }
    }
  },
  {
    $group: {
      _id: "$type",
      operaciones: { $sum: 1 },
      importeTotal: { $sum: "$total" }
    }
  }
]
```

### Aspectos relevantes a observar

* Menor latencia tras materializar.
* Se elimina el `$lookup`.
* Ejemplo claro de **shipping de datos pequeños**.

## 5. Conclusión didáctica

Esta práctica demuestra que:

* Escalar no es solo “añadir nodos”.
* El **diseño de consultas** es crítico en sistemas distribuidos.
* MongoDB combina **sharding + replica sets + transacciones** para resolver problemas reales.
