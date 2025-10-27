-- ============================================
-- CREACIÓN DE ESQUEMA: CLIENTES, PROVEEDORES, PRODUCTOS Y VENTAS
-- ============================================

-- TABLA CLIENTE
CREATE TABLE Cliente (
    cliente_id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    telefono TEXT,
    email TEXT
);

-- TABLA PROVEEDOR
CREATE TABLE Proveedor (
    proveedor_id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    telefono TEXT,
    email TEXT
);

-- TABLA PRODUCTO
CREATE TABLE Producto (
    producto_id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    precio_unitario REAL NOT NULL,
    proveedor_id INTEGER NOT NULL,
    FOREIGN KEY (proveedor_id) REFERENCES Proveedor(proveedor_id)
);

-- TABLA VENTA (cabecera de cada venta)
CREATE TABLE Venta (
    venta_id INTEGER PRIMARY KEY,
    fecha_venta TEXT NOT NULL,
    cliente_id INTEGER NOT NULL,
    total_venta REAL,
    FOREIGN KEY (cliente_id) REFERENCES Cliente(cliente_id)
);

-- TABLA VENTA_DETALLE (detalle de cada venta)
CREATE TABLE VentaDetalle (
    venta_detalle_id INTEGER PRIMARY KEY,
    venta_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario REAL NOT NULL,
    subtotal REAL NOT NULL,
    FOREIGN KEY (venta_id) REFERENCES Venta(venta_id),
    FOREIGN KEY (producto_id) REFERENCES Producto(producto_id)
);

-- ============================================
-- INSERCIÓN DE DATOS DE PRUEBA
-- ============================================

-- CLIENTES
INSERT INTO Cliente (cliente_id, nombre, telefono, email) VALUES
(1, 'Ana Pérez', '600111222', 'ana.perez@email.com'),
(2, 'Luis Gómez', '600333444', 'luis.gomez@email.com'),
(3, 'María López', '600555666', 'maria.lopez@email.com'),
(4, 'Carlos Ruiz', '600777888', 'carlos.ruiz@email.com'),
(5, 'Laura Sánchez', '600999000', 'laura.sanchez@email.com'),
(6, 'Pedro Torres', '601111222', 'pedro.torres@email.com'),
(7, 'Sofía Morales', '601333444', 'sofia.morales@email.com'),
(8, 'Javier Díaz', '601555666', 'javier.diaz@email.com'),
(9, 'Elena Castro', '601777888', 'elena.castro@email.com'),
(10, 'Miguel Ramos', '601999000', 'miguel.ramos@email.com');

-- PROVEEDORES
INSERT INTO Proveedor (proveedor_id, nombre, telefono, email) VALUES
(1, 'Distribuciones Norte', '942111111', 'contacto@norte.com'),
(2, 'Alimentos La Huerta', '942222222', 'info@lahuerta.com'),
(3, 'Suministros Cantabria', '942333333', 'ventas@cantabria.com'),
(4, 'Bebidas del Sur', '942444444', 'ventas@bebidassur.com'),
(5, 'TecnoMarket', '942555555', 'info@tecnomarket.com'),
(6, 'Frutas Selectas', '942666666', 'info@frutasselectas.com'),
(7, 'Carnes Premium', '942777777', 'contacto@carnespremium.com'),
(8, 'Café Altura', '942888888', 'info@cafealtura.com'),
(9, 'Panadería Moderna', '942999999', 'ventas@panaderia.com'),
(10, 'Quesos del Valle', '942000000', 'info@quesosvalle.com');

-- PRODUCTOS
INSERT INTO Producto (producto_id, nombre, precio_unitario, proveedor_id) VALUES
(1, 'Pan integral', 1.50, 9),
(2, 'Leche entera', 0.95, 1),
(3, 'Café molido', 4.50, 8),
(4, 'Queso manchego', 6.80, 10),
(5, 'Jamón ibérico', 12.50, 7),
(6, 'Manzanas', 2.20, 6),
(7, 'Refresco cola', 1.10, 4),
(8, 'Aceite de oliva', 5.90, 2),
(9, 'Tablet 10 pulgadas', 180.00, 5),
(10, 'Arroz redondo', 1.30, 3);

-- VENTAS
INSERT INTO Venta (venta_id, fecha_venta, cliente_id, total_venta) VALUES
(1, '2025-10-01', 1, 20.60),
(2, '2025-10-02', 2, 15.50),
(3, '2025-10-02', 3, 32.80),
(4, '2025-10-03', 4, 12.95),
(5, '2025-10-04', 5, 8.75),
(6, '2025-10-05', 6, 25.40),
(7, '2025-10-06', 7, 10.60),
(8, '2025-10-07', 8, 9.70),
(9, '2025-10-08', 9, 16.50),
(10, '2025-10-09', 10, 22.10);

-- VENTAS DETALLE
INSERT INTO VentaDetalle (venta_detalle_id, venta_id, producto_id, cantidad, precio_unitario, subtotal) VALUES
(1, 1, 1, 4, 1.50, 6.00),
(2, 1, 3, 2, 4.50, 9.00),
(3, 1, 7, 5, 1.10, 5.50),
(4, 2, 6, 3, 2.20, 6.60),
(5, 2, 2, 5, 0.95, 4.75),
(6, 3, 4, 2, 6.80, 13.60),
(7, 3, 5, 1, 12.50, 12.50),
(8, 4, 8, 2, 5.90, 11.80),
(9, 5, 10, 5, 1.30, 6.50),
(10, 6, 9, 1, 180.00, 180.00);

-- ============================================
-- Puedes probar este modelo en https://sqliteonline.com
-- Ejecuta todo el script y luego prueba consultas como:
-- SELECT * FROM VentaDetalle;
-- SELECT c.nombre, v.fecha_venta, v.total_venta
-- FROM Cliente c JOIN Venta v ON c.cliente_id = v.cliente_id;
-- ============================================
