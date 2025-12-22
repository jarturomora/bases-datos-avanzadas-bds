-- =================================================================
-- mediciones.sql
-- Demostración de índices en MySQL: lookup y coste de mantenimiento
-- Compatible MySQL 9.x / 8.x
-- =================================================================

-- --------------------------------------------------------------
-- 1) Información de contexto y veridicación inicial
-- --------------------------------------------------------------
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

-- --------------------------------------------------------------
-- 2) LOOKUP SIN ÍNDICE en PRODUCTO(nombre)
--    (línea base, EXPLAIN ANALYZE mide latencia real de SELECT)
-- --------------------------------------------------------------
USE tienda;

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

-- --------------------------------------------------------------
-- 3) CREAR ÍNDICE y repetir LOOKUP
-- --------------------------------------------------------------
USE tienda;

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

-- --------------------------------------------------------------
-- 4) INSERCIONES EN BLOQUE: coste con y sin índice
--    Usamos NOW(6) para cronometraje en microsegundos
-- --------------------------------------------------------------
SELECT 'INSERCIONES EN BLOQUE: medir tiempos con y sin índice' AS info;

-- 4.1) Preparamos: eliminar índice para la primera tanda
USE tienda;

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

-- 4.2) Crear índice y repetir con otra tanda
USE tienda;

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

-- Nota didáctica:
-- Espera mayor tiempo con el índice presente: MySQL debe actualizar el B-Tree por fila.

-- --------------------------------------------------------------
-- 5) UPDATE: coste con y sin índice en la columna indexada
-- --------------------------------------------------------------
SELECT 'UPDATE: comparar coste cuando la columna indexada cambia' AS info;

-- 5.1) UPDATE en columna indexada (más costoso)
USE tienda;

ANALYZE TABLE PRODUCTO;

SET @t4 := NOW(6);
UPDATE PRODUCTO
SET nombre = CONCAT(nombre, ' X')
WHERE producto_id BETWEEN 1 AND 2000;
SET @t5 := NOW(6);

SELECT 'UPDATE CON índice (columna indexada, 1..2000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t4, @t5) AS micros;

-- 5.2) UPDATE en columna indexada pero SIN índice (más barato)
USE tienda;

DROP INDEX idx_producto_nombre ON PRODUCTO;
ANALYZE TABLE PRODUCTO;

SET @t6 := NOW(6);
UPDATE PRODUCTO
SET nombre = CONCAT(nombre, ' Y')
WHERE producto_id BETWEEN 2001 AND 4000;
SET @t7 := NOW(6);

SELECT 'UPDATE SIN índice (columna antes indexada, 2001..4000) μs' AS metrica,
       TIMESTAMPDIFF(MICROSECOND, @t6, @t7) AS micros;

-- 5.3) UPDATE en columna no indexada (control)
USE tienda;

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

-- --------------------------------------------------------------
-- 6) LOOKUP final post-mantenimiento (ver que SELECT sigue beneficiándose)
-- --------------------------------------------------------------
USE tienda;

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

-- Fin del laboratorio
