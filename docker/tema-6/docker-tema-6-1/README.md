# Entorno Docker para el Tema 6 - Clase 1: Operaciones de inserción y lectura

## Objetivo del proyecto

Este proyecto utiliza **Docker** para levantar un entorno completo que permite trabajar con **MongoDB** y realizar una demo práctica sobre una base de datos que simula **exchange de criptomonedas**.

El objetivo es que el alumno:

* entienda cómo se organiza un proyecto con Docker,
* identifique el papel de cada archivo y carpeta,
* y pueda ejecutar el entorno sin configuraciones manuales complejas.

## Estructura de directorios

```text
docker-tema-6-1/
│
├── docker-compose.yml
└── init/
    └── init.js
```

## Descripción de cada componente

### `docker-compose.yml`

Es el **archivo principal del proyecto**.

* Define los contenedores que se van a ejecutar.
* Indica qué imagen usar (MongoDB).
* Configura puertos, volúmenes y variables de entorno.
* Permite levantar todo el entorno con un solo comando.

### Carpeta `init/`

Contiene los **scripts de inicialización** de la base de datos.

Estos scripts se ejecutan **automáticamente** cuando el contenedor de MongoDB se inicia por primera vez.

#### `init/init.js`

Script de JavaScript que se ejecuta dentro de MongoDB al arrancar.

* Crea la base de datos del ejercicio.
* Define las colecciones necesarias.
* Inserta datos de prueba (usuarios, órdenes, trades, etc.).
* Deja la base de datos lista para usar desde MongoDB Compass.
