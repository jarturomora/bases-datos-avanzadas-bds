/* ============================================================
   Seed parametrizable de pedidos: 100k / 1M / 5M (MySQL 9)
   - Copia y pega todo en phpMyAdmin (o en un .sql de initdb)
   - Ajusta SOLO la variable @TARGET_ROWS
   - Requiere tabla: ecommerce.pedidos (id auto_increment, cliente_id, fecha, total, estado, canal)
   ============================================================ */

USE ecommerce;

/* ------------------------------------------------------------
   0) PARÁMETRO PRINCIPAL (elige uno)
   ------------------------------------------------------------ */
-- SET @TARGET_ROWS = 100000;   -- 100k
-- SET @TARGET_ROWS = 1000000;     -- 1M
SET @TARGET_ROWS = 5000000;  -- 5M

/* ------------------------------------------------------------
   1) Validación simple del parámetro
   ------------------------------------------------------------ */
SELECT @TARGET_ROWS AS target_rows;

-- Si vas a re-seedear, descomenta:
-- TRUNCATE TABLE pedidos;

/* ------------------------------------------------------------
   2) Tablas auxiliares de secuencia
      - seq_0_999: 0..999  (1,000 filas)
      - seq_0_4:   0..4    (5 filas) => permite llegar a 5M
   ------------------------------------------------------------ */
DROP TABLE IF EXISTS seq_0_999;
CREATE TABLE seq_0_999 (n INT NOT NULL PRIMARY KEY) ENGINE=InnoDB;

INSERT INTO seq_0_999 (n)
SELECT ones.n + tens.n*10 + hundreds.n*100
FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) ones
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) tens
CROSS JOIN (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) hundreds;

DROP TABLE IF EXISTS seq_0_4;
CREATE TABLE seq_0_4 (n INT NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO seq_0_4 (n) VALUES (0),(1),(2),(3),(4);

/* ------------------------------------------------------------
   3) Inserción parametrizable
      Generador:
        n_global = c*1,000,000 + a*1,000 + b
      Rango total posible: 0..4,999,999 (5M)
      Limitamos con WHERE n_global < @TARGET_ROWS para 100k/1M/5M.
   ------------------------------------------------------------ */
INSERT INTO pedidos (cliente_id, fecha, total, estado, canal)
SELECT
  ((n_global % 100000) + 1) AS cliente_id,
  TIMESTAMP('2024-01-01 00:00:00')
    + INTERVAL (n_global % 365) DAY
    + INTERVAL (n_global % 86400) SECOND AS fecha,
  ROUND(((n_global % 50000) / 100.0) + 5, 2) AS total,
  (n_global % 5) AS estado,
  (n_global % 3) AS canal
FROM (
  SELECT (c.n * 1000000 + a.n * 1000 + b.n) AS n_global
  FROM seq_0_4 c
  CROSS JOIN seq_0_999 a
  CROSS JOIN seq_0_999 b
) gen
WHERE n_global < @TARGET_ROWS;

/* ============================================================
   Fin del script de seed parametrizable
   ============================================================ */