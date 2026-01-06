# Entorno Docker para el Tema 5 - Clase 3: Primer CRUD con MongoDB

## Objetivo del ejercicio

Este ejercicio despliega un **entorno MongoDB completamente funcional** mediante Docker para trabajar con un **catálogo de productos**, clientes y compras.

El objetivo es que el alumno:

* explore un **modelo de datos NoSQL basado en documentos**,
* realice consultas, inserciones, actualizaciones y borrados **MongoDB Compass**.

Todo el entorno está preparado para funcionar **sin instalaciones manuales**.

## Estructura de directorios del proyecto

```text
docker-tema-5-2/
│
├── docker-compose.yml
│
└── mongo/
    └── init.js
```

### Descripción

* **`docker-compose.yml`**
  Define los servicios Docker y la red del entorno.

* **`init.js`**
  Script de inicialización de MongoDB:

  * crea datos,
  * define índices,
  * deja el sistema listo para usar.

## Servicios definidos en el `docker-compose`

El archivo `docker-compose.yml` define los contenedores necesarios para el ejercicio.

### Servicio `mongodb`

**Rol:** Base de datos NoSQL (MongoDB)

* Utiliza la imagen oficial de MongoDB.
* Expone el puerto estándar para permitir la conexión desde MongoDB Compass.
* Ejecuta automáticamente un script de inicialización (`init.js`) al arrancar.

Este contenedor es el **núcleo del ejercicio**, ya que contiene:

* la base de datos `catalogo`,
* las colecciones,
* los datos de prueba,
* y los índices.

## Script de inicialización (`init.js`)

Al arrancar el contenedor de MongoDB, se ejecuta automáticamente el script `init.js`, que realiza las siguientes tareas :

### 1. Creación de la base de datos

```text
Base de datos: catalogo
```

### 2. Creación de colecciones

Se crean las siguientes colecciones:

* `categorias`
* `productos`
* `clientes`
* `compras`

Cada colección representa una entidad típica de un sistema de comercio.

### 3. Inserción de datos de prueba

El script genera un volumen de datos realista:

* **20 categorías**
* **2.000 clientes**
* **10.000 productos**
* **50.000 compras**

Estos datos permiten:

* probar búsquedas,
* realizar agregaciones,
* y analizar rendimiento de consultas.

### 4. Modelo de documentos (visión general)

* `productos`
  Contiene información del producto, categoría, precio y stock.

* `clientes`
  Representa usuarios del sistema con email y fecha de alta.

* `compras`
  Cada documento representa una **línea de compra**, con:

  * cliente,
  * producto,
  * cantidad,
  * precio,
  * fecha.

📌 Observa que en MongoDB **no hay joins automáticos** como en SQL; las relaciones se representan mediante identificadores.

### 5. Creación de índices

El script define índices equivalentes a los que se usarían en un sistema real:

* Búsquedas por categoría
* Búsquedas por texto en nombre de producto
* Unicidad de SKU y email
* Acceso rápido por cliente y producto en compras

Esto permite comparar:

* consultas sin índice,
* consultas optimizadas.
