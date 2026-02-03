# Entorno Docker para la demo de Elasticsearch

## 1. Descripción general

Este proyecto monta, con un solo `docker compose`, un entorno completo para trabajar con **reviews de películas** en **Elasticsearch**:

* **Elasticsearch** → almacena e indexa los documentos (`imdb_reviews`).
* **Kibana** → interfaz web para consultar, explorar y visualizar los datos.
* **es-setup** → crea el índice con el mapping correcto.
* **es-loader** → descarga datos reales (IMDb + reviews) y los carga en Elasticsearch.

La idea es que tú no tengas que preocuparte por crear índices ni buscar datos:
solo entrar en Kibana y trabajar con consultas y visualizaciones.

## 2. Estructura de directorios del proyecto

El proyecto suele tener una estructura como esta:

```text
elastic-imdb-demo/
├─ docker-compose.yml
├─ .env
├─ setup/
│  ├─ 01_create_index.sh
│  └─ imdb_reviews_mapping.json
└─ loader/
   ├─ Dockerfile
   ├─ requirements.txt
   └─ load_imdb_demo.py
```

### Descripción de los ficheros y directorios

* **`docker-compose.yml`**
  El “orquestador”: define todos los servicios (elasticsearch, kibana, es-setup, es-loader),
  los puertos, volúmenes y dependencias entre ellos.

* **`.env`**
  Archivo de configuración con variables, por ejemplo:

  * versión del stack (`STACK_VERSION`),
  * puertos (`ES_PORT`, `KIBANA_PORT`),
  * memoria máxima,
  * cuántos documentos cargar (`MAX_DOCS`).

  Así puedes cambiar parámetros sin tocar el `docker-compose.yml`.

* **`setup/`**
  Carpeta con todo lo necesario para **crear el índice**.

  * `01_create_index.sh`
    Script que se ejecuta dentro del contenedor `es-setup`.

    * Comprueba si existe el índice `imdb_reviews`.
    * Si no existe, lo crea llamando a Elasticsearch y enviando el mapping.
  * `imdb_reviews_mapping.json`
    Definición del índice:

    * settings (analyzer de texto, nº de shards, etc.),
    * mappings (campos como `title`, `year`, `genres`, `user_rating`, `review_text`… y su tipo).

* **`loader/`**
  Carpeta con todo lo necesario para **cargar los datos**.

  * `Dockerfile`
    Define la imagen del contenedor `es-loader`:

    * parte de `python:3.11-slim`,
    * instala las librerías de `requirements.txt`,
    * copia `load_imdb_demo.py` y lo ejecuta.

  * `requirements.txt`
    Lista de dependencias Python:

    * `datasets` para bajar el dataset de reviews,
    * `pandas` para procesar los TSV de IMDb,
    * `requests` para llamar a APIs, etc.

  * `load_imdb_demo.py`
    Script de carga que:

    1. Descarga los TSV oficiales de IMDb (metadatos y ratings medios).
    2. Descarga el dataset de reviews desde Hugging Face.
    3. Une reviews y metadatos por `movie_id` (tipo `tt1234567`).
    4. Construye documentos JSON con campos como:

       * `title`, `year`, `genres`,
       * `user_rating`, `review_text`,
       * `imdb_average_rating`, `imdb_num_votes`.
    5. Envía los documentos a Elasticsearch usando la **Bulk API**.

## 3. Servicios principales

### `elasticsearch`

* Motor de búsqueda.
* Modo single-node (para clase).
* API accesible en `http://localhost:9200`.
* Guarda datos en un volumen (`esdata`) para que no se pierdan al parar el contenedor.

### `kibana`

* Interfaz web.
* Acceso en `http://localhost:5601`.
* Desde aquí usarás:

  * **Dev Tools** → queries JSON (Query DSL).
  * **Discover** → ver documentos y filtrar con KQL.
  * **Dashboards** → gráficos y tablas.

### `es-setup`

* Contenedor de “inicialización”.
* Se ejecuta una vez al levantar el stack.
* Llama al script `setup/01_create_index.sh` para asegurarse de que el índice `imdb_reviews` existe y tiene el mapping correcto.

### `es-loader`

* Contenedor de “carga de datos”.
* Normalmente se ejecuta cuando activas el profile `load`.
* Usa `load_imdb_demo.py` para rellenar el índice con datos de la demo.

## 4. Volúmenes (datos persistentes)

Aunque no lo veas en el sistema de archivos del proyecto, el `docker-compose.yml` define volúmenes como:

* `esdata` → contenido del índice de Elasticsearch (los documentos).
* `imdbcache` → ficheros descargados (TSV de IMDb, datasets, etc.).

Para ti como alumno, la idea importante es:

* Si solo paras los contenedores, los datos siguen estando ahí.
* Si el profesor hace `docker compose down -v`, se “resetea” el entorno y se vuelve a crear todo desde cero.
