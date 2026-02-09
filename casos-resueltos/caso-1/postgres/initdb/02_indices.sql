-- Índices RBnB (PostgreSQL) - Nombres en español

-- Listados por ciudad + precio base
CREATE INDEX idx_apartamento_ciudad_precio
  ON apartamento (id_ciudad, precio_base_eur);

-- Consultas por día (p.ej. “qué hay disponible hoy”)
-- (PK cubre id_apartamento+dia; este ayuda a filtrar por dia)
CREATE INDEX idx_apartamento_dia_dia
  ON apartamento_dia (dia);

-- Reservas por apartamento y rango de fechas (disponibilidad / solapes)
CREATE INDEX idx_reserva_apartamento_fechas
  ON reserva (id_apartamento, fecha_entrada, fecha_salida);

-- Histórico de reservas por huésped
CREATE INDEX idx_reserva_huesped_creada
  ON reserva (id_huesped, creada_en DESC);

-- Agregados por valoración
CREATE INDEX idx_resena_valoracion
  ON resena (valoracion);