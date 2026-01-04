# Guión práctico para el Tema 3 - Clase 2: Fragmentación, replicación y transacciones distribuidas en MongoDB

## Objetivo

En esta demostración se empleará la herramienta MongoDB Compass para **identificar y comprobar** la manera en la que cómo MongoDB:

1. **Fragmenta horizontalmente (sharding)** los datos para escalar, dividiéndolos por región/sucursal.  
2. **Replica los datos** mediante *replica sets* para tolerar fallos.  
3. **Ejecuta transacciones distribuidas** (concepto de *Two-Phase Commit, 2PC*) garantizando que:
   * o se realizan todos los cambios en todos los nodos implicados,
   * o no se aplica ningún cambio.

> 💡**Nota:** Compass permite ejecutar consultas `find` y `aggregate` con interfaz gráfica.  
> Para comandos administrativos (por ejemplo `sh.status()` o `replSetGetStatus`) y para scripts (transacciones), usaremos el **mongosh integrado** de Compass (“Open MongoDB Shell”).

## Escenario de negocio

Trabajamos con un **sistema bancario distribuido**:

* Las **cuentas** están repartidas por región:
  * `EU` (Europa)
  * `AM` (América)
* Cada región se almacena en un **shard distinto**.
* Cada shard está respaldado por un **replica set**.
* Las **transferencias entre regiones** implican **más de un shard**.

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
   mongodb://localhost:27017
   ```

4. Haz clic en **Connect**

**Aspectos relevantes a observar**

* Aparece la base de datos `bank`
* Existen al menos dos colecciones:
  * `accounts`
  * `transfers`

## 2. Fragmentación horizontal (Sharding)

### 2.1 Comprobar que la colección está fragmentada (desde Compass)

Compass no muestra el estado de sharding en un panel dedicado; lo verificaremos con el **mongosh integrado**.

1. En Compass, con la conexión abierta, pulsa **Open MongoDB Shell** (o “Mongosh” en la barra superior).
2. Ejecuta el siguiente comando:

    ```javascript
    sh.status()
    ```

**Qué hace esta consulta**

* Muestra el estado de los _shards_ del cluster.
  * qué shards existen,
  * qué colecciones están fragmentadas,
  * qué clave de fragmentación se usa,
  * y (si aplica) zonas/rangos.

**Aspectos relevantes a observar**

* Existen dos shards (`shardEU`, `shardAM`).
* La colección `bank.accounts` está fragmentada.
* La clave de fragmentación incluye el campo `region`.

### 2.2 Contar cuentas por región utilizando Compass

1. En Compass, entra a **bank → accounts**
2. Ve a la pestaña **Documents**

#### 2.2.1 Contar total (sin filtro)

* En **Documents**, deja el filtro vacío y observa el contador/estimación (según configuración de Compass).

#### 2.2.2 Contar EU y AM (con filtro)

En el cuadro **Filter**, pega los siguientes comandos, uno a la vez:

**EU**

```javascript
{ region: "EU" }
```

**AM**

```javascript
{ region: "AM" }
```

**Qué hace esta consulta**

* Filtra documentos por región.

**Aspectos relevantes a observar**

* EU + AM ≈ total
* Los datos están organizados por `region`, lo cual es coherente con la fragmentación.

### 2.3 Ver “dónde viven” físicamente los datos (conexiones directas en Compass)

> 💡**Nota:** Esta parte es clave: un cluster con shards se consulta “normalmente” utilizando `mongos`.  
> Para **ver la distribución física**, conectaremos Compass directamente a cada shard.

#### 2.3.1 Conectar Compass al shard EU

1. Compass → **New Connection**
2. Connection string:

    ```text
    mongodb://localhost:27018/?directConnection=true
    ```

3. Connect
4. Abre `bank → accounts` y en **Filter** prueba lo siguiente:

    ```javascript
    { region: "EU" }
    ```

    y luego:

    ```javascript
    { region: "AM" }
    ```

**Aspectos relevantes a observar**

* El shard EU debería contener **principalmente** documentos de `region: "EU"`.

#### 2.3.2 Conectar Compass al shard AM

1. Compass → **New Connection**
2. Connection string:

    ```text
    mongodb://localhost:27020?directConnection=true
    ```

3. Connect
4. Abre `bank → accounts` y filtra por `AM` y por `EU`, igual que antes.

**Aspectos relevantes a observar**

* El shard AM debería contener **principalmente** documentos de `region: "AM"`.

**Idea clave**

* Consultar vía `mongos` da la **vista global**.
* Consultar un shard directo muestra la **vista local/física**.

## 3. Replicación (Replica Sets)

### 3.1 Comprobar que cada shard es un replica set (desde Compass → mongosh)

En Compass (conectado a `mongos`), abre **Open MongoDB Shell** y ejecuta:

```javascript
sh.status()
```

**Aspectos relevantes a observar**

* Para cada shard, aparece un nombre de replica set (por ejemplo `shardEU/...`, `shardAM/...`).
* Un shard es un **conjunto replicado**, no un nodo único.

### 3.2 Estado del replica set (replSetGetStatus) usando mongosh integrado

Esta consulta es administrativa, así que se ejecuta en **Open MongoDB Shell** de Compass.

> 💡**Nota:** Si tu configuración tiene 1 nodo por shard (modo “aula”), verás un único miembro.  
> Si tiene 3 nodos por shard (modo “realista”), verás PRIMARY/SECONDARY.

En **Compass conectado al shard EU** (`mongodb://localhost:27018`), abre **Open MongoDB Shell** y ejecuta:

