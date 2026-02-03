# Guía Didáctica Tema 10 - Clase 3: ElasticSearch, búsqueda distribuida

## Objetivos de la práctica

Al terminar esta actividad serás capaz de:

* Entrar en **Kibana** y localizar un índice previamente creado.
* Lanzar consultas en **Dev Tools** usando **Query DSL (JSON)**.
* Escribir consultas en **ES|QL** para explorar datos de forma más “tipo SQL”.
* Usar **Discover** para ver documentos y filtrar con **KQL**.
* Crear un **Dashboard** con 4 visualizaciones sencillas, pero útiles.

## Actividad 0 — Entrar en Kibana y comprobar que todo está listo

### Paso a paso

1. Abre tu navegador.
2. En la barra de direcciones escribe:
   `http://localhost:5601`
3. En el menú lateral de Kibana, entra en:

   * **Management → Dev Tools** (o directamente **Dev Tools** si te sale en el menú).
4. En la consola (lado izquierdo), pega esto y ejecútalo (botón ▶ o `Ctrl+Enter`):

   ```json
   GET /_cat/indices?v
   ```

### Resultado esperado

* Deberías ver una tabla con varios índices.
* En la columna `index` debe aparecer **`imdb_reviews`**.
* Si lo ves, significa que los datos de la demo están listos para trabajar.

## Actividad 1 — Dev Tools: primeras consultas con Query DSL (JSON)

> Aquí trabajas directamente con la API de Elasticsearch. Es “la forma oficial” de hablar con el motor.

### 1.1 Ver algunos documentos con título y review

En **Dev Tools**, ejecuta:

```json
GET imdb_reviews/_search
{
  "size": 5,
  "_source": ["title", "year", "genres", "user_rating", "imdb_average_rating", "review_text"],
  "query": { "exists": { "field": "title" } }
}
```

#### Resultado esperado

* En `hits.hits` verás hasta 5 documentos.
* Cada uno debe incluir:

  * `title` (nombre de la película),
  * `year`,
  * `genres`,
  * `user_rating`,
  * `review_text`.
* Ya tienes una primera idea de qué contiene el índice.

### 1.2 Buscar reviews que contengan una palabra y tengan buena nota

Ejecuta esta consulta:

```json
GET imdb_reviews/_search
{
  "size": 10,
  "_source": ["title", "year", "user_rating", "review_text"],
  "query": {
    "bool": {
      "must": [
        { "match": { "review_text": "masterpiece" } }
      ],
      "filter": [
        { "range": { "user_rating": { "gte": 8 } } }
      ]
    }
  },
  "sort": [
    { "user_rating": "desc" }
  ]
}
```

#### Resultado esperado

* Verás reviews que:

  * contienen la palabra **“masterpiece”** en `review_text`,
  * tienen `user_rating` mayor o igual que 8,
  * están ordenadas por la nota del usuario de mayor a menor.
* Has combinado **búsqueda por texto** y **filtro por rango**.

### 1.3 Ver los géneros más frecuentes (agregación)

Ejecuta:

```json
GET imdb_reviews/_search
{
  "size": 0,
  "aggs": {
    "top_genres": {
      "terms": { "field": "genres", "size": 10 }
    }
  }
}
```

#### Resultado esperado

* No verás `hits` (porque `size: 0`), solo `aggregations`.
* Dentro de `aggregations.top_genres.buckets` verás:

  * cada género (`key`), y
  * cuántas reviews hay de ese género (`doc_count`).
* Has usado Elasticsearch como si fuera una herramienta de **análisis de datos**, no solo de búsqueda.

## Actividad 2 — ES|QL: consultas tipo SQL/pipeline

> Ahora vas a hacer cosas parecidas, pero con un lenguaje más parecido a SQL y con “tuberías” (`|`).

### Paso previo: abrir el editor ES|QL

Dependiendo de tu versión de Kibana, puedes:

* Opción A: Ir a **Discover** y buscar un botón/selector tipo **“ES|QL”** o **“Try ES|QL”**.
* Opción B: Usar la **barra de búsqueda global** (arriba), escribir “ES|QL” y abrir el editor de ES|QL.

Una vez dentro, te aparecerá una caja de texto donde escribir consultas como texto plano (no JSON).

### 2.1 Ver algunas películas con sus datos básicos

Pega y ejecuta:

```text
FROM imdb_reviews
| WHERE title IS NOT NULL
| KEEP title, year, genres, user_rating, imdb_average_rating, review_text
| LIMIT 5
```

#### Resultado esperado

* Verás una tabla con 5 filas como máximo.
* Columnas: `title`, `year`, `genres`, `user_rating`, `imdb_average_rating`, `review_text`.
* Es similar a la primera consulta de Dev Tools, pero con un estilo más “tabla SQL”.

### 2.2 Reviews con buena nota y una palabra clave en el texto

Ejecuta:

```text
FROM imdb_reviews
| WHERE title IS NOT NULL AND user_rating >= 8
| WHERE MATCH(review_text, "masterpiece")
| KEEP title, year, user_rating, review_text
| SORT user_rating DESC
| LIMIT 10
```

#### Resultado esperado

* Tabla con reviews que mencionan “masterpiece” y nota `>= 8`.
* Ordenadas de mayor a menor `user_rating`.
* Debes reconocer el mismo tipo de resultado que en la consulta 1.2 con JSON, pero usando un pipeline ES|QL.

### 2.3 Media de rating por película (vista resumen)

Ejecuta:

```text
FROM imdb_reviews
| WHERE title IS NOT NULL
| STATS avg_user_rating = AVG(user_rating), reviews = COUNT(*) BY title
| SORT avg_user_rating DESC
| LIMIT 10
```

