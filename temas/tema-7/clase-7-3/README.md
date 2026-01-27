# Guía didáctica Tema 7 - Clase 3: Monitoreo y Observabilidad con Grafana (_performance tunning_)

## Objetivo de la clase

Al finalizar la demo, el alumno aprenderá cómo:

* Un clúster **sharded** de MongoDB genera métricas observables.
* **Prometheus** recolecta métricas del **MongoDB Exporter**.
* **Grafana** visualiza métricas y permite construir paneles útiles.
* Se provoca carga “controlada” desde **MongoDB Compass** para ver cambios inmediatos en dashboards.

## Prerrequisitos

* Docker y Docker Compose instalados
* MongoDB Compass instalado
* Navegador web

## Arranque del entorno

Desde la carpeta del proyecto (donde está `docker-compose.yml`):

```bash
docker compose up -d
```

Verificación rápida:

```bash
docker compose ps
```

Se espera ver `prometheus` y `grafana` en estado `Up`, además de `mongos` y los nodos de shards/config.

## Accesos y credenciales

### MongoDB (Compass)

Conectar a:

* **URI**: `mongodb://localhost:27017`

> Se está conectando a `mongos` (router), que es el punto de entrada recomendado para un cluster sharded.

### Prometheus

Abrir en el navegador:

* `http://localhost:9090`

### Grafana

Abrir en el navegador:

* `http://localhost:3000`

Credenciales (por defecto en el compose):

* **usuario**: `admin`
* **password**: `admin.`

## Validación rápida de métricas (profesor)

### Prometheus: ¿hay scraping?

En Prometheus → pestaña **Graph** (o “Expression”):

Ejecutar:

```promql
up
```

Buscar específicamente el exporter:

```promql
up{job="mongodb_exporter"}
```

Resultado esperado: valor `1`.

### Confirmar que existe teleco_es en métricas

Ejecutar:

```promql
mongodb_dbstats_objects
```

Debe aparecer una serie con label:

* `database="teleco_es"`

## Grafana: Dashboard listo y con datos

En Grafana:

1. Ir a **Dashboards**
2. Abrir: **MongoDB Teleco ES - Demo Clase 3 (Teleco DBStats)** (o el nombre equivalente que estés usando)

Paneles típicos que se verán:

* Documents (objects) en `teleco_es`
* dataSize
* indexSize
* totalSize
* collections
* dbstats_ok

> Si algún panel sale “No data”, revisar que el panel esté usando el datasource **Prometheus**.

## Demo interactiva: generar datos desde Compass

### Concepto clave

En esta demo, la “carga” no se genera con un script masivo. Se produce desde Compass con acciones sencillas (insertar, crear colección, crear índice). Esto hace visibles cambios en métricas como:

* `objects` (número de documentos)
* `dataSize` (tamaño de datos)
* `indexSize` (tamaño de índices)
* `collections` (número de colecciones)

## Parte A — Inserts: hacer crecer documents y dataSize

### En Compass

1. Conectar a `mongodb://localhost:27017`
2. Ir a la base de datos `teleco_es`
3. Crear (si no existe) la colección: `telemetria`

### Insertar documentos (manual, rápido y visible)

En `teleco_es.telemetria` → **Insert Document** y pegar:

```json
{
  "ts": { "$date": "2026-01-01T00:00:00Z" },
  "provincia": "Madrid",
  "evento": "demo_grafana",
  "v": 0.123,
  "n": 1
}
```

Repetir 20–50 veces (duplicar y cambiar `v` o `provincia`).

#### Qué debe observarse en Grafana

* **documents (objects)** sube en pocos segundos.
* **dataSize** sube progresivamente.
* **totalSize** aumenta.

> **Nota:** `dataSize` y `totalSize` no suben “linealmente” a cada insert; hay efectos de asignación interna de almacenamiento.

## Parte B — Colecciones: provocar incremento inmediato en “collections”

### En Compass

1. En `teleco_es` → **Create collection**
2. Nombre: `telemetria_demo_1`
3. Insertar 1 documento cualquiera (por ejemplo):

```json
{ "ok": true, "createdAt": { "$date": "2026-01-01T00:00:00Z" } }
```

#### Qué debe observarse en Grafana

* Panel **collections** sube (normalmente se refleja casi al instante).

## Parte C — Índices: mover indexSize

### En Compass

1. Colección `teleco_es.telemetria`
2. Pestaña **Indexes**
3. **Create Index**
4. Clave: `provincia: 1`

Opcional (recomendado para una demo más realista):

* Crear índice compuesto: `provincia: 1, ts: -1`

#### Qué debe observarse en Grafana

* Panel **indexSize** puede aumentar.
* En algunos entornos el aumento es pequeño al principio; se aprecia mejor con más documentos.

## Parte D — Consultas para generar actividad adicional (sin scripts)

La métrica que más “se siente” visualmente suele ser `objects/dataSize`, pero también interesa generar actividad repetible.

### Filtros (Find) en Compass

En `teleco_es.telemetria` → Filter:

```json
{ "provincia": "Madrid" }
```

Ordenar por `ts` descendente y navegar páginas.

### Aggregation simple (para explicar el valor analítico)

Ir a **Aggregations** y pegar pipeline:

```json
[
  { "$match": { "evento": "demo_grafana" } },
  { "$group": { "_id": "$provincia", "total": { "$sum": 1 } } },
  { "$sort": { "total": -1 } }
]
```

Ejecutar varias veces.

> **Nota:** aunque esto no siempre cambia DBStats, sí sirve para contextualizar “operación de negocio + observabilidad”.

## Guía de resolución de problemas

### “No data” en Grafana

* Confirmar datasource correcto (Prometheus).
* En Prometheus, ejecutar `up{job="mongodb_exporter"}` y validar `1`.
* Confirmar que existe `mongodb_dbstats_objects{database="teleco_es"}`.

### “Los paneles no cambian”

* Aumentar inserciones (50–200 docs).
* Esperar 10–30 segundos (según el `scrape_interval`).
* Confirmar que se inserta en `teleco_es` y no en otra base.

## Conclusiones

Este ejercicio demuestra el ciclo completo:

1. Base de datos operativa (MongoDB sharded)
2. Exposición de métricas (exporter)
3. Recolección (Prometheus)
4. Visualización (Grafana)
5. Generación de actividad controlada desde Compass para observar el comportamiento
