# Descripción del entorno Docker del Tema 2 - Clase 3

## Objetivo del entorno

Este entorno Docker se ha preparado para realizar una **demostración práctica de rendimiento en MySQL 9**, centrada en:

* Definición de **índices simples y compuestos**.
* Uso de la cláusula **`EXPLAIN` y `EXPLAIN ANALYZE`**.
* Lectura e interpretación de **planes de ejecución**.
* Comparación de latencia antes y después de indexar tablas con **grandes volúmenes de datos**.
* Observación indirecta de efectos sobre **CPU, E/S y caché**.

El alumno puede ejecutar toda la práctica **sin instalar MySQL localmente**, utilizando únicamente Docker y phpMyAdmin.

## Servicios incluidos

El entorno está compuesto por **dos contenedores Docker**, definidos mediante *Docker Compose*.

### 1) Servicio MySQL 9

* **Imagen**: `mysql:9.0`
* **Motor**: InnoDB
* **Base de datos**: `ecommerce`
* **Usuarios**:

  * `root / root`
  * `alumno / alumno`

Este contenedor:

* Arranca MySQL 9 con parámetros optimizados para la demo.
* Inicializa automáticamente el esquema.
* Carga un **dataset sintético parametrizable** (100k / 1M / 5M pedidos).
* Almacena los datos en un volumen Docker persistente.

### 2) Servicio phpMyAdmin

* **Imagen**: `phpmyadmin:latest`
* **Puerto expuesto**: `8080`

phpMyAdmin permite:

* Ejecutar consultas SQL.
* Lanzar `EXPLAIN` y `EXPLAIN ANALYZE`.
* Visualizar resultados y planes de ejecución de forma gráfica.
* Trabajar sin usar línea de comandos.

## Estructura de directorios del proyecto

```text
docker-tema-2-3/
├── docker-compose.yml
└── initdb/
    ├── 001_schema.sql
    └── 002_seed.sql
```

### Descripción de los ficheros

* **docker-compose.yml**
  Define los servicios de MySQL 9 y phpMyAdmin, así como los puertos, usuarios y volúmenes.

* **001_schema.sql**
  Crea la base de datos y la tabla `pedidos`.

* **002_seed.sql**
  Genera datos sintéticos de forma reproducible, ajustando el volumen mediante una variable:

  * 100.000
  * 1.000.000
  * 5.000.000 registros

> Todos los scripts ubicados en `initdb/` se ejecutan automáticamente **la primera vez** que se levanta el entorno.

## Requisitos previos

Antes de iniciar la demo, necesitas:

* **Docker Desktop** instalado y en ejecución.
* **Visual Studio Code**.
* La extensión de VS Code **Container Tools** instalada.

## Cómo iniciar el entorno desde Visual Studio Code

### Paso 1: Abrir el proyecto

1. Abre **Visual Studio Code**.
2. Selecciona **File → Open Folder**.
3. Abre la carpeta `docker-tema-2-3`.

### Paso 2: Arrancar los contenedores con Container Tools

1. Abre la vista **Container Tools** en la barra lateral de VS Code.
2. Localiza el archivo `docker-compose.yml`.
3. Haz clic derecho sobre él.
4. Selecciona **Compose Up**.

Durante el arranque:

* Docker descargará las imágenes necesarias.
* MySQL inicializará el esquema y los datos.
* phpMyAdmin quedará disponible para su uso.

### Paso 3: Acceder a phpMyAdmin

Una vez los contenedores estén en ejecución:

* Abre tu navegador y accede a:
  **[http://localhost:8080](http://localhost:8080)**

Credenciales:

* **Usuario**: `alumno`
* **Contraseña**: `alumno`
* **Base de datos**: `ecommerce`

Desde phpMyAdmin podrás copiar y pegar directamente las consultas del guion de la práctica.

## Cómo detener el entorno

Desde Visual Studio Code:

1. Abre **Container Tools**.
2. Haz clic derecho sobre `docker-compose.yml`.
3. Selecciona **Compose Down**.

Los contenedores se detienen, pero los datos permanecen gracias al volumen Docker.
