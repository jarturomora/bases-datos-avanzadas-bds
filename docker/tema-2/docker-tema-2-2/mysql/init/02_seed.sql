USE demo;

-- Tabla auxiliar con números 0..999 (1000 filas)
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

-- Carga 1,000,000 filas: (a.n * 1000 + b.n) produce 0..999999
-- Campos:
-- - email único (user{N}@example.com)
-- - created_at distribuido a lo largo de 365 días
-- - country/status/plan con variedad para filtros
INSERT INTO users (email, created_at, country, status, plan, last_login, bio)
SELECT
  CONCAT('user', (a.n * 1000 + b.n), '@example.com') AS email,
  TIMESTAMP('2024-01-01 00:00:00') + INTERVAL ((a.n * 1000 + b.n) % 365) DAY
                                + INTERVAL ((a.n * 1000 + b.n) % 86400) SECOND AS created_at,
  ELT(((a.n * 1000 + b.n) % 8) + 1, 'ES','MX','AR','CO','CL','PE','US','FR') AS country,
  ((a.n * 1000 + b.n) % 3) AS status,  -- 0,1,2
  ((a.n * 1000 + b.n) % 4) AS plan,    -- 0..3
  CASE
    WHEN ((a.n * 1000 + b.n) % 5)=0 THEN NULL
    ELSE TIMESTAMP('2024-01-01 00:00:00') + INTERVAL ((a.n * 1000 + b.n) % 365) DAY
  END AS last_login,
  CONCAT('Bio ', (a.n * 1000 + b.n)) AS bio
FROM seq_0_999 a
CROSS JOIN seq_0_999 b;

-- Asegura unicidad de email con un índice único (lo creamos aquí para evitar duplicados accidentales)
-- Si prefieres que la demo “sin índice” sea total al inicio, comenta estas dos líneas y crea el UNIQUE más tarde.
ALTER TABLE users ADD UNIQUE KEY uq_users_email (email);
