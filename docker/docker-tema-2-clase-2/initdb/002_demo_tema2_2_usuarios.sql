-- 002_demo_tema2_2_usuarios.sql
-- Tema 2.2 — Demo "Ejemplo práctico" (Usuarios) — Opción A (CON particionado)
-- Objetivo docente:
--   1) Consultas por RANGO de fechas (altas por mes / periodo)
--   2) Búsquedas EXACTAS por email (lookup)
--   3) Reforzar el uso de índices y (opcional) particionado por rango
--
-- Importante:
--   - Este script se ejecuta automáticamente SOLO la primera vez que MySQL inicializa el volumen.
--   - Para regenerar datos: docker compose down -v && docker compose up -d

CREATE DATABASE IF NOT EXISTS tema2_2_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE tema2_2_demo;

DROP TABLE IF EXISTS usuarios;

-- Regla de particionado (MySQL):
--   La PRIMARY KEY y cualquier UNIQUE KEY deben incluir la(s) columna(s) de particionado.
-- Aquí particionamos por fecha_registro, por eso PK y UNIQUE incluyen fecha_registro.
CREATE TABLE usuarios (
  usuario_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre          VARCHAR(60)  NOT NULL,
  apellido        VARCHAR(80)  NOT NULL,
  email           VARCHAR(180) NOT NULL,
  fecha_registro  DATE         NOT NULL,
  pais            CHAR(2)      NOT NULL,
  estado          ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',

  PRIMARY KEY (usuario_id, fecha_registro),

  -- Unicidad compatible con particionado (evita ERROR 1503).
  -- Nota: la unicidad formal es (email, fecha_registro), no "email global".
  UNIQUE KEY uk_usuarios_email (email, fecha_registro),

  -- Índices para la demo
  KEY idx_usuarios_fecha (fecha_registro),
  KEY idx_usuarios_email (email)
)
PARTITION BY RANGE COLUMNS (fecha_registro) (
  PARTITION p2022 VALUES LESS THAN ('2023-01-01'),
  PARTITION p2023 VALUES LESS THAN ('2024-01-01'),
  PARTITION p2024 VALUES LESS THAN ('2025-01-01'),
  PARTITION p2025 VALUES LESS THAN ('2026-01-01'),
  PARTITION pmax  VALUES LESS THAN (MAXVALUE)
);

-- ==========================================
-- SEED: generación de datos ficticios
-- ==========================================
-- Ajusta el volumen del dataset:
--   - 50_000  (rápido)
--   - 200_000 (demo completa)
SET @N := 200000;

DELIMITER $$
CREATE PROCEDURE seed_usuarios(IN total INT)
BEGIN
  DECLARE i INT DEFAULT 1;

  WHILE i <= total DO
    SET @fecha := DATE_ADD('2022-01-01', INTERVAL FLOOR(RAND() * 1460) DAY);
    SET @pais := ELT(1 + FLOOR(RAND()*8), 'ES','MX','AR','CO','CL','PE','US','FR');
    SET @estado := IF(RAND() < 0.85, 'activo', 'inactivo');
    SET @email := CONCAT('user', LPAD(i, 6, '0'), '@example.com');

    INSERT INTO usuarios (nombre, apellido, email, fecha_registro, pais, estado)
    VALUES (
      CONCAT('Nombre', LPAD(1 + FLOOR(RAND()*9999), 4, '0')),
      CONCAT('Apellido', LPAD(1 + FLOOR(RAND()*9999), 4, '0')),
      @email,
      @fecha,
      @pais,
      @estado
    );

    SET i := i + 1;
  END WHILE;
END$$
DELIMITER ;

CALL seed_usuarios(@N);
DROP PROCEDURE seed_usuarios;

-- Validación rápida
SELECT COUNT(*) AS total_usuarios,
       MIN(fecha_registro) AS min_fecha,
       MAX(fecha_registro) AS max_fecha
FROM usuarios;
