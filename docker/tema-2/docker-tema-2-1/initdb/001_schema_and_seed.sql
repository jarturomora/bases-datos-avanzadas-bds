-- ------------------------------------------------------------------
-- Base de datos: tienda
-- Compatible con MySQL 9.x / 8.x (Docker entrypoint)
-- Sin CTEs; usa tabla de secuencia por cross-join
-- ------------------------------------------------------------------

-- Configuración básica
SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- Crear BD y usarla
CREATE DATABASE IF NOT EXISTS tienda
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE tienda;

-- ------------------------------------------------------------------
-- Limpieza por si el script se ejecuta más de una vez (idempotencia)
-- ------------------------------------------------------------------
DROP TABLE IF EXISTS VENTA_DETALLE;
DROP TABLE IF EXISTS VENTA;
DROP TABLE IF EXISTS PRODUCTO;
DROP TABLE IF EXISTS PROVEEDOR;
DROP TABLE IF EXISTS CLIENTE;
DROP TABLE IF EXISTS seq_10000;

-- ------------------------------------------------------------------
-- Tabla de secuencias (1..10000) sin CTEs
-- ------------------------------------------------------------------
-- Genera números 1..10000 vía Cross Join de dígitos (0..9)
CREATE TABLE seq_10000 (
  n INT PRIMARY KEY
) ENGINE=InnoDB;

INSERT INTO seq_10000 (n)
SELECT ones.n + tens.n*10 + hundreds.n*100 + thousands.n*1000 + 1 AS n
FROM
  (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) ones
CROSS JOIN
  (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) tens
CROSS JOIN
  (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) hundreds
CROSS JOIN
  (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
         UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) thousands;

-- ------------------------------------------------------------------
-- Esquema (tablas)
-- ------------------------------------------------------------------
CREATE TABLE CLIENTE (
  cliente_id INT NOT NULL,
  nombre      VARCHAR(120) NOT NULL,
  telefono    VARCHAR(40),
  email       VARCHAR(160),
  PRIMARY KEY (cliente_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE PROVEEDOR (
  proveedor_id INT NOT NULL,
  nombre       VARCHAR(120) NOT NULL,
  telefono     VARCHAR(40),
  email        VARCHAR(160),
  PRIMARY KEY (proveedor_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE PRODUCTO (
  producto_id   INT NOT NULL,
  nombre        VARCHAR(160) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  proveedor_id  INT NOT NULL,
  PRIMARY KEY (producto_id),
  CONSTRAINT fk_producto_proveedor
    FOREIGN KEY (proveedor_id) REFERENCES PROVEEDOR(proveedor_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE VENTA (
  venta_id    INT NOT NULL,
  fecha_venta DATETIME NOT NULL,
  cliente_id  INT NOT NULL,
  total_venta DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (venta_id),
  CONSTRAINT fk_venta_cliente
    FOREIGN KEY (cliente_id) REFERENCES CLIENTE(cliente_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE VENTA_DETALLE (
  venta_detalle_id INT NOT NULL,
  venta_id         INT NOT NULL,
  producto_id      INT NOT NULL,
  cantidad         INT NOT NULL,
  precio_unitario  DECIMAL(10,2) NOT NULL,
  subtotal         DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (venta_detalle_id),
  CONSTRAINT fk_detalle_venta
    FOREIGN KEY (venta_id) REFERENCES VENTA(venta_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_detalle_producto
    FOREIGN KEY (producto_id) REFERENCES PRODUCTO(producto_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Índices útiles para FKs (no crear índice en PRODUCTO(nombre) aún)
CREATE INDEX idx_producto_proveedor_id ON PRODUCTO(proveedor_id);
CREATE INDEX idx_venta_cliente_id     ON VENTA(cliente_id);
CREATE INDEX idx_detalle_venta_id     ON VENTA_DETALLE(venta_id);
CREATE INDEX idx_detalle_producto_id  ON VENTA_DETALLE(producto_id);

-- ------------------------------------------------------------------
-- Carga de datos (sin CTEs)
-- ------------------------------------------------------------------

-- 100 CLIENTES
INSERT INTO CLIENTE (cliente_id, nombre, telefono, email)
SELECT n,
       CONCAT('Cliente ', n),
       CONCAT('+34 600', LPAD(n, 3, '0')),
       CONCAT('cliente', n, '@mail.test')
FROM seq_10000
WHERE n <= 100;

-- 50 PROVEEDORES
INSERT INTO PROVEEDOR (proveedor_id, nombre, telefono, email)
SELECT n,
       CONCAT('Proveedor ', n),
       CONCAT('+34 700', LPAD(n, 3, '0')),
       CONCAT('prov', n, '@mail.test')
FROM seq_10000
WHERE n <= 50;

-- 600 PRODUCTOS (precio determinista y proveedor rotatorio)
INSERT INTO PRODUCTO (producto_id, nombre, precio_unitario, proveedor_id)
SELECT n,
       CONCAT('Producto ', n),
       ROUND(5 + (n % 200) * 0.75, 2),     -- rango de precios razonable
       1 + (n % 50)                        -- asigna proveedores 1..50 en rotación
FROM seq_10000
WHERE n <= 600;

-- 200 VENTAS (fechas recientes)
INSERT INTO VENTA (venta_id, fecha_venta, cliente_id, total_venta)
SELECT n,
       DATE_SUB(NOW(), INTERVAL (n % 60) DAY),  -- fecha en las últimas ~8 semanas
       1 + (n % 100),                           -- clientes 1..100
       0.00
FROM seq_10000
WHERE n <= 200;

-- 400 DETALLES (precio tomado desde PRODUCTO; subtotal = cantidad * precio)
INSERT INTO VENTA_DETALLE (venta_detalle_id, venta_id, producto_id, cantidad, precio_unitario, subtotal)
SELECT n AS venta_detalle_id,
       (1 + (n % 200))       AS venta_id,       -- reparte en ventas 1..200
       (1 + (n % 600))       AS producto_id,    -- productos 1..600
       (1 + (n % 5))         AS cantidad,       -- 1..5 uds
       p.precio_unitario     AS precio_unitario,
       (1 + (n % 5)) * p.precio_unitario AS subtotal
FROM seq_10000 s
JOIN PRODUCTO p ON p.producto_id = (1 + (s.n % 600))
WHERE s.n <= 400;

-- Actualizar total_venta a partir del detalle
UPDATE VENTA v
JOIN (
  SELECT venta_id, SUM(subtotal) AS total
  FROM VENTA_DETALLE
  GROUP BY venta_id
) s ON s.venta_id = v.venta_id
SET v.total_venta = s.total;
