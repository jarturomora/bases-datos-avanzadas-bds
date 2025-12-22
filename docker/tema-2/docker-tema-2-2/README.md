# Descripción del entorno Docker de la demo para el Tema 2 - Clase 2

## Objetivo del entorno

Este entorno Docker se ha preparado para que puedas ejecutar, de forma local y reproducible, una demostración sobre:

* Ejecución de consultas SQL en **MySQL 9**
* Análisis del rendimiento mediante `EXPLAIN` y `EXPLAIN ANALYZE`
* Uso de índices sobre un dataset de gran tamaño
* Ejecución de consultas desde **phpMyAdmin**, sin necesidad de instalar MySQL en tu equipo

Todo el entorno se levanta con un único comando.

## Servicios incluidos

El entorno consta de **dos contenedores Docker**:

### 1) MySQL 8

* Motor de base de datos.
* Contiene la base de datos `demo`.
* Carga automáticamente:

  * la estructura de tablas,
  * el dataset sintético,
  * y los scripts de la demostración.

### 2) phpMyAdmin

* Interfaz web para ejecutar consultas SQL.
* Permite lanzar `EXPLAIN ANALYZE` y ver resultados de forma visual.
* Se conecta automáticamente al contenedor de MySQL.

## Estructura de directorios del proyecto

```text
docker-tema-2-2/
├── docker-compose.yml
└── mysql/
    └── init/
        ├── 01_schema.sql
        └── 02_seed.sql
```

### Descripción de los ficheros

* **docker-compose.yml**
  Define los servicios de MySQL y phpMyAdmin, así como los puertos y volúmenes.

* **01_schema.sql**
  Crea la base de datos y la tabla `users`.

* **02_seed.sql**
  Genera el dataset sintético (≈ 1 millón de registros).

> Todos los ficheros `.sql` dentro de `mysql/init/` se ejecutan automáticamente la primera vez que se levanta el entorno.

## Requisitos previos

Antes de empezar, necesitas:

* **Docker Desktop** instalado y en ejecución.
* **Visual Studio Code**.
* La extensión de VS Code **Container Tools** instalada.

## Cómo iniciar la demo desde Visual Studio Code

### Paso 1: Abrir el proyecto

1. Abre **Visual Studio Code**.
2. Selecciona **File → Open Folder**.
3. Abre la carpeta `docker-tema-2-2`.

### Paso 2: Iniciar los contenedores con Container Tools

1. Abre la vista **Container Tools** en la barra lateral de VS Code.
2. Localiza el archivo `docker-compose.yml`.
3. Haz clic derecho sobre él.
4. Selecciona **Compose Up**.

VS Code:

* Descargará las imágenes necesarias (la primera vez).
* Creará los contenedores.
* Inicializará la base de datos y cargará los datos.

Este proceso puede tardar unos minutos la primera vez.

### Paso 3: Acceder a phpMyAdmin

Una vez los contenedores estén en ejecución:

* Abre tu navegador y accede a:
  **[http://localhost:8080](http://localhost:8080)**

Credenciales:

* **Usuario**: `root`
* **Contraseña**: `root`

Base de datos:

* `demo`

Desde phpMyAdmin podrás copiar y pegar directamente las consultas del guion de la práctica.

## Cómo detener el entorno

Desde VS Code:

1. Abre **Container Tools**.
2. Localiza el `docker-compose.yml`.
3. Haz clic derecho y selecciona **Compose Down**.

Esto detiene los contenedores, pero **los datos se conservan** gracias al volumen Docker.
