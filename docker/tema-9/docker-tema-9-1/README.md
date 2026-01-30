# Entorno Docker para el Tema 9 - Clase 1: Modelo de propiedad etiquetada

## Estructura del proyecto (Docker + CSV + Config)

Este proyecto levanta **Neo4j (motor) + Neo4j Browser (UI web)** usando Docker Compose, y está preparado para **importar CSV** durante la demo desde una carpeta local.

### Árbol de directorios

```txt
docker-tema-9-1/
├─ docker-compose.yml
├─ DATA/                         # CSV accesibles desde Neo4j como file:///...
│  ├─ persons.csv
│  ├─ companies.csv
│  ├─ groups.csv
│  ├─ courses.csv
│  ├─ works_at.csv
│  ├─ member_of.csv
│  ├─ enrolled_in.csv
│  └─ connected_to.csv
└─ neo4j/
   └─ conf/                      # Configuración del servidor Neo4j (montada en /conf)
      └─ neo4j.conf
```

## Detalle de los ficheros del contenedor

### `docker-compose.yml`

Define un único servicio llamado `neo4j` que:

* Arranca **Neo4j** (base de datos orientada a grafos).
* Expone **Neo4j Browser** para ejecutar Cypher desde el navegador.
* Monta **volúmenes** para persistir datos y para importar CSV.

**Puertos publicados:**

* `7474` → Neo4j Browser (HTTP): `http://localhost:7474`
* `7687` → Bolt (drivers): `bolt://localhost:7687`

### Carpeta `data/` (CSVs para importar)

Esta carpeta contiene los ficheros CSV que se cargan durante la demo.

Se monta dentro del contenedor como el directorio de importación, por lo que desde Cypher se accede así:

```cypher
LOAD CSV WITH HEADERS FROM 'file:///file_name.csv' AS row ...
```

> **Importante:** `file:///` siempre apunta a la carpeta `import` configurada en Neo4j (en este proyecto se redirige a `data` montada en el contenedor).

### Carpeta `neo4j/conf/` (configuración del servidor)

Aquí guardamos `neo4j.conf` para poder:

* Ver “dónde se configura” Neo4j en una demo.
* Cambiar parámetros (por ejemplo, permitir importación de CSV) sin tocar la imagen del contenedor.

El contenedor monta esta carpeta en `/conf`, y Neo4j lee `neo4j.conf` desde ahí.

## Persistencia de datos

El contenedor usa volúmenes Docker para que la base de datos no se pierda al reiniciar:

* `neo4j_data` → guarda la base de datos (`/data`)
* `neo4j_logs` → guarda logs (`/logs`)

**Reset completo (borrar datos):**

```bash
docker compose down -v
```

## Cómo arrancar el entorno

En la carpeta donde está `docker-compose.yml`:

```bash
docker compose up -d
```

Ver logs:

```bash
docker compose logs -f neo4j
```

Acceso:

* Browser: `http://localhost:7474`
* Credenciales: las definidas en `NEO4J_AUTH` del compose.
