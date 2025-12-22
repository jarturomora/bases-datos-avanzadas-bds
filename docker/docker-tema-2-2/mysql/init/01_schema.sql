USE demo;

-- Para acelerar la carga de datos en la fase de seed (después puedes restaurar valores si deseas)
SET SESSION sql_log_bin = 0;
SET GLOBAL sync_binlog = 0;

DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL,
  country CHAR(2) NOT NULL,
  status TINYINT NOT NULL,
  plan TINYINT NOT NULL,
  last_login DATETIME NULL,
  bio VARCHAR(255) NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Importante: de inicio NO creamos índices, para que la primera consulta sea “lenta”.
-- Luego los iremos creando en 03_demo_queries.sql para medir el impacto.
