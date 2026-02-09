-- Esquema RBnB (PostgreSQL) - Nombres en español
-- Nota: usa UUID + pgcrypto

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------
-- Ubicación (normalizado)
-- -------------------------
CREATE TABLE pais (
  codigo_pais CHAR(2) PRIMARY KEY,
  nombre TEXT NOT NULL
);

CREATE TABLE ciudad (
  id_ciudad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo_pais CHAR(2) NOT NULL REFERENCES pais(codigo_pais),
  nombre TEXT NOT NULL
);

-- -------------------------
-- Usuarios y roles (anfitrión / huésped)
-- -------------------------
CREATE TABLE usuario (
  id_usuario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  correo TEXT NOT NULL UNIQUE,
  nombre_completo TEXT NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE anfitrion (
  id_anfitrion UUID PRIMARY KEY REFERENCES usuario(id_usuario),
  superanfitrion BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE huesped (
  id_huesped UUID PRIMARY KEY REFERENCES usuario(id_usuario),
  telefono TEXT
);

-- -------------------------
-- Apartamentos y calendario diario
-- -------------------------
CREATE TABLE apartamento (
  id_apartamento UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_anfitrion UUID NOT NULL REFERENCES anfitrion(id_anfitrion),
  id_ciudad UUID NOT NULL REFERENCES ciudad(id_ciudad),
  titulo TEXT NOT NULL,
  direccion TEXT NOT NULL,
  max_huespedes INT NOT NULL CHECK (max_huespedes > 0),
  precio_base_eur NUMERIC(10,2) NOT NULL CHECK (precio_base_eur >= 0),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Calendario diario (disponibilidad + precio por día)
CREATE TABLE apartamento_dia (
  id_apartamento UUID NOT NULL REFERENCES apartamento(id_apartamento) ON DELETE CASCADE,
  dia DATE NOT NULL,
  disponible BOOLEAN NOT NULL DEFAULT true,
  precio_eur NUMERIC(10,2) NOT NULL CHECK (precio_eur >= 0),
  PRIMARY KEY (id_apartamento, dia)
);

-- -------------------------
-- Reservas, pagos y reseñas
-- -------------------------
CREATE TYPE estado_reserva AS ENUM ('PENDIENTE','CONFIRMADA','CANCELADA','COMPLETADA');

CREATE TABLE reserva (
  id_reserva UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_apartamento UUID NOT NULL REFERENCES apartamento(id_apartamento),
  id_huesped UUID NOT NULL REFERENCES huesped(id_huesped),
  fecha_entrada DATE NOT NULL,
  fecha_salida DATE NOT NULL,
  estado estado_reserva NOT NULL,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (fecha_entrada < fecha_salida)
);

CREATE TYPE estado_pago AS ENUM ('INICIADO','PAGADO','REEMBOLSADO','FALLIDO');

-- Pago 1:1 con reserva (simplificado)
CREATE TABLE pago (
  id_reserva UUID PRIMARY KEY REFERENCES reserva(id_reserva) ON DELETE CASCADE,
  importe_eur NUMERIC(10,2) NOT NULL CHECK (importe_eur >= 0),
  estado estado_pago NOT NULL,
  pagado_en TIMESTAMPTZ
);

-- Reseña: 1 por reserva (normalmente al completar)
CREATE TABLE resena (
  id_resena UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_reserva UUID UNIQUE NOT NULL REFERENCES reserva(id_reserva) ON DELETE CASCADE,
  valoracion INT NOT NULL CHECK (valoracion BETWEEN 1 AND 5),
  comentario TEXT,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);