# Guía didáctica Tema 5 - Clase 3: Operaciones CRUD en MongoDB

## Objetivo

El objetivo de esta práctica es que el alumno aprenda a realizar **operaciones básicas sobre una base de datos MongoDB** utilizando **MongoDB Compass**, sin escribir código de backend.

Trabajaremos sobre las colecciones existentes:

* `productos`
* `clientes`
* `compras`

y realizaremos operaciones de:

* **Creación (Create)**
* **Lectura (Read)**
* **Actualización (Update)**
* **Eliminación (Delete)**

## Herramienta utilizada

Todas las operaciones se realizarán con **MongoDB Compass**, usando:

* la vista **Documents** (Filter / Insert Document),
* y, cuando sea necesario, **Open MongoDB Shell**.

## 1. Crear documentos (Create)

### 1.1 Crear un nuevo producto

En Compass:

1. Abre la colección `productos`.
2. Pulsa **ADD Data → Insert Document**.
3. Inserta el siguiente documento:

```json
{
  "_id": 20001,
  "nombre": "Teclado Mecánico Pro",
  "categoriaId": 3,
  "precio": 129.99,
  "stock": 50
}
```

Pulsa **Insert**.

### Qué observar

* El documento se guarda directamente en formato JSON.
* No es necesario definir previamente un esquema.

### 1.2 Crear un nuevo cliente

Colección `clientes` → **ADD Data → Insert Document**:

```json
{
  "_id": 3001,
  "nombre": "Laura Gómez",
  "email": "laura.gomez@example.com",
  "fechaAlta": new Date()
}
```

### Qué observar

* Los documentos pueden tener fechas y tipos complejos.
* MongoDB no requiere claves foráneas explícitas.

## 2. Leer datos (Read)

### 2.1 Consultar productos de una categoría

Colección `productos` → **Filter**:

```javascript
{ categoriaId: 3 }
```

### Qué observar

* El filtro se expresa como un objeto JSON.
* Es equivalente a un `WHERE` en SQL.

### 2.2 Ver compras realizadas por un cliente concreto

Colección `compras` → **Filter**:

```javascript
{ clienteId: 1 }
```

Opcional, en **Sort**:

```javascript
{ compradoEn: -1 }
```

### Qué observar

* Se pueden combinar filtros y ordenaciones sin escribir SQL.
* Los resultados son documentos completos.

## 3. Actualizar documentos (Update)

### 3.1 Actualizar el stock de un producto

Colección `productos` → **Filter**:

```javascript
{ _id: 2001 }
```

Pulsa **Update** y selecciona **Update Document**, usando:

```javascript
{
  $inc: { stock: -5 }
}
```

### Qué observar

* `$inc` permite modificar valores sin reescribir todo el documento.
* Las operaciones son atómicas a nivel de documento.

### 3.2 Actualizar el email de un cliente

Colección `clientes` → **Filter**:

```javascript
{ _id: 3001 }
```

**Update Document**:

```javascript
{
  $set: { email: "laura.gomez@nuevoemail.com" }
}
```

### Qué observar

* `$set` actualiza solo los campos indicados.
* No se afecta el resto del documento.

## 4. Eliminar documentos (Delete)

### 4.1 Comprobar si un producto tiene compras asociadas

Antes de borrar, **siempre se debe comprobar**.

Colección `compras` → **Filter**:

```javascript
{ productoId: 302 }
```

Otra alternativa desde MongoDB Shell es:

```javascript
db.compras.countDocuments({ productoId: 20001 })
```

Si **no devuelve resultados**, el producto no tiene compras.

### 4.2 Eliminar un producto sin compras

Colección `productos` → **Filter**:

```javascript
{ _id: 302 }
```

Pulsa **Delete Document**.

### Qué observar

* MongoDB **no impide automáticamente** borrar documentos relacionados.
* La integridad referencial debe gestionarse desde la aplicación o el diseño.

## Ideas clave para reflexionar

MongoDB permite trabajar de forma muy directa con los datos, pero esa flexibilidad implica **mayor responsabilidad en el diseño y en las operaciones**.

En sistemas reales es crítico considerar:

* las validaciones,
* las reglas de negocio,
* y las relaciones
  se controlan principalmente desde la aplicación.
