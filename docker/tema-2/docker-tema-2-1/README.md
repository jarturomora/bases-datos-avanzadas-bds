# Descripción del entorno Docker para el Tema 2 - Clase 1: Laboratorio MySQL (Tienda)

## Objetivo del entorno

Este entorno Docker se ha preparado como **laboratorio básico de MySQL** para trabajar con:

* Creación de esquemas y carga inicial de datos.
* Ejecución de consultas SQL desde **phpMyAdmin**.
* Prácticas sobre tablas de un dominio sencillo (una tienda).
* Aprendizaje sin necesidad de instalar MySQL localmente.

El entorno está pensado para que puedas **arrancar, detener y reiniciar** la base de datos de forma controlada durante las prácticas.

## Servicios incluidos

El entorno está compuesto por **dos servicios Docker** definidos mediante *Docker Compose*.


### 1) Servicio MySQL

* Imagen: `mysql:9.0`
* Contenedor: `mysql_lab`
* Base de datos inicial: `tienda`
* Usuarios configurados:

  * `root / root`
  * `alumno / alumno`

Este contenedor:

* Arranca MySQL automáticamente.
* Crea la base de datos `tienda`.
* Ejecuta los scripts SQL de inicialización al arrancar por primera vez.

Los scripts SQL se cargan desde un volumen local.

### 2) Servicio phpMyAdmin

* Imagen: `phpmyadmin:latest`
* Contenedor: `pma_lab`
* Puerto expuesto: **8080**

phpMyAdmin se conecta automáticamente al servicio MySQL y permite:

* Explorar tablas.
* Ejecutar consultas SQL.
* Visualizar resultados sin usar consola.

## Estructura de directorios del proyecto

```text
docker-tema-2-1/
├── docker-compose.yml
└── initdb/
    └── 001_schema_and_seed.sql
```

### Descripción de los ficheros

* **docker-compose.yml**
  Define los contenedores de MySQL y phpMyAdmin, así como usuarios, contraseñas y dependencias.

* **initdb/001_schema_and_seed.sql**
  Script que:

  * Crea las tablas del modelo de datos de la tienda.
  * Inserta los datos iniciales necesarios para la práctica.

> Todos los scripts ubicados en la carpeta `initdb/` se ejecutan automáticamente la **primera vez** que se levanta el entorno.

## Requisitos previos

Antes de iniciar el laboratorio, asegúrate de tener:

* **Docker Desktop** instalado y en ejecución.
* **Visual Studio Code**.
* La extensión de VS Code **Container Tools** instalada.

## Cómo iniciar el entorno desde Visual Studio Code

### Paso 1: Abrir el proyecto

1. Abre **Visual Studio Code**.
2. Selecciona **File → Open Folder**.
3. Abre la carpeta del laboratorio (por ejemplo, `docker-tema-2-1`).

### Paso 2: Arrancar los contenedores con Container Tools

1. Abre la vista **Container Tools** en la barra lateral de VS Code.
2. Localiza el archivo `docker-compose.yml`.
3. Haz clic derecho sobre él.
4. Selecciona **Compose Up**.

Durante el arranque:

* Docker descargará las imágenes necesarias (si no existen).
* Se iniciará MySQL.
* Se ejecutará automáticamente el script `001_schema_and_seed.sql`.

### Paso 3: Acceder a phpMyAdmin

Una vez los contenedores estén en ejecución:

* Abre el navegador y accede a:
  **[http://localhost:8080](http://localhost:8080)**

Credenciales recomendadas para la práctica:

* **Usuario**: `alumno`
* **Contraseña**: `alumno`
* **Base de datos**: `tienda`

Desde phpMyAdmin podrás ejecutar las consultas que se indiquen en la práctica o en clase.

## Cómo detener el entorno

Desde Visual Studio Code:

1. Abre **Container Tools**.
2. Haz clic derecho sobre `docker-compose.yml`.
3. Selecciona **Compose Down**.

Esto detiene los contenedores.
Si vuelves a ejecutar **Compose Up**, la base de datos se inicializará de nuevo si no existe volumen persistente.
