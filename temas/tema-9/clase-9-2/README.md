# Guía Didáctica Tema 9 - Clase 2: Gestión de nodos y relaciones complejas

## Objetivos

* Usar **`MERGE`** para crear/reutilizar nodos y relaciones **sin duplicados** en la red profesional.
* Aplicar **`UNWIND`** para **inserciones masivas** (personas y conexiones) de forma controlada.
* Trabajar con **relaciones con propiedades** (empleo, conexión, formación) y entender su utilidad.
* Explorar la red con **rutas de longitud variable** (`*1..n`) y **visualizar caminos** (`RETURN path`).
* Medir y optimizar consultas con **`EXPLAIN`/`PROFILE`** y construir una **recomendación** basada en contactos.

## Requisitos

Ya debes haber importado los CSV (`persons`, `companies`, `groups`, `courses` + relaciones) en Neo4j. Si aún no lo has echo, sigue las instrucciones de [este documento.](../../../docker/tema-9/docker-tema-9-2/data/carga_datos.md)

## 1) Evitar duplicados con `MERGE`

**Idea:** `MERGE` combina “buscar o crear”. Si existe, no duplica; si no existe, crea.

### 1.1 Crear (o reutilizar) una persona “demo”

```cypher
MERGE (p:Person {personId: 999999})
ON CREATE SET
  p.name = "Ana Demo",
  p.headline = "Data Engineer",
  p.location = "Madrid",
  p.industry = "Software",
  p.yearsExp = 5,
  p.openToWork = true,
  p.creado = timestamp()
ON MATCH SET
  p.actualizado = timestamp()
RETURN p;
```

**Qué observar:**

* La primera vez verás `creado`.
* Si lo ejecutas otra vez, verás `actualizado` (sin crear otro nodo).

### 1.2 `MERGE` también sirve para relaciones (sin duplicarlas)

```cypher
// Elegimos una empresa cualquiera
MATCH (c:Company)
WITH c LIMIT 1
MERGE (p:Person {personId: 999999})
MERGE (p)-[w:WORKS_AT]->(c)
ON CREATE SET w.title="Demo Role", w.startYear=2026, w.isCurrent=true
ON MATCH SET w.actualizado = timestamp()
RETURN p, w, c;
```

**Qué observar:** si repites el comando, no crea otra relación `WORKS_AT` igual.

## 2) Creación masiva con `UNWIND` + `MERGE`

**Idea:** `UNWIND` convierte una lista en “filas” para procesarlas en bloque (como un mini-CSV dentro de Cypher).

### 2.1 Crear 5 personas de golpe (sin duplicados)

```cypher
UNWIND [
  {id: 900001, name:"Luis Demo",  location:"Barcelona", industry:"AI", open:true},
  {id: 900002, name:"Marta Demo", location:"Madrid",    industry:"FinTech", open:false},
  {id: 900003, name:"Sofía Demo", location:"Valencia",  industry:"Cybersecurity", open:true},
  {id: 900004, name:"Pablo Demo", location:"Sevilla",   industry:"Consulting", open:false},
  {id: 900005, name:"Elena Demo", location:"Bilbao",    industry:"Software", open:true}
] AS row
MERGE (p:Person {personId: row.id})
SET p.name = row.name,
    p.location = row.location,
    p.industry = row.industry,
    p.openToWork = row.open
RETURN count(p) AS procesadas;
```

**Qué observar:** puedes ejecutarlo varias veces sin duplicar nodos.

### 2.2 Crear relaciones en bloque (conexiones profesionales)

```cypher
UNWIND [
  {a: 999999, b: 900001, since: 2022, strength:"strong"},
  {a: 999999, b: 900002, since: 2023, strength:"normal"},
  {a: 999999, b: 900003, since: 2024, strength:"weak"},
  {a: 900001, b: 900004, since: 2021, strength:"normal"},
  {a: 900002, b: 900005, since: 2020, strength:"strong"}
] AS rel
MATCH (p1:Person {personId: rel.a})
MATCH (p2:Person {personId: rel.b})
MERGE (p1)-[r:CONNECTED_TO]->(p2)
SET r.sinceYear = rel.since,
    r.strength = rel.strength
RETURN count(r) AS relaciones_creadas_o_actualizadas;
```

