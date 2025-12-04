# Contenedores Docker para la asignatura

Este directorio agrupa composiciones y artefactos Docker para las prácticas de los distintos temas de la asignatura "Bases de Datos Avanzadas".

## Estructura relevante

- `docker-tema-2/` — Composición para el Tema 2 (MySQL + phpMyAdmin). Incluye `docker-compose.yml` y `initdb/001_schema_and_seed.sql`.

> En este repositorio se añadirás más subcarpetas `docker-tema-X/` con las composiciones y scripts necesarios para cada tema.

## Instalación y herramientas recomendadas

1. Docker Desktop

    - Descarga e instalación: instala Docker Desktop para tu sistema operativo desde la web oficial: <https://www.docker.com/get-started>

2. Extensión "Container Tools"

    - Para gestionar contenedores y composiciones desde Visual Studio Code, instala [la extensión "Container Tools"](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-containers) desde el Marketplace de extensiones.

## Notas y recomendaciones

- Cada subcarpeta `docker-tema-X/` incluye un `README.md` con instrucciones específicas para ese tema (por ejemplo, puertos expuestos, variables de entorno y scripts de inicialización).

- Usa la vista de _Container Tools_ en VS Code para levantar composiciones (`Compose Up`), ver logs y administrar contenedores de forma visual.

- Recuerda que los scripts en `initdb/` se ejecutan una sola vez al inicializar la base de datos si se usan volúmenes persistentes; para re-ejecutarlos es necesario recrear la base de datos/volumen.
