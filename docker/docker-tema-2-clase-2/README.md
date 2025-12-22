# Tema 2.2 — Demostración del Ejemplo práctico

Esta guía describe, paso a paso, cómo ejecutar una la demostración de la clase del tema 2.2 utilizando **Docker Compose** desde **VS Code** con la extensión **Container Tools**.

## 1. Objetivo de la demostración

Reafirmar conceptos de acceso a datos e índices con un caso realista:

* **Consulta por rango de fechas**: “usuarios registrados en un mes”.
* **Búsqueda exacta por email**: localizar un usuario por correo.
* Observar el impacto de:
  * índices (B+Tree/BTREE en InnoDB)
  * implicaciones del **partitioning** por rango en `fecha_registro`
  * comparativa didáctica **BTREE vs HASH multiclave** con `ENGINE=MEMORY`

## 2. Estructura de ficheros

```text
docker-tema-2-clase-2/
├─ docker-compose.yml
└─ initdb/
   ├─ 002_demo_tema2_2_usuarios.sql
   └─ 003_tema2_2_hash_vs_btree_memory.sql
```

### Descripción de cada elemento

* **`docker-compose.yml`**  
  Define los contenedores:
  * MySQL 9
  * phpMyAdmin

* **`initdb/`**  
  Carpeta con scripts SQL que MySQL ejecuta **automáticamente** al inicializar un volumen de datos nuevo.

* **`002_demo_tema2_2_usuarios.sql`**  
  Crea la BD `tema2_2_demo`, la tabla `usuarios` (InnoDB, particionada por `fecha_registro`) y genera datos ficticios.

* **`003_tema2_2_hash_vs_btree_memory.sql`**  
  Crea tablas `ENGINE=MEMORY` para comparar índices `USING HASH` vs `USING BTREE` con una muestra del dataset.

### Nota importante sobre ejecución de scripts

Los scripts de `initdb/` **solo se ejecutan automáticamente** cuando MySQL inicializa un **volumen vacío**.  
Para regenerar datos (y que se re-ejecuten `002` y `003`) hay que regenerar también los contenedores, desde VS Code
con la extensión "Container Tools" o desde la terminal ejecutando los siguientes comandos:

```bash
docker compose down -v
docker compose up -d
```

## 3. Contenedores incluidos y puertos

### 3.1 MySQL

* Contenedor: `mysql_tema2_2`
* Puerto host: **3307** → contenedor 3306

Credenciales:

* Root: `root` / `root`
* Usuario alumno: `alumno` / `alumno`
* Base de datos: `tema2_2_demo`

### 3.2 phpMyAdmin

* Contenedor: `pma_tema2_2`
* URL: `http://localhost:8082`

## 4. Puesta en marcha de los contenedores desde VS Code (Container Tools)

1. Abre VS Code y la carpeta `tema2-2-demo/`.
2. Localiza `docker-compose.yml`.
3. Clic derecho → **Compose Up** (o “Bring Up”, según versión).

Alternativa utilizando la terminal integrada en VS Code:

```bash
docker compose up -d
```

## 5. Acceso a phpMyAdmin

1. En un navegador, abre la siguiente dirección: <http://localhost:8082>
2. Servidor: `mysql`
3. Usuario: `alumno`
4. Contraseña: `alumno`

## 6. Consideración clave: ejecución automática del SQL

El contenido de `initdb/` se ejecuta **solo** cuando MySQL inicializa un **volumen de datos nuevo**.

## 7. Guía de la demostración de clase (paso a paso)

Este guion está pensado para ejecutarse utilizando **phpMyAdmin** (o cualquier cliente MySQL) y comentando el **plan de ejecución** que devuelve `EXPLAIN ANALYZE`.

> **Recordatorio didáctico**
> `EXPLAIN ANALYZE` ejecuta la consulta y muestra cómo MySQL accede a los datos:
> índices usados, filas examinadas y coste relativo de la operación.

### Paso 1 — Verificar la carga de datos (tabla InnoDB)

```sql
USE tema2_2_demo;

SELECT COUNT(*) AS total_usuarios FROM usuarios;

SELECT MIN(fecha_registro) AS min_fecha,
       MAX(fecha_registro) AS max_fecha
FROM usuarios;
```

**Qué hace cada comando:**

* `USE tema2_2_demo`: selecciona la base de datos de la demo.
* `COUNT(*)`: verifica que los datos ficticios se han cargado correctamente.
* `MIN / MAX(fecha_registro)`: confirma el rango temporal cubierto por los datos.

**Aspectos a observar:**

* El volumen de datos (≈ 200.000 filas por defecto).
* La distribución temporal, que justifica el uso de **índices por fecha** y **particiones**.

### Paso 2 — Caso de negocio: altas por mes (B+Tree para rangos)

**Pregunta de negocio:**

