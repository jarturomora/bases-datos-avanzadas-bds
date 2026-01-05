# Guión práctico para el Tema 4 - Clase 3: Práctica comparativa SQL vs NoSQL

## Objetivo de la práctica

En esta práctica se comparan **dos enfoques de bases de datos** aplicados al mismo problema:

* **PostgreSQL (SQL)** con un modelo relacional.
* **MongoDB (NoSQL)** con un modelo basado en documentos JSON.

Ambos sistemas gestionan un **catálogo de productos** con operaciones frecuentes de:

* búsqueda,
* actualización,
* e inserción de compras.

El objetivo es **analizar cómo cada tecnología responde a los mismos retos** desde perspectivas distintas.

## Qué se va a evaluar en ambos paradigmas de bases de datos

Durante la práctica se analizarán las siguientes dimensiones:

1. **Latencia:** Tiempo que tarda cada operación individual (medido mediante p50 y p95).
2. **Throughput:** Número de operaciones por segundo que puede manejar cada sistema.
3. **Complejidad de desarrollo:** Facilidad para modelar los datos y expresar las operaciones.
4. **Operación y mantenimiento:** Consideraciones sobre escalado, replicación y gestión del sistema.

## Cómo se realiza la práctica

* El entorno se despliega mediante **Docker**.
* El benchmark se ejecuta **paso a paso en un Jupyter Notebook**.
* El notebook incluye:

  * explicación del escenario,
  * ejecución de un workload mixto,
  * microbenchmarks separados (search / update / insert),
  * visualización de resultados,
  * y preguntas guía para la reflexión.

> 📌 **Importante**:
> El **detalle completo del experimento, el código y las explicaciones técnicas** se encuentran en el notebook [`SQL_vs_NoSQL_Benchmark.ipynb`](../../../docker/tema-4/docker-tema-4-3/bench/SQL_vs_NoSQL_Benchmark.ipynb).

### Arranque y conexión

Utiliza la extensión "Container Tools" de VS Code para iniciar los contenedores, o ejecutar el siguiente comando desde el directorio del proyecto (en Windows se debe utilizar un terminal de WSL -Windows Subsystem Linux-):

```bash
docker compose up -d
```

Espera a que termine la inicialización automática.

## Ideas clave

* No existe una base de datos “mejor” en términos absolutos.
* La elección entre SQL y NoSQL depende del **tipo de carga**, los **requisitos de consistencia**, y las **necesidades de escalado** del sistema.
