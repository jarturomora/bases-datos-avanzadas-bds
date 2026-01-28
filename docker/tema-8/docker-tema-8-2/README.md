# Entorno Docker para el Tema 8 - Clase 2: Conceptos básicos de Neo4j y Cypher

Este repositorio incluye un `docker-compose.yml` para levantar **Neo4j** (motor de base de datos orientada a grafos) junto con **Neo4j Browser** (interfaz web) en un solo contenedor.

## Estructura del `docker-compose`

Crea **un servicio** llamado `neo4j`:

* **Neo4j Database Engine** (motor)
* **Neo4j Browser** (UI web integrada en Neo4j)

Neo4j Browser **no es un contenedor aparte**: viene incluido en la imagen oficial de Neo4j y se expone por HTTP.

## Puertos expuestos

El contenedor publica dos puertos al host:

* `7474:7474` → **Neo4j Browser (HTTP)**  
  Abre: `http://localhost:7474`
* `7687:7687` → **Bolt** (protocolo para drivers: Java, Python, Node, etc.)  
  Conexión típica: `bolt://localhost:7687`

## Variables de entorno (environment)

El `docker-compose.yml` define:

* `NEO4J_AUTH=neo4j/neo4j12345`  
  Crea el usuario/contraseña inicial para acceder al Browser y al motor.
  > Recomendación: cambia la contraseña en entornos no docentes.

* Ajustes de memoria para un entorno de clase (evita consumo excesivo):
  * `NEO4J_server_memory_heap_initial__size`
  * `NEO4J_server_memory_heap_max__size`
  * `NEO4J_server_memory_pagecache_size`

Estos límites ayudan a que el contenedor funcione de forma estable en portátiles o máquinas con recursos moderados.

## Persistencia de datos (volúmenes)

Se usan volúmenes Docker para no perder información al reiniciar el contenedor:

* `neo4j_data:/data` → almacena la base de datos
* `neo4j_logs:/logs` → guarda logs del motor

> **Nota:**
> Si haces `docker compose down` los datos se mantienen.  
> Si haces `docker compose down -v` se eliminan también los volúmenes y se pierde la base de datos.

## Cómo arrancar

En la carpeta donde está `docker-compose.yml`:

```bash
docker compose up -d
````

Ver logs del servicio:

```bash
docker compose logs -f neo4j
```

## Acceso

* **Browser:** `http://localhost:7474`
* **Usuario:** `neo4j`
* **Password:** `neo4j12345`
* **Bolt:** `bolt://localhost:7687`
