-- =================================================================
-- mediciones.sql
-- Demostración de índices en MySQL: lookup y coste de mantenimiento
-- Compatible MySQL 9.x / 8.x
-- =================================================================

USE tienda;

-- --------------------------------------------------------------
-- 0) Información de contexto
-- --------------------------------------------------------------
SELECT 'Contexto: Conteos iniciales' AS info;
SELECT
  (SELECT COUNT(*) FROM CLIENTE)       AS clientes,
  (SELECT COUNT(*) FROM PROVEEDOR)     AS proveedores,
  (SELECT COUNT(*) FROM PRODUCTO)      AS productos,
  (SELECT COUNT(*) FROM VENTA)         AS ventas,
  (SELECT COUNT(*) FROM VENTA_DETALLE) AS detalles;

-- --------------------------------------------------------------
-- 1) Preparación: preparar caché y asegurar estado sin índice
-- --------------------------------------------------------------
SELECT 'Preparación: drop índice si existe y calentamiento de caché' AS info;

-- El índice se crea/elimina a lo largo del script.
-- Si existiera de una sesión previa, lo eliminamos.
DROP INDEX IF EXISTS idx_producto_nombre ON PRODUCTO;

-- Consultas de calentamiento de caché (acceden a páginas de datos)
SELECT producto_id FROM PRODUCTO WHERE producto_id IN (1, 100, 250, 500, 600);
SELECT * FROM PRODUCTO WHERE nombre = 'Producto 250'; -- sin índice, será table scan

-- --------------------------------------------------------------
-- 2) LOOKUP SIN ÍNDICE en PRODUCTO(nombre)
--    (línea base, EXPLAIN ANALYZE mide latencia real de SELECT)
-- --------------------------------------------------------------
SELECT 'Lookup SIN índice: igualdad (=) y LIKE' AS info;

EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre = 'Producto 250';

-- Con wildcard inicial el B-Tree no ayuda aun con índice; sirve de comparativa.
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE '%250%';

-- Prefijo: sin índice seguirá escaneando; guardamos para comparar luego.
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE 'Producto 25%';

-- --------------------------------------------------------------
-- 3) CREAR ÍNDICE y repetir LOOKUP
-- --------------------------------------------------------------
SELECT 'Crear índice y repetir LOOKUP' AS info;

CREATE INDEX idx_producto_nombre ON PRODUCTO(nombre);
ANALYZE TABLE PRODUCTO;

EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre = 'Producto 250';

-- Prefijo (aprovecha índice)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE 'Producto 25%';

-- Wildcard inicial (no aprovecha índice B-Tree)
EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE '%250%';

-- --------------------------------------------------------------
-- 4) INSERCIONES EN BLOQUE: coste con y sin índice
--    Usamos NOW(6) para cronometraje en microsegundos
-- --------------------------------------------------------------
SELECT 'INSERCIONES EN BLOQUE: medir tiempos con y sin índice' AS info;

-- 4.1) Preparamos: eliminar índice para la primera tanda
DROP INDEX IF EXISTS idx_producto_nombre ON PRODUCTO;
ANALYZE TABLE PRODUCTO;

-- Tanda A: insertar 1000 productos (IDs 2601..3600) SIN índice
SET @t0 := NOW(6);

INSERT INTO PRODUCTO (producto_id, nombre, precio_unitario, proveedor_id)
SELECT n,
       CONCAT('Producto ', n),
       ROUND(5 + (n % 200) * 0.75, 2),
       1 + (n % 50)
FROM seq_10000
WHERE n BETWEEN 2601 AND 3600;

SET @t1 := NOW(6);
SELECT 'Inserción SIN índice (1000 filas 2601..3600) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t0, @t1) AS micros;

-- 4.2) Crear índice y repetir con otra tanda
CREATE INDEX idx_producto_nombre ON PRODUCTO(nombre);
ANALYZE TABLE PRODUCTO;

-- Tanda B: insertar 1000 productos (IDs 3601..4600) CON índice
SET @t2 := NOW(6);

INSERT INTO PRODUCTO (producto_id, nombre, precio_unitario, proveedor_id)
SELECT n,
       CONCAT('Producto ', n),
       ROUND(5 + (n % 200) * 0.75, 2),
       1 + (n % 50)
FROM seq_10000
WHERE n BETWEEN 3601 AND 4600;

SET @t3 := NOW(6);
SELECT 'Inserción CON índice (1000 filas 3601..4600) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t2, @t3) AS micros;

-- Nota didáctica:
-- Espera mayor tiempo con el índice presente: MySQL debe actualizar el B-Tree por fila.

-- --------------------------------------------------------------
-- 5) UPDATE: coste con y sin índice en la columna indexada
-- --------------------------------------------------------------
SELECT 'UPDATE: comparar coste cuando la columna indexada cambia' AS info;

-- 5.1) CON índice: actualizamos nombre (columna indexada) en un rango
--     Esto obliga a reescritura del índice para cada fila
SET @t4 := NOW(6);

UPDATE PRODUCTO
SET nombre = CONCAT(nombre, ' X')
WHERE producto_id BETWEEN 1 AND 2000;

SET @t5 := NOW(6);
SELECT 'UPDATE CON índice sobre columna indexada (1..2000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t4, @t5) AS micros;

-- 5.2) SIN índice: drop y repetimos otro rango
DROP INDEX IF EXISTS idx_producto_nombre ON PRODUCTO;
ANALYZE TABLE PRODUCTO;

SET @t6 := NOW(6);

UPDATE PRODUCTO
SET nombre = CONCAT(nombre, ' Y')
WHERE producto_id BETWEEN 2001 AND 4000;

SET @t7 := NOW(6);
SELECT 'UPDATE SIN índice sobre columna (2001..4000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t6, @t7) AS micros;

-- Comentario:
-- Deberías observar menor tiempo sin índice porque no hay mantenimiento del B-Tree.

-- --------------------------------------------------------------
-- 6) CONTROL: UPDATE en columna NO indexada (precio)
--    (muestra que el mantenimiento de índice afecta solo columnas indexadas)
-- --------------------------------------------------------------
SELECT 'CONTROL: UPDATE en columna NO indexada (precio_unitario)' AS info;

-- Creamos de nuevo el índice para subrayar que actualizar precio (no indexado) no afecta su mantenimiento
CREATE INDEX idx_producto_nombre ON PRODUCTO(nombre);
ANALYZE TABLE PRODUCTO;

SET @t8 := NOW(6);

UPDATE PRODUCTO
SET precio_unitario = precio_unitario + 0.10
WHERE producto_id BETWEEN 1 AND 4000;

SET @t9 := NOW(6);
SELECT 'UPDATE CON índice pero sobre columna NO indexada (1..4000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t8, @t9) AS micros;

-- --------------------------------------------------------------
-- 7) LOOKUP final post-mantenimiento (ver que SELECT sigue beneficiándose)
-- --------------------------------------------------------------
SELECT 'Lookup final con índice recreado' AS info;

EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre = 'Producto 250';

EXPLAIN ANALYZE
SELECT producto_id, nombre, precio_unitario
FROM PRODUCTO
WHERE nombre LIKE 'Producto 25%';

-- --------------------------------------------------------------
-- 8) Resumen de tamaño e índices
-- --------------------------------------------------------------
SELECT 'Resumen de índices en PRODUCTO' AS info;
SHOW INDEX FROM PRODUCTO;

SELECT 'Total de filas en PRODUCTO tras las inserciones' AS info;
SELECT COUNT(*) AS total_productos FROM PRODUCTO;

-- Fin del laboratorio
