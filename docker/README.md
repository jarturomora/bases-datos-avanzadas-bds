# Contenedores Docker para la asignatura

Este directorio agrupa composiciones y artefactos Docker para las prácticas de los distintos temas de la asignatura "Bases de Datos Avanzadas".

## Instalación y herramientas recomendadas

1. Docker Desktop

    - Descarga e instalación: instala Docker Desktop para tu sistema operativo desde la web oficial: <https://www.docker.com/get-started>

2. Extensión "Container Tools"

    - Para gestionar contenedores y composiciones desde Visual Studio Code, instala [la extensión "Container Tools"](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-containers) desde el Marketplace de extensiones.

## Notas y recomendaciones

- Cada subcarpeta `docker-tema-X/` incluye un `README.md` con instrucciones específicas para ese tema (por ejemplo, puertos expuestos, variables de entorno y scripts de inicialización).

- Usa la vista de _Container Tools_ en VS Code para levantar composiciones (`Compose Up`), ver logs y administrar contenedores de forma visual.
