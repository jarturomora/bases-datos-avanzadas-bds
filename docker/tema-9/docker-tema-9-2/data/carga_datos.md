# Dataset “Red Profesional” (Neo4j) — Carga de datos

## 1) Constraints (recomendado)

```cypher
CREATE CONSTRAINT person_id_unique IF NOT EXISTS
FOR (p:Person) REQUIRE p.personId IS UNIQUE;

CREATE CONSTRAINT company_id_unique IF NOT EXISTS
FOR (c:Company) REQUIRE c.companyId IS UNIQUE;

CREATE CONSTRAINT group_id_unique IF NOT EXISTS
FOR (g:Group) REQUIRE g.groupId IS UNIQUE;

CREATE CONSTRAINT course_id_unique IF NOT EXISTS
FOR (c:Course) REQUIRE c.courseId IS UNIQUE;
```

## 2) Import de nodos

```cypher
// Personas
LOAD CSV WITH HEADERS FROM 'file:///persons.csv' AS row
CREATE (:Person {
  personId: toInteger(row.personId),
  name: row.name,
  headline: row.headline,
  location: row.location,
  industry: row.industry,
  yearsExp: toInteger(row.yearsExp),
  openToWork: toBoolean(row.openToWork)
});

// Empresas
LOAD CSV WITH HEADERS FROM 'file:///companies.csv' AS row
CREATE (:Company {
  companyId: toInteger(row.companyId),
  name: row.name,
  industry: row.industry,
  hqCity: row.hqCity,
  country: row.country,
  size: row.size
});

// Grupos
LOAD CSV WITH HEADERS FROM 'file:///groups.csv' AS row
CREATE (:Group {
  groupId: toInteger(row.groupId),
  name: row.name,
  topic: row.topic,
  language: row.language,
  createdYear: toInteger(row.createdYear),
  isPublic: toBoolean(row.isPublic)
});

// Cursos
LOAD CSV WITH HEADERS FROM 'file:///courses.csv' AS row
CREATE (:Course {
  courseId: toInteger(row.courseId),
  title: row.title,
  provider: row.provider,
  level: row.level,
  hours: toInteger(row.hours),
  tag: row.tag
});
```

## 3) Import de relaciones

```cypher
// WORKS_AT (Persona → Empresa)
LOAD CSV WITH HEADERS FROM 'file:///works_at.csv' AS row
MATCH (p:Person {personId: toInteger(row.personId)})
MATCH (c:Company {companyId: toInteger(row.companyId)})
CREATE (p)-[:WORKS_AT {
  title: row.title,
  startYear: toInteger(row.startYear),
  endYear: CASE WHEN row.endYear = "" THEN NULL ELSE toInteger(row.endYear) END,
  isCurrent: toBoolean(row.isCurrent)
}]->(c);

// MEMBER_OF (Persona → Grupo)
LOAD CSV WITH HEADERS FROM 'file:///member_of.csv' AS row
MATCH (p:Person {personId: toInteger(row.personId)})
MATCH (g:Group {groupId: toInteger(row.groupId)})
CREATE (p)-[:MEMBER_OF {
  sinceYear: toInteger(row.sinceYear),
  role: row.role
}]->(g);

// ENROLLED_IN (Persona → Curso)
LOAD CSV WITH HEADERS FROM 'file:///enrolled_in.csv' AS row
MATCH (p:Person {personId: toInteger(row.personId)})
MATCH (c:Course {courseId: toInteger(row.courseId)})
CREATE (p)-[:ENROLLED_IN {
  enrolledDate: date(row.enrolledDate),
  status: row.status,
  score: CASE WHEN row.score = "" THEN NULL ELSE toInteger(row.score) END
}]->(c);

// CONNECTED_TO (Persona ↔ Persona)
/*
En el CSV viene como pares `personId1`, `personId2`.
Creamos una relación dirigida (en la práctica puedes tratarla como “simétrica”
consultando en ambos sentidos).
*/
LOAD CSV WITH HEADERS FROM 'file:///connected_to.csv' AS row
MATCH (a:Person {personId: toInteger(row.personId1)})
MATCH (b:Person {personId: toInteger(row.personId2)})
CREATE (a)-[:CONNECTED_TO {
  sinceYear: toInteger(row.sinceYear),
  strength: row.strength
}]->(b);
```

## 4) Verificaciones rápidas (sanity checks)

### 4.1 Conteos

```cypher
MATCH (p:Person)  RETURN count(p) AS persons;
```

```cypher
MATCH (c:Company) RETURN count(c) AS companies;
```

```cypher
MATCH (g:Group)   RETURN count(g) AS groups;
```

```cypher
MATCH (c:Course)  RETURN count(c) AS courses;
```

### 4.2 Relaciones

```cypher
MATCH ()-[r:WORKS_AT]->()    RETURN count(r) AS works_at;
```

```cypher
MATCH ()-[r:MEMBER_OF]->()   RETURN count(r) AS member_of;
```

```cypher
MATCH ()-[r:ENROLLED_IN]->() RETURN count(r) AS enrolled_in;
```

```cypher
MATCH ()-[r:CONNECTED_TO]->() RETURN count(r) AS connected_to;
```

## 5) Primera visualización “bonita” para validar la carga de datos

Muestra una persona, su empresa actual, sus grupos y cursos (subgrafo útil para enseñar el modelo):

```cypher
MATCH (p:Person)-[w:WORKS_AT]->(co:Company)
WHERE w.isCurrent = true
WITH p, co
LIMIT 1
OPTIONAL MATCH (p)-[:MEMBER_OF]->(g:Group)
OPTIONAL MATCH (p)-[:ENROLLED_IN]->(c:Course)
RETURN p, co, g, c;
```
