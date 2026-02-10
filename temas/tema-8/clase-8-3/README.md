# Guía Didáctica Tema 8 - Clase 3: Tu primer grafo en Neo4j

## Objetivo

Al finalizar, serás capaz de:

* Importar datos desde CSV con `LOAD CSV WITH HEADERS`.
* Crear nodos y relaciones desde un dataset.
* Navegar y **visualizar** el grafo en Neo4j Browser.
* Ejecutar consultas con `MATCH`, `RETURN`, `WHERE` y una agregación simple.

## Reset (opcional, recomendado para repetir la práctica)

```cypher
MATCH (n) DETACH DELETE n;
```

**Qué esperas:** “Deleted X nodes, Y relationships”.
**Utilidad:** repetir la demo sin duplicar datos ni reiniciar el contenedor Docker.

## Definir constraints para IDs (Recomendado)

Este paso ayuda a mantener el grafo consistente y acelera los `MATCH` por id.

```cypher
CREATE CONSTRAINT movie_id_unique IF NOT EXISTS
FOR (m:Movie) REQUIRE m.id IS UNIQUE;

CREATE CONSTRAINT person_id_unique IF NOT EXISTS
FOR (p:Person) REQUIRE p.id IS UNIQUE;
```

## Importar los nodos (películas y personas)

### Películas → nodos `:Movie`

Basado en el enfoque de cargar un fichero CSV: `LOAD CSV WITH HEADERS` + `CREATE`, ejecuta el siguiente código:

```cypher
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
CREATE (:Movie {
  id: toInteger(row.movieId),
  title: row.title,
  year: toInteger(row.year)
});
```

**Qué esperas:** “Created … nodes”.
**Utilidad:** los nodos representan entidades (`:Movie`).

### Personas → nodos `:Person`

```cypher
LOAD CSV WITH HEADERS FROM 'file:///actors.csv' AS row
CREATE (:Person {
  id: toInteger(row.personId),
  name: row.name,
  born: toInteger(row.born)
});
```

**Qué esperas:** “Created … nodes”.

### Importar las relaciones (roles de los actores)

El *Movie Graph* conecta `:Person` con `:Movie` mediante la relación `:ACTED_IN`.

```cypher
LOAD CSV WITH HEADERS FROM 'file:///roles.csv' AS row
MATCH (p:Person {id: toInteger(row.personId)})
MATCH (m:Movie  {id: toInteger(row.movieId)})
CREATE (p)-[:ACTED_IN {role: row.role}]->(m);
```

**Qué esperas:** “Created … relationships”.
**Utilidad didáctica clave:** `role` (Neo, Trinity…) es una **propiedad de la relación**, porque describe el vínculo “persona actúa en película”, no a la persona ni a la película.

## Visualiza tu primer grafo

Neo4j Browser dibuja grafos cuando devuelves nodos/relaciones (no solo columnas).

### Visualización directa (persona → películas)

Ejemplo con `MATCH` + `RETURN`:

```cypher
MATCH (p:Person {name:"Tom Hanks"})-[:ACTED_IN]->(m:Movie)
RETURN p, m;
```

**Qué esperas ver:**

* Un nodo `Tom Hanks`
* Varias películas conectadas por flechas `ACTED_IN`

**Utilidad:**

* Entender que Cypher “describe patrones” (como un diagrama) y el Browser los renderiza.

#### Tip de navegación en Browser

* Haz click en un nodo para ver sus propiedades.
* Expande relaciones desde el nodo para “descubrir” subgrafos (exploración interactiva).

## Consultas básicas (MATCH + RETURN + WHERE)

En este tema, se enfatiza el patrón: `MATCH` define, `RETURN` muestra y `WHERE` filtra.

### Listado tabular (título y año)

```cypher
MATCH (p:Person {name:"Tom Hanks"})-[:ACTED_IN]->(m:Movie)
RETURN m.title, m.year
ORDER BY m.year;
```

**Qué esperas:** tabla con títulos/años.

### Añadir un filtro con WHERE

```cypher
MATCH (m:Movie)
WHERE m.year >= 2000
RETURN m.title, m.year
ORDER BY m.year;
```

**Qué esperas:** solo películas desde 2000.

### Ver el “rol” (propiedad de relación)

```cypher
MATCH (p:Person)-[r:ACTED_IN]->(m:Movie {title:"The Matrix"})
RETURN p.name, r.role
ORDER BY p.name;
```

**Qué esperas:** nombres de actores y su personaje (`r.role`).

## Un primer insight: agregación y colaboración

Este tema, menciona agregaciones (`COUNT`, `COLLECT`) y patrones de colaboración.

### ¿Cuántas películas por actor?

```cypher
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
RETURN p.name AS actor, count(m) AS num_peliculas
ORDER BY num_peliculas DESC, actor;
```

### “Patrón de amistad” (co-actuación)

```cypher
MATCH (a:Person)-[:ACTED_IN]->(m:Movie)<-[:ACTED_IN]-(b:Person)
WHERE id(a) < id(b)
RETURN a.name, b.name, collect(m.title) AS peliculas_en_comun;
```

**Qué esperas:** pares de actores con listado de películas compartidas.