```javascript
db.adminCommand({ replSetGetStatus: 1 })
```

Repite lo mismo en el shard AM (`mongodb://localhost:27020`).

**Qué hace esta consulta**

* Devuelve el estado del replica set: miembros, roles, salud y elección.

**Aspectos relevantes a observar**

* Existe un **PRIMARY** (si hay más de un miembro)
* Pueden existir **SECONDARY**
* El PRIMARY es el que acepta escrituras

**Idea clave**

> 💡**Nota:** La replicación permite sobrevivir a fallos: si cae un nodo, otro puede asumir el rol de PRIMARY (cuando hay ≥3 nodos).

## 4. Transacciones distribuidas (2PC conceptual) — todo o nada

> 💡**Nota:** Compass no ofrece un “botón” para transacciones multi-operación en la UI.  
> La forma correcta (y replicable por alumnos) es ejecutar el script en **Open MongoDB Shell** de Compass conectado a `mongos`.

### 4.1 Seleccionar cuentas EU y AM (desde Compass → mongosh)

En Compass conectado a `mongodb://localhost:27017` (mongos), abre **Open MongoDB Shell** desde la base de datos `bank` y ejecuta:

```javascript
{
  const bank = db.getSiblingDB("bank");

  const fromEU = bank.accounts.findOne(
    { region: "EU" },
    { _id: 0, accountId: 1, balance: 1, region: 1 }
  );

  const toAM = bank.accounts.findOne(
    { region: "AM" },
    { _id: 0, accountId: 1, balance: 1, region: 1 }
  );

  print("Cuenta origen (EU):");
  printjson(fromEU);

  print("Cuenta destino (AM):");
  printjson(toAM);
}
```

**Aspectos relevantes a observar**

* Son regiones distintas (`EU` y `AM`)
* Es una transferencia **cross-shard**

### 4.2 Ejecutar una transferencia distribuida (COMMIT) desde Open MongoDB Shell

En el mismo mongosh integrado (conectado a la base de datos `bank` de `mongos`):

```javascript
{
  const amount = 50;
  const bank = db.getSiblingDB("bank");

  const fromEU = bank.accounts.findOne({ region: "EU" });
  const toAM   = bank.accounts.findOne({ region: "AM" });

  const session = db.getMongo().startSession();
  const sdb = session.getDatabase("bank");

  try {
    session.startTransaction();

    const debit = sdb.accounts.updateOne(
      { accountId: fromEU.accountId, balance: { $gte: amount } },
      { $inc: { balance: -amount } }
    );
    if (debit.matchedCount !== 1) throw new Error("Saldo insuficiente (origen).");

    const credit = sdb.accounts.updateOne(
      { accountId: toAM.accountId },
      { $inc: { balance: amount } }
    );
    if (credit.matchedCount !== 1) throw new Error("Destino no existe.");

    sdb.transfers.insertOne({
      ts: new Date(),
      from: fromEU.accountId,
      to: toAM.accountId,
      amount,
      status: "COMMITTED_DEMO"
    });

    session.commitTransaction();
    print("TRANSFERENCIA CONFIRMADA");
  } catch (e) {
    session.abortTransaction();
    print("TRANSFERENCIA ABORTADA: " + e.message);
  } finally {
    session.endSession();
  }
}
```