> “¿Cuántos usuarios se registraron en mayo de 2024?”

```sql
USE tema2_2_demo;

EXPLAIN ANALYZE
SELECT COUNT(*) AS altas
FROM usuarios
WHERE fecha_registro >= '2024-05-01'
  AND fecha_registro <  '2024-06-01';
```

**Qué hace:**

* Filtra por un **rango de fechas**.
* Agrega el resultado con `COUNT(*)`.

**Aspectos a observar:**

* Uso del índice `idx_usuarios_fecha`.
* Posible **partition pruning** (solo se accede a la partición del año 2024).
* Número reducido de filas examinadas frente al total de la tabla.

**Aprendizaje clave para el alumno:**

> Los índices **B+Tree** son especialmente eficientes para **consultas por rango**.

### Paso 3 — Lookup por email (B+Tree para igualdad exacta)

**Escenario operativo:**

> “Atención al cliente recibe un email y necesita localizar al usuario.”

```sql
USE tema2_2_demo;

EXPLAIN ANALYZE
SELECT usuario_id, nombre, apellido, email, fecha_registro, pais, estado
FROM usuarios
WHERE email = 'user000123@example.com';
```

**Qué hace:**

* Realiza una búsqueda por **igualdad exacta** sobre `email`.

**Aspectos a observar:**

* Uso del índice `idx_usuarios_email`.
* Muy pocas filas examinadas (acceso altamente selectivo).

**Nota importante (diseño con particiones):**

* La unicidad formal es `(email, fecha_registro)` por una regla del motor.
* Aun así, el índice adicional por `email` permite un **lookup eficiente y simple**.

---

### Paso 4 — Introducción conceptual: B+Tree vs Hashing multiclave

**Aprendizaje clave para el alumno:**

* En **InnoDB**, los índices son **B+Tree**.
* No es posible crear índices HASH manualmente en InnoDB.
* Para comparar **HASH vs BTREE**, se usan tablas `ENGINE=MEMORY`.

**Objetivo del resto de la demostración:**

> Comparar igualdad exacta, rangos y prefijos entre **HASH** y **BTREE**.

### Paso 5 — Verificar tablas MEMORY (script 003)

```sql
USE tema2_2_demo;
SHOW TABLES;
```

**Qué hace:**

* Muestra las tablas disponibles en la base de datos.

**Aspectos a observar:**

* Existencia de:

  * `usuarios_mem_hash`
  * `usuarios_mem_btree`

Estas tablas contienen **la misma muestra de datos**, pero con **estructuras de índice distintas**.

### Paso 6 — Comparativa 1: igualdad exacta multiclave

**Escenario técnico:**

> “Filtrar usuarios activos de un país concreto.”

```sql
USE tema2_2_demo;

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM usuarios_mem_hash
WHERE pais='ES' AND estado='activo';

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM usuarios_mem_btree
WHERE pais='ES' AND estado='activo';
```

**Qué hace:**

* Filtra por **dos columnas con igualdad exacta**.

**Aspectos a observar:**

* Ambas consultas son rápidas.
* HASH suele ser muy competitivo en igualdad exacta multiclave.
* BTREE también funciona bien, aunque su fortaleza es más general.

**Aprendizaje clave para el alumno:**

> HASH es muy bueno en igualdad exacta, pero es especializado.

### Paso 7 — Comparativa 2: rangos y prefijos (BTREE gana por diseño)

#### Rango por fecha

```sql
USE tema2_2_demo;

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM usuarios_mem_btree
WHERE fecha_registro >= '2024-05-01'
  AND fecha_registro <  '2024-06-01';
```

**Qué hace:**

* Consulta por rango sobre una columna indexada con BTREE.

**Aspectos a observar:**

* Uso eficiente del índice.
* HASH no es una opción válida para este tipo de consulta.

#### Prefijo (autocompletado)

```sql
USE tema2_2_demo;

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM usuarios_mem_btree
WHERE email LIKE 'user0001%';
```

**Qué hace;**

* Búsqueda por prefijo sobre un índice ordenado.

**Aspectos a observar:**

* BTREE permite recorrer el índice de forma ordenada.
* HASH no soporta prefijos ni navegación secuencial.

### Paso 8 — Cierre conceptual

* **B+Tree / BTREE (InnoDB)**

  * Igualdad, rangos, prefijos, ORDER BY.
  * Opción generalista para la mayoría de sistemas OLTP (Online Transaction Processing o Procesamiento de Transacciones en Línea).

* **HASH multiclave (MEMORY)**

  * Excelente para igualdad exacta.
  * No apto para rangos, prefijos ni ordenación.
  * Motor en memoria, no persistente.

**Conclusión final:**

> No existe un índice “mejor” en general: la clave está en **conocer el patrón de acceso** y diseñar los índices en consecuencia.
