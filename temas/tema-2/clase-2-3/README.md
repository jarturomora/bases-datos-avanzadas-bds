# Guion práctico para el Tema 2 - Clase 3: Índices simples vs índices compuestos en MySQL

## Contexto del ejercicio

Estamos trabajando con una tabla `pedidos` que contiene **millones de registros**.
El problema a resolver es el siguiente:

> Las consultas de ventas por **cliente y rango de fechas** son lentas.
> Queremos entender **por qué** y **cómo mejorar su rendimiento** usando índices.

En cada bloque:

1. Copia y pega el SQL.
2. Ejecuta la consulta.
3. Observa el resultado de `EXPLAIN ANALYZE`.
4. Lee los comentarios antes de continuar.

## 0) Verificar el volumen de datos

```sql
USE ecommerce;

-- Comprobamos cuántos pedidos hay en la tabla
SELECT COUNT(*) AS total_pedidos
FROM pedidos;
```

### Qué debes entender

* El volumen es muy alto (millones de filas).
* Un escaneo completo de la tabla será costoso.

## 1) Consulta problemática SIN índices

Esta es la consulta real que ejecutan los analistas:
ventas de un cliente concreto durante un mes.

```sql
USE ecommerce;

EXPLAIN ANALYZE
SELECT
  cliente_id,
  DATE(fecha) AS dia,
  SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01'
  AND fecha <  '2024-07-01'
GROUP BY cliente_id, DATE(fecha);
```

### Qué debes observar

* `type: ALL`
* Se examinan **millones de filas**.
* El tiempo de ejecución es elevado.

### Qué está pasando internamente

MySQL:

* Recorre toda la tabla `pedidos`.
* Comprueba fila por fila si coincide el cliente y la fecha.

### Idea clave

> Sin índices, el motor no tiene forma de ir “directo” a los datos que necesita.

## 2) Medir actividad de lectura (antes de indexar)

```sql
USE ecommerce;

-- Contadores de acceso a datos en esta sesión
SHOW SESSION STATUS LIKE 'Handler_read%';
SHOW SESSION STATUS LIKE 'Innodb_buffer_pool_read%';
```

### Qué debes observar

* Muchos accesos de lectura.
* Señal de alto consumo de E/S y uso intensivo de memoria caché.

## 3) Crear un índice simple en cliente_id

Ahora ayudamos parcialmente al motor.

```sql
USE ecommerce;

-- Índice simple solo por cliente
CREATE INDEX idx_pedidos_cliente
ON pedidos(cliente_id);

ANALYZE TABLE pedidos;
```

Repetimos exactamente la misma consulta:

```sql
USE ecommerce;

EXPLAIN ANALYZE
SELECT
  cliente_id,
  DATE(fecha) AS dia,
  SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01'
  AND fecha <  '2024-07-01'
GROUP BY cliente_id, DATE(fecha);
```

### Qué debes observar ahora

* `type` cambia (por ejemplo, `ref`).
* El número de filas examinadas **baja**, pero sigue siendo alto.
* El tiempo mejora, pero no es óptimo.

### Qué está pasando internamente

MySQL:

* Usa el índice para localizar **todos los pedidos del cliente**.
* Luego filtra por fecha **fuera del índice**.

### Idea clave

> Un índice simple ayuda, pero no cubre todo el patrón de la consulta.

## 4) Medir actividad de lectura tras el índice simple

```sql
USE ecommerce;

SHOW SESSION STATUS LIKE 'Handler_read%';
SHOW SESSION STATUS LIKE 'Innodb_buffer_pool_read%';
```

### Qué debes observar

* Menos lecturas que antes.
* Aún hay trabajo innecesario.

## 5) Crear un índice compuesto (cliente_id, fecha)

Ahora creamos el índice adecuado para la consulta real.

```sql
USE ecommerce;

-- Índice compuesto: igualdad primero, rango después
CREATE INDEX idx_pedidos_cliente_fecha
ON pedidos(cliente_id, fecha);

ANALYZE TABLE pedidos;
```

Repetimos de nuevo la misma consulta:

```sql
USE ecommerce;

EXPLAIN ANALYZE
SELECT
  cliente_id,
  DATE(fecha) AS dia,
  SUM(total) AS ventas
FROM pedidos
WHERE cliente_id = 4242
  AND fecha >= '2024-06-01'
  AND fecha <  '2024-07-01'
GROUP BY cliente_id, DATE(fecha);
```

### Qué debes observar ahora

* MySQL elige el índice compuesto.
* Muchísimas menos filas examinadas.
* Latencia claramente menor.

### Qué está pasando internamente

El motor:

* Localiza directamente el cliente.
* Dentro de ese cliente, navega solo el rango de fechas.
* Reduce E/S, CPU y trabajo de filtrado.

### Idea clave

> El índice compuesto se adapta exactamente al patrón de la consulta.

## 6) Medir actividad de lectura tras el índice compuesto

```sql
USE ecommerce;

SHOW SESSION STATUS LIKE 'Handler_read%';
SHOW SESSION STATUS LIKE 'Innodb_buffer_pool_read%';
```

### Qué debes observar

* Menos lecturas físicas.
* Uso más eficiente de la caché.
* Menor presión sobre el sistema.

## 7) Consulta alternativa: solo por fecha

Esta consulta **no filtra por cliente**.

```sql
USE ecommerce;

EXPLAIN ANALYZE
SELECT
  DATE(fecha) AS dia,
  SUM(total) AS ventas
FROM pedidos
WHERE fecha >= '2024-06-01'
  AND fecha <  '2024-07-01'
GROUP BY DATE(fecha);
```

### Qué debes reflexionar

* El índice `(cliente_id, fecha)` **no es ideal** para este patrón.
* El orden de las columnas del índice importa.

### Idea clave

> Un índice compuesto solo es eficiente cuando se usa su prefijo izquierdo.

## Conclusión final

* `EXPLAIN ANALYZE` muestra cómo **realmente** se ejecuta una consulta.
* Un índice simple puede mejorar, pero no siempre es suficiente.
* Los índices compuestos deben diseñarse según:

  * columnas usadas en `WHERE`,
  * tipo de condición (igualdad / rango),
  * y orden de los filtros.
* Menos filas examinadas implica:

  * menos E/S,
  * menor uso de CPU,
  * mejor aprovechamiento de la caché.

> **Regla de oro**
> *Diseña los índices a partir de las consultas más importantes, no al revés.*
