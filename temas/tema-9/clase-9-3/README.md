# Guía Didáctica Tema 9 - Clase 3: Optimización y seguridad en Cypher

## Objetivos

* Crear índices para acelerar búsquedas.
* Analizar planes con `EXPLAIN` y `PROFILE` y reconocer “uso de índice” vs “escaneo”.
* Reducir el coste de recorridos: limitar profundidad y filtrar antes de expandir.
* Hacer una transacción controlada.

## Requisitos

Ya debes haber importado los CSV (`persons`, `companies`, `groups`, `courses` + relaciones) en Neo4j. Si aún no lo has echo, sigue las instrucciones de [este documento.](../../../docker/tema-9/docker-tema-9-3/data/carga_datos.md)

## 1) Optimización con índices

La idea del tema: indexar propiedades **muy consultadas** (por ejemplo, ids, nombre, ciudad).

### 1.1 Crear índices recomendados (si no existen)

```cypher
CREATE INDEX person_id IF NOT EXISTS FOR (p:Person) ON (p.personId);
CREATE INDEX person_name IF NOT EXISTS FOR (p:Person) ON (p.name);
CREATE INDEX person_location IF NOT EXISTS FOR (p:Person) ON (p.location);

CREATE INDEX company_id IF NOT EXISTS FOR (c:Company) ON (c.companyId);
CREATE INDEX company_name IF NOT EXISTS FOR (c:Company) ON (c.name);

CREATE INDEX course_tag IF NOT EXISTS FOR (c:Course) ON (c.tag);
```

### 1.2 Consulta típica que debería aprovechar índice

```cypher
MATCH (p:Person {personId: 1})
RETURN p;
```

**Qué tienes que mirar:** más adelante, con `PROFILE`, intenta ver un operador tipo *NodeIndexSeek* (uso de índice) en lugar de *NodeByLabelScan* (escaneo).

## 2) Analizar consultas con EXPLAIN y PROFILE

* `EXPLAIN` muestra el plan **sin ejecutar**.
* `PROFILE` ejecuta y te da estadísticas (db hits, filas, etc.).

### 2.1 EXPLAIN (no ejecuta)

```cypher
EXPLAIN
MATCH (p:Person {personId: 1})
RETURN p;
```

### 2.2 PROFILE (sí ejecuta)

```cypher
PROFILE
MATCH (p:Person {personId: 1})
RETURN p;
```

**Qué deberías observar en el plan:**

* Que el motor “busque” por índice si existe (ideal).

## 3) Reducir profundidad y coste de recorridos (red social)

En grafos, cada salto puede multiplicar combinaciones. Por eso en el tema se insiste en:

* Limitar profundidad `*1..3`
* Filtrar **antes** de expandir
* Usar etiquetas específicas para reducir candidatos

### 3.1 Caso “caro”: contactos hasta 4 saltos (solo para observar)

```cypher
PROFILE
MATCH (a:Person {personId: 1})-[:CONNECTED_TO*1..4]-(b:Person)
RETURN count(DISTINCT b) AS contactos_1_a_4;
```

### 3.2 Versión optimizada: limitar y filtrar antes

Ejemplo: “solo contactos (hasta 3 saltos) que estén en Madrid”.

```cypher
PROFILE
MATCH (a:Person {personId: 1})
MATCH (a)-[:CONNECTED_TO*1..3]-(b:Person)
WHERE b.location = "Madrid"
RETURN count(DISTINCT b) AS contactos_madrid_1_a_3;
```

**Qué comparar (mensaje del tema):**

* Menos profundidad + filtro temprano ⇒ menos coste.

> Si “Madrid” devuelve 0, prueba otra: `"Barcelona"`, `"Valencia"`, `"Sevilla"`.

## 4) Optimizar patrones reales: recomendación de cursos desde tu red

Consulta “tipo LinkedIn”: cursos que hacen tus contactos (hasta 2 saltos) y tú aún no.

### 4.1 Versión directa (y medible con PROFILE)

```cypher
PROFILE
MATCH (me:Person {personId: 1})
MATCH (me)-[:CONNECTED_TO*1..2]-(other:Person)-[:ENROLLED_IN]->(c:Course)
WHERE NOT (me)-[:ENROLLED_IN]->(c)
RETURN c.title AS curso, c.provider AS proveedor, count(DISTINCT other) AS personas_que_lo_hacen
ORDER BY personas_que_lo_hacen DESC
LIMIT 10;
```

**Qué estás aplicando aquí:**

* Profundidad limitada (`*1..2`)
* Filtro anti-repetición (`DISTINCT`)
* Caso de uso real (recomendación)

## 5) Control de transacciones (commit/rollback)

Esta parte del ejercicio, hay que hacerlo desde `cypher-shell`. Para ello, hay que conectarse a la terminal de comandos del contenedor.

Una vez dentro de la terminar de comandos del contenedor, utiliza el siguiente comando para acceder a `cypher-shell`:

```bash
cypher-shell -u neo4j -p neo4j12345
```

### 5.1 Demo: crear algo y deshacerlo

1. Inicia transacción:

    ```cypher
    :begin;
    ```

2. Ejecuta (cambios dentro de la transacción):

    ```cypher
    CREATE (u:Person {personId: 777777, name:"Carlos Tx", location:"Madrid"})
    RETURN u;
    ```

3. Comprueba que el nodos existe dentro del contexto de la transacción:

    ```cypher
    MATCH (u:Person {personId: 777777})
    RETURN u;
    ```

4. Ahora deshaz:

    ```cypher
    :rollback;
    ```

5. Comprueba que el nodo ya no existe:

    ```cypher
    MATCH (u:Person {personId: 777777})
    RETURN u;
    ```

**Qué deberías ver:** después del rollback, no devuelve nada.
**Qué demuestra:** consistencia y capacidad de revertir cambios.