**Qué observar:** `MERGE` evita repetir la misma conexión dirigida.

## 3) Actualizaciones en cascada (controladas)

**Idea:** modificar una entidad y “propagar” un cambio a nodos relacionados, con filtros para no afectar todo el grafo.

### 3.1 Marcar una empresa y “actualizar” el perfil de sus empleados actuales

```cypher
// Elegimos una empresa con empleados actuales (si no sale nada, repite con otra)
MATCH (c:Company)<-[w:WORKS_AT]-(p:Person)
WHERE w.isCurrent = true
WITH c, collect(p)[0..25] AS empleados
SET c.country = "ES"
FOREACH (e IN empleados | SET e.headline = coalesce(e.headline,"") + " | (Empleado activo)")
RETURN c.name AS empresa, size(empleados) AS empleados_actualizados;
```

**Qué observar:**

* Cambia `c.country`
* Cambia el `headline` de un subconjunto acotado de empleados (máx 25) para no “romper” rendimiento.

> En una demo real, el “cascading update” debe estar acotado (por filtros y límites), justo como indica el tema.

## 4) Rutas de longitud variable (redes sociales)

**Idea:** explorar conexiones indirectas hasta una profundidad controlada usando `*`.

### 4.1 Contactos de 1 a 3 saltos (1º, 2º y 3º grado)

Primero elige una persona “semilla” real (con conexiones):

```cypher
MATCH (p:Person)-[:CONNECTED_TO]->()
RETURN p.personId, p.name
LIMIT 5;
```

Copia un `personId` de los resultados y úsalo aquí (ejemplo con 1):

```cypher
MATCH (a:Person {personId: 1})-[:CONNECTED_TO*1..3]-(b:Person)
RETURN DISTINCT b.personId, b.name, b.location
LIMIT 50;
```

**Qué observar:** aparecen personas conectadas directa o indirectamente (hasta 3 niveles).

### 4.2 Visualizar el camino (para que Browser lo dibuje)

```cypher
MATCH path = (a:Person {personId: 1})-[:CONNECTED_TO*1..3]-(b:Person)
RETURN path
LIMIT 25;
```

## 5) Optimización: `EXPLAIN` y `PROFILE`

**Idea:** entender el coste de las consultas y por qué conviene limitar profundidad y usar índices.

### 5.1 Ver plan sin ejecutar (EXPLAIN)

```cypher
EXPLAIN
MATCH (a:Person {personId: 1})-[:CONNECTED_TO*1..4]-(b:Person)
RETURN count(DISTINCT b);
```

### 5.2 Ejecutar y medir (PROFILE)

```cypher
PROFILE
MATCH (a:Person {personId: 1})-[:CONNECTED_TO*1..4]-(b:Person)
RETURN count(DISTINCT b);
```

**Qué observar en Browser:**

* Operadores del plan y “db hits”
* Cómo cambia el coste si subes la profundidad (`*1..2` vs `*1..4`)

> Mensaje clave del tema: las rutas variables crecen rápido; controla la profundidad y apóyate en índices/constraints.

## 6) Mini reto final (aplicando todo)

**Objetivo:** recomendar cursos “cerca” de tu red.

> “Dame cursos en los que están inscritos mis contactos de hasta 2 saltos, y que yo aún no haya hecho.”

(Usa `personId: 1` o el que elegiste antes)

```cypher
MATCH (me:Person {personId: 1})
MATCH (me)-[:CONNECTED_TO*1..2]-(other:Person)-[:ENROLLED_IN]->(c:Course)
WHERE NOT (me)-[:ENROLLED_IN]->(c)
RETURN c.title AS curso, c.provider AS proveedor, count(DISTINCT other) AS personas_que_lo_hacen
ORDER BY personas_que_lo_hacen DESC
LIMIT 10;
```

**Qué demuestra:**

* Rutas variables
* Filtro anti-duplicados (`DISTINCT`)
* Caso de uso real (recomendación) con un patrón de grafo