**Qué hace este bloque**

* Inicia una transacción
* Debita una cuenta EU (shard EU)
* Acredita una cuenta AM (shard AM)
* Inserta auditoría en `transfers`
* Confirma de forma atómica

**Aspectos relevantes a observar**

* Se confirma “todo o nada”
* Aunque participan varios shards, el resultado es consistente (2PC conceptual)

### 4.3 Verificar el resultado (con Compass UI)

#### 4.3.1 Ver balances (Documents → accounts)

En Compass conectado a `mongodb://localhost:27017` (mongos), abre **Open MongoDB Shell** desde la base de datos `bank` y ejecuta:

```javascript
{
  const bank = db.getSiblingDB("bank");

  const fromEU = bank.accounts.findOne({ region: "EU" }, { _id: 0, accountId: 1 });
  const toAM   = bank.accounts.findOne({ region: "AM" }, { _id: 0, accountId: 1 });

  const docs = bank.accounts.find(
    { accountId: { $in: [fromEU.accountId, toAM.accountId] } },
    { _id: 0, accountId: 1, region: 1, balance: 1 }
  ).toArray();

  printjson(docs);
}
```

**Aspectos relevantes a observar**

* La cuenta EU bajó `amount`
* La cuenta AM subió `amount`

#### 4.3.2 Ver transferencia (Documents → transfers)

En `bank → transfers`, filtra:

```javascript
{ status: "COMMITTED_DEMO" }
```

**Aspectos relevantes a observar**

* Existe un documento con `status: "COMMITTED_DEMO"`
* Una transferencia cross-shard se registra igual que cualquier otra
* El estado `COMMITTED_DEMO` facilita rastreo didáctico

### 4.4 Forzar un ABORT (fallo controlado) y comprobar que no hay cambios

En **Open MongoDB Shell** (mongos - mongodb://localhost:27017), ejecuta el siguiente bloque:

```javascript
{
  const amountFail = 999999;
  const bank = db.getSiblingDB("bank");

  const fromEU = bank.accounts.findOne({ region: "EU" });
  const toAM   = bank.accounts.findOne({ region: "AM" });

  const session2 = db.getMongo().startSession();
  const sdb2 = session2.getDatabase("bank");

  try {
    session2.startTransaction();

    const debit = sdb2.accounts.updateOne(
      { accountId: fromEU.accountId, balance: { $gte: amountFail } },
      { $inc: { balance: -amountFail } }
    );
    if (debit.matchedCount !== 1) throw new Error("Saldo insuficiente (origen).");

    sdb2.accounts.updateOne(
      { accountId: toAM.accountId },
      { $inc: { balance: amountFail } }
    );

    session2.commitTransaction();
    print("COMMIT (no debería ocurrir)");
  } catch (e) {
    session2.abortTransaction();
    print("ABORT OK: " + e.message);
  } finally {
    session2.endSession();
  }
}
```

**Aspectos relevantes a observar**

* Debe imprimir `ABORT OK: ...`
* En `accounts`, los balances **no cambian**
* En `transfers`, no aparece una transferencia “exitosa” asociada al intento fallido

## 5. Consultas de análisis (Compass)

### 5.1 Volumen por región (Aggregate pipeline en Compass)

En Compass: `bank → accounts → Aggregations`

Pipeline:

```javascript
[
  { $group: { _id: "$region", cuentas: { $sum: 1 }, saldo: { $sum: "$balance" } } },
  { $sort: { _id: 1 } }
]
```

**Qué hace esta consulta**

* Agrupa cuentas por región y calcula:
  * número de cuentas
  * suma de saldos

**Aspectos relevantes a observar**

* Cada región puede crecer de forma independiente (escala horizontal)

## 6. Ideas clave de esta demostración

* **Sharding**: escala horizontal dividiendo los datos por una clave (aquí `region`).
* **Replica sets**: disponibilidad y durabilidad; el PRIMARY acepta escrituras.
* **Transacciones distribuidas (2PC conceptual)**: atomicidad entre shards: **todo o nada**.
* En la práctica:
  * Compass UI se utiliza para `find` y `aggregate`
  * **Open MongoDB Shell** de Compass se emplea para comandos admin y transacciones
