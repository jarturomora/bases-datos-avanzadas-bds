USE demo;

-- Recomendación: en phpMyAdmin ejecuta estas consultas por bloques y observa:
-- - tiempo
-- - EXPLAIN
-- - EXPLAIN ANALYZE (MySQL 8)

-- -------------------------------------------------------------------
-- A) Verificación rápida del volumen
-- -------------------------------------------------------------------
SELECT COUNT(*) AS total_rows FROM users;

-- -------------------------------------------------------------------
-- B) Consulta por rango (reporting mensual) SIN índice en created_at
-- -------------------------------------------------------------------
EXPLAIN
SELECT COUNT(*) AS users_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01';

-- Si tu versión lo permite, mide con:
EXPLAIN ANALYZE
SELECT COUNT(*) AS users_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01';

-- -------------------------------------------------------------------
-- C) Crear índice por fecha y repetir
-- -------------------------------------------------------------------
CREATE INDEX idx_users_created_at ON users(created_at);

EXPLAIN
SELECT COUNT(*) AS users_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01';

EXPLAIN ANALYZE
SELECT COUNT(*) AS users_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01';

-- -------------------------------------------------------------------
-- D) Consulta exacta por email (lookup)
-- -------------------------------------------------------------------
-- Si dejaste creado el UNIQUE en seed, ya tendrás un plan óptimo.
-- Si NO, crea un índice (idealmente UNIQUE) y compara.

EXPLAIN
SELECT *
FROM users
WHERE email = 'user123456@example.com';

EXPLAIN ANALYZE
SELECT *
FROM users
WHERE email = 'user123456@example.com';

-- -------------------------------------------------------------------
-- E) Filtro combinado: rango por fecha + país + estado
--    Aquí se ve el valor de un índice compuesto (multi-columna).
-- -------------------------------------------------------------------
-- 1) Primero, sin índice compuesto (solo created_at)
EXPLAIN
SELECT COUNT(*) AS es_active_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01'
  AND country = 'ES'
  AND status = 1;

EXPLAIN ANALYZE
SELECT COUNT(*) AS es_active_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01'
  AND country = 'ES'
  AND status = 1;

-- 2) Crea índice compuesto y compara.
-- Orden recomendado: columnas de igualdad primero, rango al final (regla práctica).
CREATE INDEX idx_users_country_status_created
ON users(country, status, created_at);

EXPLAIN
SELECT COUNT(*) AS es_active_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01'
  AND country = 'ES'
  AND status = 1;

EXPLAIN ANALYZE
SELECT COUNT(*) AS es_active_feb
FROM users
WHERE created_at >= '2024-02-01' AND created_at < '2024-03-01'
  AND country = 'ES'
  AND status = 1;

-- -------------------------------------------------------------------
-- F) Caso: ORDER BY created_at (recorrido secuencial de índice)
-- -------------------------------------------------------------------
EXPLAIN
SELECT id, email, created_at
FROM users
WHERE created_at >= '2024-06-01' AND created_at < '2024-06-02'
ORDER BY created_at
LIMIT 50;

EXPLAIN ANALYZE
SELECT id, email, created_at
FROM users
WHERE created_at >= '2024-06-01' AND created_at < '2024-06-02'
ORDER BY created_at
LIMIT 50;

-- -------------------------------------------------------------------
-- G) Trade-off: inserciones masivas y coste de índices
--    (Para demostrarlo en vivo: crear una tabla clon sin índices,
--     insertar masivo, luego crear índices, comparar con insertar con índices ya creados.)
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS users_noidx;
CREATE TABLE users_noidx LIKE users;
-- Eliminar índices secundarios (deja PK)
ALTER TABLE users_noidx DROP INDEX uq_users_email;
ALTER TABLE users_noidx DROP INDEX idx_users_created_at;
ALTER TABLE users_noidx DROP INDEX idx_users_country_status_created;

-- Inserta 200k filas desde users (rápido de reproducir)
INSERT INTO users_noidx (email, created_at, country, status, plan, last_login, bio)
SELECT CONCAT(email, '.copy'), created_at, country, status, plan, last_login, bio
FROM users
LIMIT 200000;

-- Ahora crea índices y observa el tiempo (dependerá de la máquina)
ALTER TABLE users_noidx ADD UNIQUE KEY uq_users_noidx_email (email);
CREATE INDEX idx_users_noidx_created_at ON users_noidx(created_at);
CREATE INDEX idx_users_noidx_country_status_created ON users_noidx(country, status, created_at);
