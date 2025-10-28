-- Listar todos los clientes
SELECT * FROM cliente;

-- Listar todos los clientes ordenados alfabéticamente por su nombre
SELECT cliente_id, nombre, telefono, email
FROM Cliente
ORDER BY nombre ASC;

-- Mostrar los productos con precio superior a 5 euros
SELECT producto_id, nombre, precio_unitario
FROM Producto
WHERE precio_unitario > 5.00
ORDER BY precio_unitario DESC;

-- Calcular el número total de ventas registradas y el promedio de su importe
SELECT 
    COUNT(venta_id) AS total_ventas,
    ROUND(AVG(total_venta), 2) AS promedio_importe
FROM Venta;

-- Listar los nombres de los clientes junto con las fechas y totales de sus ventas
SELECT c.nombre, v.fecha_venta, v.total_venta
FROM Cliente c JOIN Venta v ON c.cliente_id = v.cliente_id;

-- Detalles de las compras realizadas por un cliente concreto (por ejemplo, cliente_id = 3)
SELECT 
    c.nombre AS cliente,
    v.venta_id,
    v.fecha_venta,
    p.nombre AS producto,
    vd.cantidad,
    vd.precio_unitario,
    vd.subtotal
FROM Cliente c
JOIN Venta v ON c.cliente_id = v.cliente_id
JOIN VentaDetalle vd ON v.venta_id = vd.venta_id
JOIN Producto p ON vd.producto_id = p.producto_id
WHERE c.cliente_id = 1
ORDER BY v.fecha_venta;