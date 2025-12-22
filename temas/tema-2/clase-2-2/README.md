# Guion práctico Tema 2 - Clase 2: cómo MySQL ejecuta consultas con y sin índices

## Contexto inicial

Estamos trabajando con una tabla `users` que contiene **aproximadamente 1 millón de registros**.
Este volumen es suficiente para que:

* Las consultas sin índices sean perceptiblemente lentas.
* Los cambios en el plan de ejecución sean visibles con `EXPLAIN ANALYZE`.

En cada bloque:

1. Copia y pega la consulta.
2. Observa el resultado.
3. Lee la explicación antes de continuar.

## 1) Verificar el tamaño de la tabla

```sql
use demo;

SELECT COUNT(*) AS total_users
FROM users;
```

### Qué debes observar

* El número total de filas.
* A partir de este volumen, **recorrer toda la tabla** ya no es eficiente.

### Idea clave

> Cuantos más registros hay, más importante es ayudar al motor a encontrar solo los datos relevantes.

## 2) Consulta por rango de fechas SIN índice

Vamos a contar los usuarios creados en febrero de 2024.

```sql
use demo;

EXPLAIN ANALYZE
SELECT COUNT(*) AS users_february
FROM users
WHERE created_at >= '2024-02-01'
  AND created_at <  '2024-03-01';
```

### Qué debes observar

* `type: ALL` (escaneo completo de la tabla).
* El número de filas examinadas es muy alto.
* El tiempo de ejecución es relativamente elevado.

### Qué está pasando internamente

MySQL no tiene ninguna estructura que le permita “saltar” a febrero, por lo que **revisa fila por fila** comprobando la fecha.

### Idea clave

> Sin índice, el motor no tiene alternativa al recorrido completo.

## 3) Crear un índice por fecha y repetir la consulta

Ahora vamos a ayudar al motor creando un índice.

```sql
use demo;

CREATE INDEX idx_users_created_at
ON users(created_at);
```

Repite exactamente la misma consulta:

```sql
use demo;

EXPLAIN ANALYZE
SELECT COUNT(*) AS users_february
FROM users
WHERE created_at >= '2024-02-01'
  AND created_at <  '2024-03-01';
```

### Qué debes observar ahora

* El tipo de acceso cambia a `range`.
* El número de filas examinadas se reduce de forma clara.
* El tiempo de ejecución mejora notablemente.

### Qué está pasando internamente

El índice está organizado como un **árbol B+**, lo que permite:

* Localizar rápidamente el inicio del rango.
* Recorrer solo las hojas necesarias.

### Idea clave

> Los índices son especialmente eficaces para consultas por rango.

## 4) Búsqueda exacta por email

Ahora realizamos una búsqueda por un valor concreto.

```sql
use demo;

EXPLAIN ANALYZE
SELECT *
FROM users
WHERE email = 'user123456@example.com';
```

### Qué debes observar

* Tipo de acceso `const` o `ref`.
* Muy pocas filas examinadas (normalmente 1).
* Tiempo de ejecución muy bajo.

### Qué está pasando internamente

El índice sobre `email` permite encontrar directamente la fila, sin necesidad de recorrer rangos ni filtrar resultados.

### Idea clave

> Las búsquedas exactas sobre columnas indexadas son extremadamente rápidas.

## 5) Consulta con varios filtros SIN índice compuesto

Vamos a combinar varios criterios:

```sql
use demo;

EXPLAIN ANALYZE
SELECT COUNT(*) AS spanish_active_users_february
FROM users
WHERE created_at >= '2024-02-01'
  AND created_at <  '2024-03-01'
  AND country = 'ES'
  AND status = 1;
```

### Qué debes observar

* Se utiliza el índice de `created_at`.
* Aun así, se examinan bastantes filas.
* Los filtros `country` y `status` se aplican después.

### Qué está pasando internamente

MySQL usa el índice para el rango de fechas, pero:

* Para cada fila encontrada, comprueba país y estado.
* Esto genera trabajo adicional.

### Idea clave

> Un índice simple no siempre es suficiente cuando hay varios filtros.

## 6) Crear un índice compuesto y repetir la consulta

Creamos un índice que cubra varias columnas.

```sql
use demo;

CREATE INDEX idx_users_country_status_created
ON users(country, status, created_at);
```

Repite la consulta anterior:

```sql
use demo;

EXPLAIN ANALYZE
SELECT COUNT(*) AS spanish_active_users_february
FROM users
WHERE created_at >= '2024-02-01'
  AND created_at <  '2024-03-01'
  AND country = 'ES'
  AND status = 1;
```

### Qué debes observar

* Menor número de filas examinadas.
* Menor tiempo de ejecución.
* El índice se usa de forma más eficiente.

### Qué está pasando internamente

El índice ya está organizado teniendo en cuenta:

1. País
2. Estado
3. Fecha

Esto reduce el trabajo antes incluso de leer las filas de la tabla.

### Idea clave

> El orden de las columnas en un índice compuesto importa.

## 7) Consulta con `ORDER BY` sobre columna indexada

```sql
use demo;

EXPLAIN ANALYZE
SELECT id, email, created_at
FROM users
WHERE created_at >= '2024-06-01'
  AND created_at <  '2024-06-02'
ORDER BY created_at
LIMIT 50;
```

### Qué debes observar

* No aparece `Using filesort`.
* El motor devuelve los resultados ya ordenados.
* El acceso es secuencial sobre el índice.

### Qué está pasando internamente

El índice ya está ordenado por `created_at`, por lo que:

* MySQL no necesita ordenar los datos en memoria o disco.

### Idea clave

> Un índice puede acelerar filtros y ordenaciones.

## 8) Inserciones masivas y coste de los índices

Este bloque ilustra el coste de mantener índices.

```sql
use demo;

DROP TABLE IF EXISTS users_noidx;
CREATE TABLE users_noidx LIKE users;

INSERT INTO users_noidx (email, created_at, country, status, plan, last_login, bio)
SELECT CONCAT(email, '.copy'), created_at, country, status, plan, last_login, bio
FROM users
LIMIT 200000;
```

Y después:

```sql
use demo;

ALTER TABLE users_noidx
ADD UNIQUE KEY uq_users_noidx_email (email);

CREATE INDEX idx_users_noidx_created_at
ON users_noidx(created_at);

CREATE INDEX idx_users_noidx_country_status_created
ON users_noidx(country, status, created_at);
```

### Qué debes observar

* Insertar sin índices es rápido.
* Crear índices después tiene un coste puntual.
* Mantener muchos índices penaliza las escrituras.

### Idea clave

> Los índices mejoran la lectura, pero encarecen la escritura.

---

## Conclusión final

* Los índices son una herramienta poderosa, pero deben diseñarse con criterio.
* No existe “el índice perfecto” para todo.
* `EXPLAIN ANALYZE` es esencial para entender el comportamiento real del motor.
* El diseño de índices debe partir de las **consultas reales**, no solo de la estructura.

> *Un buen diseñador de bases de datos piensa primero en cómo se consultan los datos, no solo en cómo se almacenan.*
