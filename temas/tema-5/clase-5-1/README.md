# Guía didáctica del Tema 5 - Clase 1: Primeros pasos con MongoDB

## Objetivo

En esta parte de la práctica vamos a realizar **consultas sencillas en MongoDB** utilizando **MongoDB Compass**, y las compararemos con sus **equivalentes en SQL**.

El objetivo no es aprender sintaxis avanzada, sino:

* entender **cómo se consulta un modelo basado en documentos**,
* y comparar ese enfoque con el **modelo relacional tradicional**.

Todas las consultas se realizarán desde:

* **MongoDB Compass**

  * sección **Documents** (Filter / Sort)
  * o **Open Mongosh**

### Arranque y conexión

Utiliza la extensión "Container Tools" de VS Code para iniciar los contenedores, o ejecutar el siguiente comando desde el directorio del proyecto (en Windows se debe utilizar un terminal de WSL -Windows Subsystem Linux-):

```bash
docker compose up -d
```

## 1. Ver documentos de una colección

### MongoDB (Compass → Open Mongosh)

```javascript
db.productos.find().limit(5)
```

### Qué hace

* Accede a la colección `productos`.
* Muestra **solo 5 documentos** para evitar una salida demasiado grande.

### Qué deben observar

* Cada registro es un **documento JSON**.
* No existen filas ni columnas fijas como en SQL.
* Los campos se leen como propiedades de un objeto.

### Equivalente en SQL (PostgreSQL)

```sql
SELECT * 
FROM productos
LIMIT 5;
```

### Idea clave

* MongoDB devuelve **documentos completos**, mientras que SQL devuelve **filas de una tabla**.
* El objetivo es el mismo, pero el formato y el modelo de datos son distintos.

## 2. Filtrar documentos por una condición

### MongoDB (Compass → Collection `compras` → Documents → Filter)

```javascript
{ clienteId: 1 }
```

### Qué hace

* Filtra las compras realizadas por el **cliente con id 1**.

Opcional, para ordenar por fecha (campo **Sort** en Compass):

```javascript
{ compradoEn: -1 }
```

### Qué deben observar

* El filtro se expresa como un **objeto JSON**.
* No hay cláusula `WHERE`, sino pares `campo: valor`.

### Equivalente en SQL

```sql
SELECT *
FROM compras
WHERE cliente_id = 1
ORDER BY comprado_en DESC;
```

### Idea clave

* En MongoDB, las condiciones se expresan como **estructuras de datos**, no como texto SQL.

## 3. Contar documentos que cumplen una condición

### MongoDB (Compass → Open MongoDB Shell)

```javascript
db.compras.countDocuments({ productoId: 3 })
```

### Qué hace

* Cuenta cuántas compras existen del **producto 3**.
* Devuelve un único número.

### Qué deben observar

* No se devuelven documentos, solo el **resultado agregado**.
* El filtro vuelve a expresarse como JSON.

### Equivalente en SQL

```sql
SELECT COUNT(*)
FROM compras
WHERE producto_id = 3;
```

## 4. Calcular el total de ventas de un producto

### MongoDB (Compass → Collection `compras` → Aggregations)

```javascript
[
  { $match: { productoId: 3 } },
  {
    $group: {
      _id: "$productoId",
      unidadesVendidas: { $sum: "$cantidad" },
      totalVentas: { $sum: { $multiply: ["$cantidad", "$precioUnitario"] } }
    }
  }
]
```

### Qué hace

* Filtra las compras del producto 3.
* Agrupa los resultados.
* Calcula:

  * unidades vendidas,
  * importe total de ventas.

### Equivalente en SQL

```sql
SELECT
  producto_id,
  SUM(cantidad) AS unidades_vendidas,
  SUM(cantidad * precio_unitario) AS total_ventas
FROM compras
WHERE producto_id = 3
GROUP BY producto_id;
```

### Idea clave

* En MongoDB las agregaciones se expresan como **pipelines de etapas**.
* Por otro lado en SQL se usan **funciones agregadas y GROUP BY**.

## Conclusiones

* **MongoDB** y **SQL** permiten resolver los **mismos problemas**, pero:

  * MongoDB trabaja con **documentos y filtros JSON**,
  * SQL trabaja con **tablas y sentencias declarativas**.
* El cambio principal no es solo de sintaxis, sino de **modelo lógico**.
