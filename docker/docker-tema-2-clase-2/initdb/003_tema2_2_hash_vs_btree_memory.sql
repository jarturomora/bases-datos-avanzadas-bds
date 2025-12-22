-- 003_tema2_2_hash_vs_btree_memory.sql
-- Tema 2.2 — Comparativa didáctica: BTREE (B+Tree) vs HASH multiclave (ENGINE=MEMORY)
--
-- Contexto:
--   - InnoDB usa índices tipo B-tree/B+Tree (clustered + secundarios).
--   - InnoDB NO permite crear índices HASH “de usuario”; el hashing en InnoDB es interno (Adaptive Hash Index).
--   - Para comparar HASH vs BTREE de forma tangible, se usa ENGINE=MEMORY.

USE tema2_2_demo;

-- Ajusta el tamaño de la muestra (RAM). Recomendado: 50k–150k.
SET @MUESTRA := 50000;

DROP TABLE IF EXISTS usuarios_mem_hash;
DROP TABLE IF EXISTS usuarios_mem_btree;

CREATE TABLE usuarios_mem_hash (
  usuario_id BIGINT UNSIGNED NOT NULL,
  pais       CHAR(2) NOT NULL,
  estado     ENUM('activo','inactivo') NOT NULL,
  email      VARCHAR(180) NOT NULL,
  fecha_registro DATE NOT NULL,
  PRIMARY KEY (usuario_id),
  INDEX idx_hash_pais_estado (pais, estado) USING HASH,
  INDEX idx_hash_email (email) USING HASH
) ENGINE=MEMORY;

CREATE TABLE usuarios_mem_btree (
  usuario_id BIGINT UNSIGNED NOT NULL,
  pais       CHAR(2) NOT NULL,
  estado     ENUM('activo','inactivo') NOT NULL,
  email      VARCHAR(180) NOT NULL,
  fecha_registro DATE NOT NULL,
  PRIMARY KEY (usuario_id),
  INDEX idx_btree_pais_estado (pais, estado) USING BTREE,
  INDEX idx_btree_email (email) USING BTREE,
  INDEX idx_btree_fecha (fecha_registro) USING BTREE
) ENGINE=MEMORY;

INSERT INTO usuarios_mem_hash (usuario_id, pais, estado, email, fecha_registro)
SELECT usuario_id, pais, estado, email, fecha_registro
FROM usuarios
WHERE usuario_id <= @MUESTRA;

INSERT INTO usuarios_mem_btree (usuario_id, pais, estado, email, fecha_registro)
SELECT usuario_id, pais, estado, email, fecha_registro
FROM usuarios
WHERE usuario_id <= @MUESTRA;

SELECT 'hash'  AS tabla, COUNT(*) AS filas FROM usuarios_mem_hash
UNION ALL
SELECT 'btree' AS tabla, COUNT(*) AS filas FROM usuarios_mem_btree;
