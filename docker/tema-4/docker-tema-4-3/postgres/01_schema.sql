-- Esquema relacional: categorías, productos, clientes, compras

-- Extensión para búsquedas por texto (para el índice trgm)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- DB: catalogo

CREATE TABLE IF NOT EXISTS categorias (
  categoria_id  SERIAL PRIMARY KEY,
  nombre        TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS productos (
  producto_id   SERIAL PRIMARY KEY,
  sku           TEXT NOT NULL UNIQUE,
  nombre        TEXT NOT NULL,
  categoria_id  INT NOT NULL REFERENCES categorias(categoria_id),
  precio        NUMERIC(10,2) NOT NULL,
  stock         INT NOT NULL DEFAULT 0,
  actualizado_en TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS clientes (
  cliente_id    SERIAL PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  nombre        TEXT NOT NULL,
  creado_en     TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Compras como "líneas de compra" (simplifica el caso: 1 fila = 1 producto comprado)
CREATE TABLE IF NOT EXISTS compras (
  compra_id     SERIAL PRIMARY KEY,
  cliente_id    INT NOT NULL REFERENCES clientes(cliente_id),
  producto_id   INT NOT NULL REFERENCES productos(producto_id),
  cantidad      INT NOT NULL CHECK (cantidad > 0),
  precio_unitario NUMERIC(10,2) NOT NULL,
  comprado_en   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Índices para búsquedas frecuentes
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(categoria_id);
CREATE INDEX IF NOT EXISTS idx_productos_nombre_trgm ON productos USING gin (nombre gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_compras_cliente ON compras(cliente_id);
CREATE INDEX IF NOT EXISTS idx_compras_producto ON compras(producto_id);
