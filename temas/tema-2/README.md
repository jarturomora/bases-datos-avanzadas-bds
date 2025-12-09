# Guion de mediciones del Tema 2: índices, lookups e impacto en escrituras (MySQL 8/9)

## Prerrequisitos

* Tener la base de datos `tienda` creada y poblada con el script [`001_schema_and_seed.sql`](../../docker/docker-tema-2/initdb/001_schema_and_seed.sql). Se recomienda utilizar el [contenedor Docker del Tema 2](../../docker/docker-tema-2/README.md).
* Puede ser de utilidad, tener a mano el script [`mediciones.sql`](code/mediciones.sql) para ver la versión completa de las consultas presentadas en este guion.

A continuación, se describen los paso para replicar la demostración mostrada en la videoclase.

## 1) Verificación inicial

**Objetivo:** asegurar que la base está cargada y preparar caché.

```sql
USE tienda;

-- Conteos básicos
SELECT
  (SELECT COUNT(*) FROM CLIENTE)       AS clientes,
  (SELECT COUNT(*) FROM PROVEEDOR)     AS proveedores,
  (SELECT COUNT(*) FROM PRODUCTO)      AS productos,
  (SELECT COUNT(*) FROM VENTA)         AS ventas,
  (SELECT COUNT(*) FROM VENTA_DETALLE) AS detalles;

-- Preparación del caché (acceso a páginas de datos)
SELECT producto_id FROM PRODUCTO WHERE producto_id IN (1,100,250,500,600);
```

**Observa:** que los conteos son razonables (≥600 productos, etc.).

## 2) Lookups SIN índice (línea base)

**Objetivo:** medir el coste de búsqueda sin apoyo del índice.

```sql
-- Igualdad exacta
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre = 'Producto 250';

-- Búsqueda con comodín inicial (peor caso)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE '%250%';

-- Búsqueda por prefijo (sin índice seguirá costosa)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE 'Producto 25%';
```

**Qué mirar en EXPLAIN ANALYZE:**

* Tiempo total reportado.
* Si aparece **table scan** (full scan) y la estimación de **rows**.

## 3) Crear índice y repetir lookups

**Objetivo:** evidenciar la mejora en igualdad y prefijo.

```sql
CREATE INDEX idx_producto_nombre ON PRODUCTO(nombre);
ANALYZE TABLE PRODUCTO;

-- Igualdad (debería cambiar a index lookup/range)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre = 'Producto 250';

-- Prefijo (aprovecha índice B-Tree)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE 'Producto 25%';

-- Comodín inicial (no usa B-Tree, sigue siendo costosa)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE '%250%';
```

**Observa:**

* Caída clara del tiempo en `=` y en `LIKE 'prefijo%'`.
* Sin mejora con `%texto%` (comodín al inicio).

## 4) Inserciones masivas: coste con vs. sin índice

**Objetivo:** mostrar que el índice **encarece** inserciones (mantener el B-Tree).

### 4.1 Inserción SIN índice

```sql
DROP INDEX idx_producto_nombre ON PRODUCTO;
ANALYZE TABLE PRODUCTO;

SET @t0 := NOW(6);
INSERT INTO PRODUCTO (producto_id, nombre, precio_unitario, proveedor_id)
SELECT n, CONCAT('Producto ', n),
       ROUND(5 + (n % 200) * 0.75, 2),
       1 + (n % 50)
FROM seq_10000
WHERE n BETWEEN 2601 AND 3600;
SET @t1 := NOW(6);

SELECT 'Inserción SIN índice (1000 filas 2601..3600) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t0, @t1) AS micros;
```

### 4.2 Inserción CON índice

```sql
CREATE INDEX idx_producto_nombre ON PRODUCTO(nombre);
ANALYZE TABLE PRODUCTO;

SET @t2 := NOW(6);
INSERT INTO PRODUCTO (producto_id, nombre, precio_unitario, proveedor_id)
SELECT n, CONCAT('Producto ', n),
       ROUND(5 + (n % 200) * 0.75, 2),
       1 + (n % 50)
FROM seq_10000
WHERE n BETWEEN 3601 AND 4600;
SET @t3 := NOW(6);

SELECT 'Inserción CON índice (1000 filas 3601..4600) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t2, @t3) AS micros;
```

**Compara:** la métrica en microsegundos. Con índice **debe ser mayor**.

## 5) UPDATE en columna indexada vs. no indexada

**Objetivo:** mostrar que el coste de mantenimiento del índice afecta **solo** a columnas indexadas.

### 5.1 UPDATE en columna **indexada** (más costoso)

```sql
ANALYZE TABLE PRODUCTO;

SET @t4 := NOW(6);
UPDATE PRODUCTO
SET nombre = CONCAT(nombre, ' X')
WHERE producto_id BETWEEN 1 AND 2000;
SET @t5 := NOW(6);

SELECT 'UPDATE CON índice (columna indexada, 1..2000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t4, @t5) AS micros;
```

### 5.2 UPDATE en columna **indexada** pero SIN índice (más barato)

```sql
DROP INDEX idx_producto_nombre ON PRODUCTO;
ANALYZE TABLE PRODUCTO;

SET @t6 := NOW(6);
UPDATE PRODUCTO
SET nombre = CONCAT(nombre, ' Y')
WHERE producto_id BETWEEN 2001 AND 4000;
SET @t7 := NOW(6);

SELECT 'UPDATE SIN índice (columna antes indexada, 2001..4000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t6, @t7) AS micros;
```

### 5.3 UPDATE en columna **no indexada** (control)

```sql
-- Recrear índice para resaltar que actualizar otra columna no lo toca
CREATE INDEX idx_producto_nombre ON PRODUCTO(nombre);
ANALYZE TABLE PRODUCTO;

SET @t8 := NOW(6);
UPDATE PRODUCTO
SET precio_unitario = precio_unitario + 0.10
WHERE producto_id BETWEEN 1 AND 4000;
SET @t9 := NOW(6);

SELECT 'UPDATE en columna NO indexada (1..4000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t8, @t9) AS micros;
```

**Conclusión esperada:**

* **INSERT/UPDATE** en columna **indexada** ⇒ más lento (mantenimiento del B-Tree).
* **UPDATE** en columna **no indexada** ⇒ no paga ese coste.

## 6) Lookup final (confirmar beneficio de índice)

**Objetivo:** validar que, pese al coste en escrituras, los SELECT se benefician.

```sql
-- Asegurar índice
ANALYZE TABLE PRODUCTO;

EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre = 'Producto 250';

EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE 'Producto 25%';
```

**Observa:** tiempos bajos y uso de índice en igualdad/prefijo.

## 7) Resumen y buenas prácticas

* Índices **aceleran lecturas** (equality/prefix) pero **encarecen escrituras** en columnas indexadas.
* `LIKE '%texto%'` **no** usa B-Tree (considera índices de texto completo si es tu caso).
* Mide con `EXPLAIN ANALYZE` y cronometra con `NOW(6)` para comparar **con y sin índice**.
* Crea **solo** los índices que tus consultas **realmente** necesitan.
* Tras grandes cargas, `ANALYZE TABLE` puede ayudar al optimizador.
