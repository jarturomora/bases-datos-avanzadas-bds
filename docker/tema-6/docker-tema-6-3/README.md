# Entorno Docker para el Tema 6 - Clase 3: Aggregation Pipeline y Map-Reduce en MongoDB

## Objetivo del repositorio

Este repositorio contiene el material necesario para ejecutar una **demo práctica de MongoDB** sobre un escenario de **comercio electrónico tipo Amazon**, utilizando **Docker** y **MongoDB Compass**.

El objetivo es que el alumno:

* comprenda cómo se organiza un proyecto con Docker,
* identifique el papel de cada archivo y carpeta,
* y pueda ejecutar el entorno de forma sencilla y reproducible.

## Estructura de directorios

```text
docker-tema-6-3/
│
├── docker-compose.yml
└── init/
    ├── init.sh
    └── seed.js
```

## Descripción de cada componente

### `docker-compose.yml`

Archivo principal de configuración de Docker.

* Define los contenedores que se ejecutan (MongoDB, inicialización, etc.).
* Configura puertos, volúmenes y dependencias.
* Permite levantar todo el entorno con un único comando (`docker compose up`).

### Carpeta `init/`

Contiene los scripts de **inicialización del entorno**.

Se separa claramente:

* **infraestructura** (arranque del replica set),
* y **datos** (creación del dataset).

### `init/init.sh`

Script de inicialización del entorno MongoDB.

* Espera a que MongoDB esté disponible.
* Inicializa el **replica set** (necesario para transacciones).
* Lanza el script de carga de datos.

Este script se ejecuta **automáticamente** al arrancar Docker.

### `init/seed.js`

Script de carga de datos de prueba.

* Crea la base de datos `shop`.
* Genera miles de productos, cientos de clientes y miles de pedidos.
* Crea índices para mejorar las consultas.
* Deja la base de datos lista para usar desde MongoDB Compass.
