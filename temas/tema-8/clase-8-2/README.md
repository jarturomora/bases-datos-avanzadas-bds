# Guía Didáctica Tema 8 - Clase 2: Mini grafo Personas–Películas (Neo4j + Cypher)

## Objetivos de aprendizaje

1. Ejecutar consultas simples con **MATCH** y **RETURN**.
2. Entender la diferencia entre **propiedades en nodos** y **propiedades en relaciones**.
3. Hacer una recomendación sencilla: “¿qué películas podrían gustarle a una persona?”

## Requisitos previos

* Neo4j levantado (Docker o instalación local).
* Neo4j Browser: `http://localhost:7474`
* Iniciar sesión.

## Limpieza del grafo (opcional)

### Comando

```cypher
MATCH (n) DETACH DELETE n;
```

### ¿Qué hace?

* Encuentra todos los nodos y los elimina junto con sus relaciones.

### ¿Qué se espera ver?

* Un mensaje tipo: *Deleted X nodes, Y relationships*.

### ¿Para qué sirve?

* Empezar desde cero y evitar resultados contaminados por prácticas anteriores.

## Crear datos: nodos (Personas, Películas, Géneros)

Aquí veremos **propiedades en nodos**.

### Comando

```cypher
CREATE
  (ana:Persona {nombre:'Ana', edad:25}),
  (luis:Persona {nombre:'Luis', edad:30}),
  (marta:Persona {nombre:'Marta', edad:28}),

  (matrix:Pelicula {titulo:'The Matrix', anio:1999}),
  (inception:Pelicula {titulo:'Inception', anio:2010}),
  (inter:Pelicula {titulo:'Interstellar', anio:2014}),
  (notebook:Pelicula {titulo:'The Notebook', anio:2004}),

  (sci:Genero {nombre:'Sci-Fi'}),
  (rom:Genero {nombre:'Romance'});
```

### ¿Qué hace?

* Crea nodos con labels (`Persona`, `Pelicula`, `Genero`) y propiedades (`nombre`, `edad`, `titulo`, `anio`).

### ¿Qué se espera ver?

* Confirmación de nodos creados.

### ¿Para qué sirve?

* Modelar entidades del dominio: personas, películas y géneros.

## Crear relaciones (con propiedades en relaciones)

Aquí veremos **propiedades en relaciones**, que guardan contexto (rating, fecha, motivo…).

### Comando

```cypher
MATCH
  (ana:Persona {nombre:'Ana'}),
  (luis:Persona {nombre:'Luis'}),
  (marta:Persona {nombre:'Marta'}),
  (matrix:Pelicula {titulo:'The Matrix'}),
  (inception:Pelicula {titulo:'Inception'}),
  (inter:Pelicula {titulo:'Interstellar'}),
  (notebook:Pelicula {titulo:'The Notebook'}),
  (sci:Genero {nombre:'Sci-Fi'}),
  (rom:Genero {nombre:'Romance'})
CREATE
  // Película -> Género
  (matrix)-[:ES_DE]->(sci),
  (inception)-[:ES_DE]->(sci),
  (inter)-[:ES_DE]->(sci),
  (notebook)-[:ES_DE]->(rom),

  // Persona -> Película (relaciones con propiedades)
  (ana)-[:VIO {fecha:'2026-01-10'}]->(matrix),
  (ana)-[:LE_GUSTA {rating:5, motivo:'Acción + Sci-Fi'}]->(matrix),
  (ana)-[:LE_GUSTA {rating:4}]->(inception),

  (luis)-[:LE_GUSTA {rating:5}]->(inception),
  (luis)-[:LE_GUSTA {rating:4}]->(inter),

  (marta)-[:LE_GUSTA {rating:5}]->(notebook);
```

### ¿Qué hace?

* `MATCH` recupera nodos existentes por sus propiedades.
* `CREATE` crea relaciones entre nodos.
* `[:LE_GUSTA {rating:...}]` crea una relación con propiedades.

### ¿Qué se espera ver?

* Confirmación de relaciones creadas.

### ¿Para qué sirve?

* En grafos, el “vínculo” puede tener datos:

  * “Ana le gusta Matrix con rating 5” → ese `rating` es del **vínculo**, no de la película.

## Consultas básicas con MATCH y RETURN

### Ver todas las personas

```cypher
MATCH (p:Persona)
RETURN p;
```

**Esperas ver:** 3 nodos (Ana, Luis, Marta).
**Utilidad:** listar entidades.

### Ver películas y propiedades (propiedades en nodo)

```cypher
MATCH (m:Pelicula)
RETURN m.titulo, m.anio;
```

**Esperas ver:** 4 filas con título y año.
**Utilidad:** seleccionar campos concretos.

### Ver “a quién le gusta qué” (patrón Persona → Película)

```cypher
MATCH (p:Persona)-[:LE_GUSTA]->(m:Pelicula)
RETURN p.nombre, m.titulo;
```

**Esperas ver:** pares persona–película.
**Utilidad:** consultar patrones (lo típico en grafos).

## Nodos vs relaciones: dónde van las propiedades

### Propiedades “propias” (nodos)

```cypher
MATCH (m:Pelicula)
RETURN m.titulo, m.anio;
```

* `anio` pertenece a la película → propiedad del **nodo**.

### Propiedades “del vínculo” (relación)

```cypher
MATCH (p:Persona {nombre:'Ana'})-[r:LE_GUSTA]->(m:Pelicula)
RETURN p.nombre, m.titulo, r.rating, r.motivo;
```

**Esperas ver:**

* `rating` en todas las relaciones de Ana.
* `motivo` solo en Matrix (porque solo esa relación lo tiene).

**Utilidad:** modelar contexto (fecha, rating, rol, peso, etc.) en la relación.

### Comparación directa en una consulta

```cypher
MATCH (p:Persona {nombre:'Ana'})-[r:LE_GUSTA]->(m:Pelicula)
RETURN m.titulo, m.anio, r.rating;
```

* `m.anio` = propiedad del nodo `Pelicula`
* `r.rating` = propiedad de la relación `LE_GUSTA`

## Recomendación sencilla: “películas que podrían gustarle a Ana”

Regla:

1. Buscar géneros de películas que Ana **LE_GUSTA**.
2. Recomendar otras películas de esos géneros.
3. Excluir películas que Ana ya tiene en **LE_GUSTA**.

### Comando

```cypher
MATCH (ana:Persona {nombre:'Ana'})-[:LE_GUSTA]->(:Pelicula)-[:ES_DE]->(g:Genero)
MATCH (rec:Pelicula)-[:ES_DE]->(g)
WHERE NOT (ana)-[:LE_GUSTA]->(rec)
RETURN DISTINCT rec.titulo AS recomendacion, g.nombre AS por_genero;
```

### ¿Qué se espera ver?

* Para Ana, debería aparecer **Interstellar** como recomendación (es Sci-Fi y Ana no la marcó como `LE_GUSTA`).

### ¿Para qué sirve?

* Es la base de recomendadores por “preferencias compartidas” o “vecindario” en un grafo.
