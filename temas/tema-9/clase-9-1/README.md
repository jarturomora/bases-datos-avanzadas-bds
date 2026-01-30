# Guía Didáctica Tema 9 - Clase 1: Modelo de propiedad etiquetada

## Objetivos de aprendizaje

Al terminar, podrás:

* Ver y **visualizar** un subgrafo real en Neo4j Browser.
* Entender (de verdad) la diferencia entre **propiedades en nodos** y **propiedades en relaciones**.
* Usar **etiquetas múltiples** (multi-label) para clasificar nodos sin duplicarlos.
* Proteger tu grafo con **constraints de unicidad** y acelerar búsquedas con **índices**.

> **Requisito indispensable:** Ya debes haber importado los CSV (`persons`, `companies`, `groups`, `courses` + relaciones) en Neo4j. Si aún no lo has echo, sigue las instrucciones de [este documento.](../../../docker/tema-9/docker-tema-9-1/data/carga_datos.md)

## Antes de empezar

1. Abre Neo4j Browser: `http://localhost:7474`
2. Inicia sesión.
3. Ejecuta los comandos que se presentan en cada sección (puedes copiar/pegar).

## 1) Ver tu primer subgrafo (visualización en Browser)

Ahora vamos a pedir a Neo4j un trozo del grafo para que el Browser lo dibuje.

```cypher
MATCH (p:Person)-[w:WORKS_AT]->(co:Company)
WHERE w.isCurrent = true
WITH p, co LIMIT 1
OPTIONAL MATCH (p)-[:MEMBER_OF]->(g:Group)
OPTIONAL MATCH (p)-[:ENROLLED_IN]->(c:Course)
RETURN p, co, g, c;
```

**Qué deberías ver:**

* Un nodo **Person**
* Una relación **WORKS_AT** hacia una **Company**
* Y además (si existen) **Group** y **Course** conectados a esa persona

**Para qué sirve:**

* Aprendes a “leer” el grafo visualmente: entidades (nodos) y conexiones (relaciones).

## 2) Entender propiedades: nodos vs. relaciones

### 2.1 Propiedades en nodos (aspectos “propios” de la entidad)

Esto pide campos que pertenecen a una persona:

```cypher
MATCH (p:Person)
RETURN p.name, p.location, p.industry
LIMIT 10;
```

**Qué estás viendo:** propiedades del nodo `Person`.

### 2.2 Propiedades en relaciones (contexto del vínculo)

En un empleo, el **cargo** y las **fechas** pertenecen a la relación de “trabajar en”, no al nodo persona.

```cypher
MATCH (p:Person)-[w:WORKS_AT]->(c:Company)
WHERE w.isCurrent = true
RETURN p.name, w.title, w.startYear, c.name
LIMIT 10;
```

**Idea clave:**

* `p.name` está en el **nodo Person**
* `c.name` está en el **nodo Company**
* `w.title` y `w.startYear` están en la **relación WORKS_AT** (porque describen ese vínculo)

## 3) Etiquetas múltiples: una persona puede tener “roles”

Neo4j permite que un nodo tenga **más de una etiqueta**. Vamos a usarlo para crear “subconjuntos” de personas.

### 3.1 Marcar como `:Employee` a personas con empleo actual

```cypher
MATCH (p:Person)-[w:WORKS_AT]->(:Company)
WHERE w.isCurrent = true
WITH p LIMIT 50
SET p:Employee
RETURN count(p) AS etiquetados_como_employee;
```

**Qué deberías ver:** un número (hasta 50).
**Para qué sirve:** ahora puedes consultar solo empleados usando `MATCH (e:Employee)`.

### 3.2 Marcar algunos empleados como `:Recruiter`

Vamos a etiquetar como `Recruiter` a gente cuyo `headline` tenga “Sales” o “Manager”.

```cypher
MATCH (p:Employee)
WHERE p.headline CONTAINS "Sales" OR p.headline CONTAINS "Manager"
WITH p LIMIT 30
SET p:Recruiter
RETURN count(p) AS etiquetados_como_recruiter;
```

**Qué deberías ver:** un número entre 0 y 30.
**Si sale 0:** no pasa nada; significa que en ese subconjunto no había coincidencias.

### 3.3 Comprobar la “jerarquía” de etiquetas

```cypher
MATCH (p:Person) RETURN count(p) AS total_personas;
```

```cypher
MATCH (e:Employee) RETURN count(e) AS total_empleados;
```

```cypher
MATCH (r:Recruiter) RETURN count(r) AS total_recruiters;
```

**Qué debería cumplirse:**
`Recruiter ≤ Employee ≤ Person`

**Para qué sirve:** etiquetar es una forma rápida de clasificar sin duplicar datos.

## 4) Constraints de unicidad: evitar duplicados

Neo4j es flexible, pero tú puedes imponer reglas para que el grafo sea consistente.

### 4.1 Crear constraints

```cypher
CREATE CONSTRAINT person_unique IF NOT EXISTS
FOR (p:Person) REQUIRE p.personId IS UNIQUE;

CREATE CONSTRAINT company_unique IF NOT EXISTS
FOR (c:Company) REQUIRE c.companyId IS UNIQUE;
```

**Qué deberías ver:** “created” o “already exists”.

### 4.2 Probar que funciona (esto debe fallar)

Ejecuta esto para ver el error (es parte del aprendizaje):

```cypher
CREATE (:Person {personId: 1, name: "Duplicado", location:"Madrid"});
```

**Qué deberías ver:** un error por violación de unicidad.
**Para qué sirve:** evitar duplicar personas si importas CSV dos veces por accidente.

## 5) Índices: acelerar búsquedas por propiedades

Los índices ayudan cuando buscas mucho por una propiedad (nombre, ciudad, etc.).

### 5.1 Crear índices útiles

```cypher
CREATE INDEX person_name IF NOT EXISTS FOR (p:Person) ON (p.name);
CREATE INDEX person_location IF NOT EXISTS FOR (p:Person) ON (p.location);
CREATE INDEX company_name IF NOT EXISTS FOR (c:Company) ON (c.name);
CREATE INDEX group_topic IF NOT EXISTS FOR (g:Group) ON (g.topic);
CREATE INDEX course_tag IF NOT EXISTS FOR (c:Course) ON (c.tag);
```

### 5.2 Probar una búsqueda típica

```cypher
MATCH (p:Person {location:"Madrid"})
RETURN p.name, p.headline, p.industry
LIMIT 25;
```

**Si Madrid te devuelve 0**, prueba otra ciudad que te suene: `"Barcelona"`, `"Valencia"`, `"Sevilla"`.

## 6) Mini-caso final (tipo LinkedIn)

Encuentra empleados “openToWork” en una ciudad y su empresa actual.

```cypher
MATCH (p:Employee)-[w:WORKS_AT]->(c:Company)
WHERE w.isCurrent = true AND p.openToWork = true AND p.location = "Madrid"
RETURN p.name, p.headline, c.name AS empresa, w.title AS puesto
LIMIT 25;
```

**Qué estás haciendo:** un caso real de búsqueda de candidatos.

**Si Madrid te devuelve 0**, prueba otra ciudad que te suene: `"Barcelona"`, `"Valencia"`, `"Sevilla"`
