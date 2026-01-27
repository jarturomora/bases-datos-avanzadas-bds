# Entorno Docker para el Tema 7 - Clase 2: Replica Sets y Sharding en MongoDB

Este repositorio levanta un clúster MongoDB con **shards** y preparado para docencia, accesible desde **MongoDB Compass** mediante una única URI.

## Visión general

El `docker-compose.yml` crea un entorno con:

* **1 router `mongos`** expuesto en el host (puerto `27017`)
* **1 Config Server Replica Set** (`cfgRS`) para metadatos del clúster
* **3 shards**, donde cada shard es un **Replica Set** con **3 nodos de datos**
* Un proceso de **bootstrap automático** que:

  * inicializa el config server RS,
  * arranca `mongos` cuando el config server está listo,
  * configura sharding + shards,
  * carga datos de ejemplo en la BD `teleco_es`.

## Servicios del compose

### `cfg1` (Config Server)

* Contenedor: `cfg1`
* Rol: **Config Server** (almacena metadatos en la BD interna `config`)
* Puerto interno: `27019`
* RS: `cfgRS`
* Volumen: `cfg1_data`

### `init_cfg` (bootstrap del config RS)

* Contenedor “one-shot” (se ejecuta y termina).
* Función:

  * espera a que `cfg1` esté saludable,
  * ejecuta `rs.initiate(...)` si hace falta,
  * espera a que `cfgRS` tenga **PRIMARY**.
* Esto garantiza que `mongos` no arranque antes de tiempo.

### `mongos` (router del clúster)

* Contenedor: `mongos`
* Rol: router (no guarda datos de negocio).
* Puerto expuesto en el host: `localhost:27017`
* Lee metadatos de `cfgRS` mediante `--configdb`.
* Entrada: usa `setup/mongos-entrypoint.sh` para esperar que el config RS esté listo antes de arrancar.

### Shards (Replica Sets de datos)

Cada shard es un Replica Set con 3 nodos (sin árbitros).

* **Shard 1**: `rsShard1`

  * `s1a`, `s1b`, `s1c` (puerto interno `27018`)
  * Volúmenes: `s1a_data`, `s1b_data`, `s1c_data`

* **Shard 2**: `rsShard2`

  * `s2a`, `s2b`, `s2c` (puerto interno `27018`)
  * Volúmenes: `s2a_data`, `s2b_data`, `s2c_data`

* **Shard 3**: `rsShard3`

  * `s3a`, `s3b`, `s3c` (puerto interno `27018`)
  * Volúmenes: `s3a_data`, `s3b_data`, `s3c_data`

### `setup` (bootstrap del clúster y carga de datos)

* Contenedor “one-shot” (se ejecuta y termina).
* Función:

  1. Espera a que `mongos` y nodos base estén accesibles.
  2. Ejecuta `setup/01-init-cluster.js`:

     * inicia los Replica Sets de shards,
     * añade shards al clúster,
     * habilita sharding y configura shard keys.
  3. Verifica que el sharding está listo.
  4. Ejecuta `setup/02-seed-teleco.js`:

     * carga datos en `teleco_es` (usuarios, líneas, llamadas).

## Estructura de ficheros

```text
docker-tema-7-2/
├─ docker-compose.yml
└─ setup/
   ├─ mongos-entrypoint.sh      # Arranque seguro de mongos (espera cfgRS PRIMARY)
   ├─ setup.sh                  # Orquesta init-cluster + verificación + seed
   ├─ 01-init-cluster.js        # RS shards + addShard + enableSharding + shardCollection
   └─ 02-seed-teleco.js         # Generación/carga de datos demo (teleco_es)
```

## Cómo se conecta Compass

El solo se necesita conectarse a través de la siguiente URI desde MongoDB Compass:

* URI: `mongodb://localhost:27017`

Esa conexión entra por `mongos`, que enruta operaciones hacia los shards según la shard key.

## Notas operativas

* Para reiniciar desde cero (borrando volúmenes y datos):

  ```bash
  docker compose down -v
  docker compose up -d
  docker logs -f setup
  ```

* La base de datos de negocio es:

  * `teleco_es` (sharded)

* Los metadatos del clúster se almacenan en:

  * DB `config` (en el config server)
