# Docker — Tema 2

Este directorio contiene una pequeña composición Docker para las prácticas del Tema 2.

Contenido principal:

- `docker-compose.yml`: Define dos servicios: `mysql` (imagen oficial MySQL) y `phpmyadmin`.
- `initdb/001_schema_and_seed.sql`: Script que se monta en `/docker-entrypoint-initdb.d` para inicializar la base de datos al crear el contenedor.

## Guión de instrucciones

1. Requisitos previos
   - Tener Docker (o Docker Desktop) corriendo en la máquina.
   - Tener instalada la extensión "Container Tools" en VS Code.

2. Localizar el archivo `docker-compose.yml` e iniciar todos los servicios.
  
3. Comprobar inicialización de datos
   - El fichero `initdb/001_schema_and_seed.sql` se monta en `/docker-entrypoint-initdb.d` dentro del contenedor MySQL y se ejecuta automáticamente la primera vez que la base de datos se crea.

4. Acceder a phpMyAdmin (interfaz web)
   - Una vez levantada la composición, el servicio `phpmyadmin` expone el puerto `8080`. Abre `http://localhost:8080` en el navegador para acceder a la interfaz.

5. Ver logs y estado
   - Desde Container Tools puedes ver los logs de cada contenedor, reiniciarlos o detenerlos con las acciones disponibles (View Logs, Restart, Stop, Compose Down).

6. Parar la composición
   - Usa la acción "Compose Down" o "Stop" en la interfaz de Container Tools para detener y, si procede, eliminar los contenedores creados.

Notas

- El script en `initdb/` sólo se ejecuta cuando la base de datos se inicializa por primera vez (si la base de datos ya existe en un volumen persistente, no se ejecutará).
- Si necesitas volver a ejecutar el script de inicialización, elimina el volumen/contendor asociado o crea una nueva base de datos temporal.
