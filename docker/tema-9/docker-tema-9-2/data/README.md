# Dataset “Red Profesional” (Neo4j) — Estructura y ficheros CSV

## 1) Idea general del modelo

Vamos a construir un grafo que representa una **red social profesional** (estilo LinkedIn) con cuatro tipos de entidades principales:

* **Personas** (perfiles profesionales)
* **Empresas** (organizaciones)
* **Grupos** (comunidades temáticas)
* **Cursos** (formación / upskilling)

En un grafo, las **entidades** se modelan como **nodos** y las **interacciones** (trabajar en una empresa, pertenecer a un grupo, conectarse con alguien…) se modelan como **relaciones**.

En las siguientes secciones se explica con detalle la estructura de los ficheros CSV que se utilizan para generar la base datos. La carga de los ficheros, se presenta en [este documento](carga_datos.md).

## 2) Ficheros CSV de nodos (crean entidades)

### `persons.csv` → nodos `:Person`

Cada fila es una persona (un “perfil”).

**Columnas principales**

* `personId` (entero): identificador único
* `name` (texto): nombre completo
* `headline` (texto): titular profesional (ej. “Data Engineer”)
* `location` (texto): ciudad/ubicación
* `industry` (texto): sector
* `yearsExp` (entero): años de experiencia
* `openToWork` (boolean): disponibilidad para trabajar (true/false)

**Se convierte en**

* `(:Person {personId, name, headline, location, industry, yearsExp, openToWork})`

### `companies.csv` → nodos `:Company`

Cada fila es una empresa.

**Columnas principales**

* `companyId` (entero): identificador único
* `name` (texto): nombre de empresa
* `industry` (texto): sector
* `hqCity` (texto): ciudad de sede
* `country` (texto): país (código tipo ES, PT…)
* `size` (texto): rango de tamaño (1-10, 11-50, …)

**Se convierte en**

* `(:Company {companyId, name, industry, hqCity, country, size})`

### `groups.csv` → nodos `:Group`

Cada fila es un grupo/comunidad.

**Columnas principales**

* `groupId` (entero): identificador único
* `name` (texto): nombre del grupo
* `topic` (texto): temática (ej. “Cybersecurity”, “AI & ML”)
* `language` (texto): idioma (es/en)
* `createdYear` (entero): año de creación
* `isPublic` (boolean): si es público o no

**Se convierte en**

* `(:Group {groupId, name, topic, language, createdYear, isPublic})`

### `courses.csv` → nodos `:Course`

Cada fila es un curso.

**Columnas principales**

* `courseId` (entero): identificador único
* `title` (texto): título del curso
* `provider` (texto): proveedor (UNIPRO Academy, Coursera…)
* `level` (texto): nivel (Beginner/Intermediate/Advanced)
* `hours` (entero): duración aproximada
* `tag` (texto): etiqueta técnica (para búsquedas)

**Se convierte en**

* `(:Course {courseId, title, provider, level, hours, tag})`

## 3) Ficheros CSV de relaciones (conectan entidades)

Estos CSV **no crean nodos**, sino **enlaces** entre nodos ya existentes usando IDs.

### `works_at.csv` → relaciones `(:Person)-[:WORKS_AT]->(:Company)`

Describe experiencias laborales: “esta persona trabaja/trabajó en esta empresa”.

**Columnas**

* `personId`, `companyId` (claves para conectar)
* `title` (texto): cargo
* `startYear` (entero): inicio
* `endYear` (entero o vacío): fin (vacío = sigue)
* `isCurrent` (boolean): indica si es empleo actual

**Interpretación**

* Propiedades como `title`, `startYear`, `endYear` describen el **vínculo** persona–empresa, no la persona ni la empresa.

### `member_of.csv` → relaciones `(:Person)-[:MEMBER_OF]->(:Group)`

Describe pertenencia a comunidades.

**Columnas**

* `personId`, `groupId`
* `sinceYear` (entero): año desde el que pertenece
* `role` (texto): member/moderator/admin

### `enrolled_in.csv` → relaciones `(:Person)-[:ENROLLED_IN]->(:Course)`

Describe formación: matrícula o progreso en cursos.

**Columnas**

* `personId`, `courseId`
* `enrolledDate` (fecha ISO): fecha de inscripción
* `status` (texto): enrolled / in_progress / completed
* `score` (entero o vacío): nota si está completado

### `connected_to.csv` → relaciones `(:Person)-[:CONNECTED_TO]->(:Person)`

Describe conexiones entre profesionales (red de contactos).

**Columnas**

* `personId1`, `personId2`
* `sinceYear` (entero): año desde la conexión
* `strength` (texto): weak / normal / strong

**Nota importante**

* En el CSV la conexión es “conceptualmente bidireccional”, pero en Neo4j la creamos como una relación dirigida (A→B). En consultas, si quieres tratarla como “no dirigida”, puedes usar el patrón:

  * `-[:CONNECTED_TO]-` (sin flecha) para “en cualquier dirección”.

## 4) Resumen del grafo (cómo se ve el modelo)

Piensa en este “mapa mental”:

* Una persona puede:

  * trabajar en una empresa
    `(:Person)-[:WORKS_AT]->(:Company)`
  * pertenecer a grupos
    `(:Person)-[:MEMBER_OF]->(:Group)`
  * inscribirse en cursos
    `(:Person)-[:ENROLLED_IN]->(:Course)`
  * conectarse con otras personas
    `(:Person)-[:CONNECTED_TO]->(:Person)`

## 5) ¿Por qué algunas propiedades van en relaciones?

En grafos, es muy común que el “detalle” viva en la relación:

* **Cargo, fechas de empleo** → describen *la relación* entre persona y empresa (`WORKS_AT`)
* **Rol en un grupo** → describe *la membresía* (`MEMBER_OF`)
* **Estado/nota de un curso** → describe *la inscripción* (`ENROLLED_IN`)
* **Antigüedad/fuerza de conexión** → describe *la conexión* (`CONNECTED_TO`)

Esto hace el modelo más realista y facilita consultas tipo:

* “Personas con empleo actual en X”
* “Conexiones fuertes en mi sector”
* “Recomendar cursos a gente de una industria”
* “Grupos más populares por ciudad/tema”

## 6) Primeras consultas para “leer” el grafo (muy cortas)

**Ver un perfil con su entorno (subgrafo):**

```cypher
MATCH (p:Person)-[w:WORKS_AT]->(co:Company)
WHERE w.isCurrent = true
WITH p, co LIMIT 1
OPTIONAL MATCH (p)-[:MEMBER_OF]->(g:Group)
OPTIONAL MATCH (p)-[:ENROLLED_IN]->(c:Course)
RETURN p, co, g, c;
```

**Ver conexiones de una persona (en cualquier dirección):**

```cypher
MATCH (p:Person {personId: 1})-[:CONNECTED_TO]-(other:Person)
RETURN p, other
LIMIT 25;
```
