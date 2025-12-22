USE ecommerce;

DROP TABLE IF EXISTS pedidos;

CREATE TABLE pedidos (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cliente_id BIGINT UNSIGNED NOT NULL,
  fecha DATETIME NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  estado TINYINT NOT NULL,
  canal TINYINT NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Importante: NO creamos índices al inicio (para observar el Full Table Scan).
-- Luego los añadiremos en la demo para comparar planes y latencia.
