# Entorno Docker para el Tema 7 - Clase 1: Seguridad y control de acceso en MongoDB

Este repositorio contiene un entorno Docker mínimo para realizar una demo en clase sobre **seguridad y control de acceso en MongoDB** utilizando **MongoDB Compass** como cliente. El entorno levanta un servidor MongoDB con **autenticación y autorización (RBAC)** activadas, y crea una base de datos de ejemplo `ventas` (mueblería) con datos iniciales.

## Objetivo del entorno

* Proveer un MongoDB **listo para conectarse desde Compass**.
* Tener **usuarios con roles distintos** para demostrar:
  * Autenticación (login correcto)
  * Autorización (permisos por rol)
  * Principio de mínimo privilegio
* Contar con datos realistas en `ventas` para ejecutar consultas y operaciones.

## Estructura del proyecto

```text
docker-tema-7-1/
├─ docker-compose.yml
├─ mongod.conf
└─ init/
├─ 01-seed-ventas-muebleria.js
└─ 02-users-and-roles.js
```

### `docker-compose.yml`

Define el servicio principal `mongo`:

* **Imagen**: `mongodb/mongodb-community-server:8.0-ubi8`
* **Puertos**: expone MongoDB en `127.0.0.1:27017` (solo accesible desde la máquina local)
* **Variables de entorno**:
  * `MONGO_INITDB_ROOT_USERNAME`: usuario administrador inicial
  * `MONGO_INITDB_ROOT_PASSWORD`: contraseña del administrador
  * `MONGO_INITDB_DATABASE`: base por defecto para el entrypoint (`admin`)
* **Volúmenes**:
  * `mongo_data:/data/db` para persistencia
  * `./mongod.conf:/etc/mongo/mongod.conf:ro` para configuración del servidor
  * `./init:/docker-entrypoint-initdb.d:ro` para scripts de inicialización (seed + usuarios/roles)
* **Command**: arranca `mongod` usando el fichero de configuración montado.

### `mongod.conf`

Configuración del servidor MongoDB:

* `net.bindIp: 0.0.0.0` para permitir que MongoDB escuche dentro del contenedor (Docker).
* Publicación “segura” hacia el host gracias a `127.0.0.1:27017:27017` en `docker-compose.yml`.
* `security.authorization: enabled` para activar autorización basada en roles (RBAC).

### `init/01-seed-ventas-muebleria.js`

Script de seed que **crea y hace visible** la base de datos `ventas` insertando datos iniciales. Incluye:

* Colecciones:
  * `ventas.productos`
  * `ventas.clientes`
  * `ventas.pedidos`
* Datos de ejemplo (mueblería):
  * muebles (SKU, nombre, categoría, precio, stock, proveedor)
  * clientes (dni, nombre, email, ciudad, etc.)
  * pedidos (estado, líneas, totales)
* Índices recomendados:
  * `sku` único en `productos`
  * `dni` y `email` únicos en `clientes`
  * `numero` único en `pedidos`

### `init/02-users-and-roles.js`

Script de seguridad que crea usuarios y roles para la demo:

* Rol personalizado `ventasAudit` (ejemplo):
  * permite `find` y `collStats` en `ventas`
  * no permite escritura
* Usuarios (creados en la DB `ventas`):
  * `ventas_read`: rol `read` sobre `ventas` (solo lectura)
  * `ventas_rw`: rol `readWrite` sobre `ventas` (lectura/escritura)
  * `ventas_audit`: rol `ventasAudit` (auditoría)

## Cómo se ejecutan los scripts de `init/`

Los scripts dentro de `/docker-entrypoint-initdb.d` se ejecutan **solo la primera vez** que el contenedor arranca con el volumen de datos vacío.

Si se quiere “reiniciar” la base para que el seed vuelva a ejecutarse:

```bash
docker compose down -v
docker compose up -d
````

## Conexión desde MongoDB Compass (URIs)

* Admin:

    ```text
    mongodb://admin:StrongPass123!@localhost:27017/?authSource=admin
    ```

* Solo lectura (DB `ventas`):

    ```text
    mongodb://ventas_read:ReadPass_2026!@localhost:27017/ventas?authSource=ventas
    ```

* Lectura/escritura (DB `ventas`):

    ```text
    mongodb://ventas_rw:RWPass_2026!@localhost:27017/ventas?authSource=ventas
    ```

* Auditoría (DB `ventas`):

    ```text
    mongodb://ventas_audit:AuditPass_2026!@localhost:27017/ventas?authSource=ventas
    ```

## Buenas prácticas incorporadas

* Puerto publicado solo en `localhost` para reducir exposición en entornos de aula.
* Separación de cuentas: `admin` solo para tareas administrativas; usuarios funcionales para la operación.
* RBAC para demostrar mínimo privilegio.
* Seed con datos realistas para consultas y ejercicios.
