-- Categorías
INSERT INTO categorias(nombre)
SELECT 'Categoria ' || i
FROM generate_series(1, 20) AS s(i)
ON CONFLICT (nombre) DO NOTHING;

-- Clientes
INSERT INTO clientes(email, nombre)
SELECT 'cliente' || i || '@demo.local', 'Cliente ' || i
FROM generate_series(1, 2000) AS s(i)
ON CONFLICT (email) DO NOTHING;

-- Productos (10.000)
INSERT INTO productos(sku, nombre, categoria_id, precio, stock)
SELECT
  'SKU-' || i,
  'Producto ' || i || ' / ' || (CASE WHEN i % 2 = 0 THEN 'Premium' ELSE 'Base' END),
  ((i % 20) + 1),
  (10 + (i % 500))::numeric(10,2),
  (50 + (i % 200))
FROM generate_series(1, 10000) AS s(i)
ON CONFLICT (sku) DO NOTHING;

-- Compras (50.000)
-- distribución: clientes y productos aleatorios
INSERT INTO compras(cliente_id, producto_id, cantidad, precio_unitario, comprado_en)
SELECT
  (1 + (random() * 1999))::int,
  (1 + (random() * 9999))::int,
  (1 + (random() * 4))::int,
  (10 + (random() * 500))::numeric(10,2),
  NOW() - (random() * interval '30 days')
FROM generate_series(1, 50000);
