USE ecommerce;

-- =========================================================
-- 0) Comprobación: volumen y base del caso
-- =========================================================
SELECT COUNT(*) AS total_pedidos FROM pedidos;

-- Esta es la consulta "problema":
-- Reporte de ventas por cliente y rango de fechas
-- (simula analistas filtrando por cliente y mes)
-- =========================================================
-- 1) SIN índices: observación del Full Table Scan
-- =========================================================
EXPLAIN
SELECT cliente_id, DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY cliente_id, DATE(fecha);

EXPLAIN ANALYZE
SELECT cliente_id, DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY cliente_id, DATE(fecha);

-- Qué mirar:
-- - type: ALL (escaneo completo)
-- - rows: cercano a 5,000,000
-- - Extra: Using where (y potencial "Using temporary" por el GROUP BY)

-- =========================================================
-- 2) Métricas de E/S y caché (antes)
--    (Contadores aproximados para ver "presión" de lectura)
-- =========================================================
SHOW SESSION STATUS LIKE 'Handler_read%';
SHOW SESSION STATUS LIKE 'Innodb_buffer_pool_read%';

-- =========================================================
-- 3) Índice simple: (cliente_id)
-- =========================================================
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
ANALYZE TABLE pedidos;

EXPLAIN
SELECT cliente_id, DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY cliente_id, DATE(fecha);

EXPLAIN ANALYZE
SELECT cliente_id, DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY cliente_id, DATE(fecha);

-- Qué mirar:
-- - type: ref (o similar) en vez de ALL
-- - rows: baja (ya no son 5M), pero aún puede ser "demasiado" si el cliente tiene muchos pedidos
-- - El filtro por fecha se aplica después (menos eficiente que indexarlo)

-- Métricas (después del índice simple)
SHOW SESSION STATUS LIKE 'Handler_read%';
SHOW SESSION STATUS LIKE 'Innodb_buffer_pool_read%';

-- =========================================================
-- 4) Índice compuesto: (cliente_id, fecha)
-- =========================================================
CREATE INDEX idx_pedidos_cliente_fecha ON pedidos(cliente_id, fecha);
ANALYZE TABLE pedidos;

EXPLAIN
SELECT cliente_id, DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY cliente_id, DATE(fecha);

EXPLAIN ANALYZE
SELECT cliente_id, DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY cliente_id, DATE(fecha);

-- Qué mirar:
-- - type: range o ref+range (dependiendo del plan)
-- - key: idx_pedidos_cliente_fecha (debe preferirse frente al simple)
-- - rows: cae aún más (se limita por cliente y por rango de fecha desde el índice)
-- - Menos trabajo de filtrado, menor latencia

-- Métricas (después del índice compuesto)
SHOW SESSION STATUS LIKE 'Handler_read%';
SHOW SESSION STATUS LIKE 'Innodb_buffer_pool_read%';

-- =========================================================
-- 5) Comparación directa: misma fecha, sin filtrar cliente
--    (para explicar por qué el orden del índice importa)
-- =========================================================
EXPLAIN ANALYZE
SELECT DATE(fecha) AS dia, SUM(total) AS ventas
FROM pedidos
WHERE fecha >= '2024-06-01' AND fecha < '2024-07-01'
GROUP BY DATE(fecha);

-- Qué mirar:
-- - Con (cliente_id, fecha) este patrón puede NO ser ideal
-- - Lección: índices compuestos sirven bien cuando el prefijo (cliente_id) participa en el filtro.
