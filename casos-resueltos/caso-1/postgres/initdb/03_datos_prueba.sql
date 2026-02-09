-- Datos de prueba mínimos (smoke test) - Español

INSERT INTO pais (codigo_pais, nombre) VALUES
('ES', 'España'),
('FR', 'Francia'),
('PT', 'Portugal')
ON CONFLICT (codigo_pais) DO NOTHING;

-- Ciudades base
INSERT INTO ciudad (codigo_pais, nombre) VALUES
('ES', 'Madrid'),
('ES', 'Barcelona'),
('ES', 'Valencia'),
('ES', 'Sevilla'),
('FR', 'París'),
('PT', 'Lisboa');

-- Usuarios de ejemplo
INSERT INTO usuario (id_usuario, correo, nombre_completo) VALUES
(gen_random_uuid(), 'ana.anfitriona@rbnb.local', 'Ana López'),
(gen_random_uuid(), 'carlos.anfitrion@rbnb.local', 'Carlos García'),
(gen_random_uuid(), 'lucia.huesped@rbnb.local', 'Lucía Martín'),
(gen_random_uuid(), 'david.huesped@rbnb.local', 'David Pérez');

-- Convertimos dos usuarios en anfitriones y dos en huéspedes
WITH u AS (
  SELECT correo, id_usuario FROM usuario
)
INSERT INTO anfitrion (id_anfitrion, superanfitrion)
SELECT id_usuario, true FROM u WHERE correo='ana.anfitriona@rbnb.local'
UNION ALL
SELECT id_usuario, false FROM u WHERE correo='carlos.anfitrion@rbnb.local';

WITH u AS (
  SELECT correo, id_usuario FROM usuario
)
INSERT INTO huesped (id_huesped, telefono)
SELECT id_usuario, '+34 600 111 222' FROM u WHERE correo='lucia.huesped@rbnb.local'
UNION ALL
SELECT id_usuario, '+34 600 333 444' FROM u WHERE correo='david.huesped@rbnb.local';

-- Apartamentos de ejemplo en Madrid y Barcelona
WITH
c AS (SELECT id_ciudad, nombre FROM ciudad),
a AS (SELECT id_anfitrion FROM anfitrion),
ana AS (
  SELECT id_anfitrion FROM anfitrion
  WHERE id_anfitrion = (SELECT id_usuario FROM usuario WHERE correo='ana.anfitriona@rbnb.local')
),
carlos AS (
  SELECT id_anfitrion FROM anfitrion
  WHERE id_anfitrion = (SELECT id_usuario FROM usuario WHERE correo='carlos.anfitrion@rbnb.local')
)
INSERT INTO apartamento (id_apartamento, id_anfitrion, id_ciudad, titulo, direccion, max_huespedes, precio_base_eur)
VALUES
(gen_random_uuid(), (SELECT id_anfitrion FROM ana), (SELECT id_ciudad FROM c WHERE nombre='Madrid' LIMIT 1),
 'Ático céntrico en Madrid', 'Calle Mayor 1, Madrid', 4, 120.00),
(gen_random_uuid(), (SELECT id_anfitrion FROM carlos), (SELECT id_ciudad FROM c WHERE nombre='Barcelona' LIMIT 1),
 'Loft moderno en Barcelona', 'Carrer de la Marina 10, Barcelona', 2, 95.00);

-- Calendario de 14 días para cada apartamento (simple)
INSERT INTO apartamento_dia (id_apartamento, dia, disponible, precio_eur)
SELECT
  ap.id_apartamento,
  (CURRENT_DATE + gs)::date AS dia,
  (random() < 0.75) AS disponible,
  round((ap.precio_base_eur * (0.85 + random() * 0.40))::numeric, 2) AS precio_eur
FROM apartamento ap
CROSS JOIN generate_series(0, 13) AS gs;

-- Reserva de ejemplo (siempre consistente)
WITH
apt AS (SELECT id_apartamento FROM apartamento ORDER BY creado_en LIMIT 1),
h AS (SELECT id_huesped FROM huesped ORDER BY id_huesped LIMIT 1)
INSERT INTO reserva (id_reserva, id_apartamento, id_huesped, fecha_entrada, fecha_salida, estado)
VALUES
(gen_random_uuid(), (SELECT id_apartamento FROM apt), (SELECT id_huesped FROM h),
 (CURRENT_DATE + 7), (CURRENT_DATE + 10), 'CONFIRMADA');

-- Pago asociado a la reserva
INSERT INTO pago (id_reserva, importe_eur, estado, pagado_en)
SELECT r.id_reserva, 360.00, 'PAGADO', now()
FROM reserva r
ORDER BY r.creada_en DESC
LIMIT 1;

-- Reseña (solo como ejemplo)
INSERT INTO resena (id_reserva, valoracion, comentario)
SELECT r.id_reserva, 5, 'Estancia excelente, todo muy limpio y bien ubicado.'
FROM reserva r
ORDER BY r.creada_en DESC
LIMIT 1;