#### Resultado esperado

* Tabla con las 10 películas mejor valoradas según las reviews indexadas.
* Columnas:

  * `title`
  * `avg_user_rating`
  * `reviews` (cuántas reviews se han usado)
* Acabas de hacer una especie de `GROUP BY title` con media y conteo.

## Actividad 3 — Discover: explorar documentos con KQL

> Discover es la “vista tipo tabla” donde puedes hacer filtros rápidos sin escribir JSON.

### 3.1 Abrir Discover y crear el Data View

1. Menú lateral → **Discover**.
2. Si te pide crear un Data View:

   * Name: `imdb`
   * Index pattern: `imdb_reviews*`
   * Time field: elige **“I don’t want to use the time filter”**.

#### Resultado esperado

* Verás una tabla con documentos del índice `imdb_reviews`.

### 3.2 Añadir columnas útiles

En la lista de campos (panel izquierdo), añade como columnas:

* `title`
* `year`
* `genres`
* `user_rating`
* `imdb_average_rating`
* `imdb_num_votes`

(Se añaden haciendo clic en el icono “+” que aparece al pasar por encima del nombre del campo.)

#### Resultado esperado

* La tabla central muestra una fila por documento.
* Para cada fila ves el título de la película, el año, géneros, rating de usuario y rating medio de IMDb.

### 3.3 Hacer 3 filtros con KQL

#### 3.3.1 Solo documentos con título

En la barra de búsqueda (arriba), escribe:

```kql
title : *
```

y pulsa Enter.

**Resultado esperado**

* Solo ves documentos que tienen campo `title`.
* El número total de documentos mostrados baja.

#### 3.3.2 Reviews con nota alta

Cambia la consulta a:

```kql
user_rating >= 8
```

**Resultado esperado**

* Ahora la tabla solo muestra reviews con `user_rating` entre 8 y 10.
* Puedes ordenar la columna `user_rating` haciendo clic en el encabezado para ver primero las más altas.

#### 3.3.3 Buscar expresión en review y filtrar por género

Usa:

```kql
review_text : "plot twist" and genres : "Drama"
```

**Resultado esperado**

* Solo ves reviews que mencionan “plot twist” y cuyo género incluye `Drama`.
* Has combinado un filtro por texto con un filtro por campo exacto.

## Actividad 4 — Dashboard: construir una vista resumen con 4 gráficas

> Aquí conviertes consultas en visualizaciones. Es lo que enseñas a alguien para “vender” tus resultados.

### 4.1 Crear un nuevo Dashboard

1. Menú → **Dashboards**.
2. Pulsa **Create dashboard**.
3. Pulsa **Create visualization** (o “Add panel” → “Create new”).

#### Resultado esperado

* Estás en un dashboard vacío, listo para ir añadiendo visualizaciones.
* Todas las visualizaciones deben usar el data view `imdb_reviews*`.

### 4.2 Visualización 1: Métrica de total de reviews

1. Elige tipo **Metric**.
2. En la métrica, selecciona:

   * `Count`
3. Guarda la visualización con el nombre: **`Total reviews`**, y añádela al dashboard.

#### Resultado esperado

* Ves un número grande con el total de documentos del índice (por ejemplo, 5.000, 10.000… lo que hayas cargado).

### 4.3 Visualización 2: Barras con los géneros más frecuentes

1. Crea otra visualización de tipo **Bar (vertical)**.
2. Configura:

   * Eje Y: `Count`
   * Eje X (Buckets → Terms):

     * Field: `genres`
     * Size: 10
     * Order: por `Count` descendente
3. Guarda como **`Top genres (count)`** y añádela al dashboard.

#### Resultado esperado

* Un gráfico de barras donde cada barra es un género.
* Cuanto más alta la barra, más reviews tiene ese género.

### 4.4 Visualización 3: Histograma de `user_rating`

1. Nueva visualización de tipo **Histogram** o **Bar** (según versión).
2. Configura:

   * X-axis: `Histogram` sobre `user_rating` con intervalo = 1
   * Y-axis: `Count`
3. Guarda como **`User rating distribution`**.

#### Resultado esperado

* Un gráfico que muestra cuántas reviews hay con nota 1, 2, 3, …, 10.
* Te permite ver si la gente tiende a puntuar alto, bajo, etc.

### 4.5 Visualización 4: Tabla de “Top películas por media de rating”

1. Crea una visualización de tipo **Data table**.
2. Configura:

   * Split rows (Buckets → Terms):

     * Field: `title.raw` (si existe) o `movie_id` si no.
     * Size: 10
   * Metrics:

     * `Average` sobre `user_rating` → renombra a `avg_user_rating`
     * `Count` → renombra a `reviews`
   * Ordena por `avg_user_rating` descendente.
3. Guarda como **`Top movies by avg user rating`**.

#### Resultado esperado

* Una tabla donde cada fila es una película.
* Columnas:

  * título (o `movie_id`),
  * media de nota (`avg_user_rating`),
  * número de reviews (`reviews`).
* Estás viendo un ranking de películas según las reviews indexadas.

## ¿Qué has aprendido con todo esto?

* **Dev Tools (JSON)**: cómo hacer búsquedas y agregaciones directamente contra Elasticsearch.
* **ES|QL**: cómo expresar las mismas ideas con un lenguaje más parecido a SQL y muy cómodo para análisis.
* **Discover**: cómo explorar los documentos como si fueran una tabla de datos, usando KQL para filtrar.
* **Dashboards**: cómo transformar datos en visualizaciones que resumen la información clave.
