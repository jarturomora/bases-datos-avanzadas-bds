# Entorno Docker para el Tema 4 - Clase 3: Comparación práctica SQL vs NoSQL

## Objetivo del entorno

Este proyecto utiliza **Docker Compose** para levantar un entorno completo que permite comparar, de forma controlada, una base de datos **relacional (PostgreSQL)** y una base de datos **NoSQL (MongoDB)** ejecutando el mismo escenario y el mismo conjunto de operaciones.

El entorno está diseñado para:

* ser reproducible,
* funcionar en cualquier equipo,
* y evitar instalaciones manuales complejas.

## Estructura de directorios del proyecto

El proyecto está organizado en carpetas para separar claramente responsabilidades: configuración, datos, y ejecución de la práctica.

```text
docker-tema-4-3/
│
├── docker-compose.yml
│
├── postgres/
│   ├── 01_schema.sql
│   └── 02_seed.sql
│
├── mongo/
│   └── init.js
│
└── bench/
    ├── Dockerfile
    ├── requirements.txt
    └── SQL_vs_NoSQL_Benchmark.ipynb
```

## Servicios incluidos en el `docker-compose`

El archivo `docker-compose.yml` define varios **servicios independientes**, cada uno con un propósito concreto dentro de la práctica.

---

### 1. Servicio `postgres`

**Rol:** Base de datos relacional (SQL)

* Utiliza la imagen oficial de PostgreSQL.
* Contiene las tablas:

  * `categorias`
  * `productos`
  * `clientes`
  * `compras`
* Al iniciarse, ejecuta automáticamente los scripts SQL:

  * `01_schema.sql`: creación del esquema,
  * `02_seed.sql`: carga de datos de prueba.

**Por qué es importante**

* Representa el enfoque clásico **relacional**:
  * esquema fijo,
  * claves foráneas,
  * integridad gestionada por el motor.

### 2. Servicio `pgadmin`

**Rol:** Interfaz gráfica para PostgreSQL

* Permite explorar la base de datos PostgreSQL desde el navegador.
* Facilita:

  * ver tablas,
  * ejecutar consultas SQL,
  * inspeccionar datos sin usar la línea de comandos.

**Uso en la práctica**

* Comparar cómo se consulta el mismo modelo de datos en SQL.
* Visualizar el esquema relacional.

### 3. Servicio `mongodb`

**Rol:** Base de datos NoSQL orientada a documentos

* Utiliza la imagen oficial de MongoDB.
* Al iniciarse, ejecuta un script de inicialización que crea:

  * colecciones equivalentes a las tablas SQL,
  * datos de prueba en formato JSON.

**Por qué es importante**

* Representa el enfoque **NoSQL**:

  * documentos flexibles,
  * ausencia de joins obligatorios,
  * modelo más cercano a la aplicación.

### 4. Servicio `jupyter`

**Rol:** Ejecución del benchmark paso a paso

* Ejecuta un **Jupyter Notebook** en el navegador.
* Desde el notebook se realizan:

  * pruebas de rendimiento,
  * mediciones de latencia y throughput,
  * microbenchmarks por tipo de operación.

**Por qué es clave**

* Permite ejecutar la práctica de forma guiada.
* El código se ejecuta **paso a paso**, no como una “caja negra”.
* Incluye explicaciones didácticas y preguntas de reflexión.

## Cómo se comunican los servicios

* Todos los servicios están en la **misma red Docker**.
* Se comunican usando el **nombre del servicio** como hostname:

  * `postgres` para PostgreSQL,
  * `mongodb` para MongoDB.
* El alumno **no necesita configurar conexiones manuales**.

> 📌 **Nota importante**
> El funcionamiento detallado del benchmark y la interpretación de resultados se explican en el notebook `SQL_vs_NoSQL_Benchmark.ipynb`.
