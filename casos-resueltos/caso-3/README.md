# Caso 3: Detección de fraude sobre grafos de pagos

## Introducción al escenario

En esta demo analizamos **fraude en pagos** usando **Neo4j**. En vez de ver transacciones como filas, las vemos como una **red**:

* **Cliente** (quién paga)
* **Tarjeta** (con qué paga)
* **Comercio** (dónde paga)
* El pago es una relación `:PAGA` (con `importe`, `canal`, `estado`, `dispositivo_ip`, etc.)
* `:USA` conecta cliente–tarjeta

La idea clave: el fraude suele dejar **patrones repetidos** y, en grafos, esos patrones se vuelven muy visibles.

### Qué indican los riesgos que verás en los grafos

* **Tarjetas compartidas por muchos clientes (forma de “estrella”)**: posible suplantación o uso coordinado.
* **Grupos o cadenas de clientes conectados por tarjetas**: posible colusión (red de cuentas relacionadas).
* **Muchos pagos ONLINE desde la misma IP**: posible automatización/granja de fraude.
* **Pagos altos en comercios con mayor `riesgo_comercio`**: priorización de investigación (impacto + contexto).

En la demo no buscamos “culpables”, sino **señales** para **priorizar** qué clientes, tarjetas y comercios investigar primero.

## Estructura del proyecto (docker)

```text
fraude-grafos-neo4j/
├─ docker-compose.yml
├─ neo4j/
│  └─ conf/
│     └─ neo4j.conf
└─ seed/
   ├─ seed.cypher
   └─ run-seed-via-docker.sh
```

## 1) Levanta el entorno con Docker

Levanta el contenedor utilizando la extensión Container Tools de Visual Studio Code (VSCode) o ejecutando el siguiente comando desde la terminal.

```bash
docker compose up -d
```

Abre Neo4j Browser en tu navegador web:

* `http://localhost:7474`
* usuario: `neo4j`
* contraseña: `neo4j1234`

## 2) Verifica que el grafo está cargado (sanity check)

Ejecuta:

```cypher
MATCH (n)
RETURN labels(n)[0] AS etiqueta, count(*) AS total
ORDER BY total DESC;
```

**Qué debes ver**

* `Cliente` ≈ 12000
* `Tarjeta` ≈ 12000
* `Comercio` ≈ 6000

**Qué significa**

* Ya tienes el “universo” de entidades sobre el que buscar patrones de fraude.

## 3) Visualiza el primer gran patrón: tarjetas compartidas (hub-and-spoke)

Ejecuta:

```cypher
MATCH (t:Tarjeta)<-[:USA]-(c:Cliente)
WITH t, count(c) AS n
WHERE n >= 15
RETURN t, n
ORDER BY n DESC
LIMIT 15;
```

**Cómo verlo en pantalla (Graph)**

* Cambia a vista **Graph**.
* Observa nodos `Tarjeta` con muchos `Cliente` alrededor (estructura “estrella”).

**Interpretación**

* Una tarjeta compartida por muchos clientes es una señal típica de: suplantación, “mulas”, cuentas controladas por un mismo actor.

## 4) Entra al detalle de una tarjeta sospechosa (subgrafo claro)

Elige una tarjeta del top (por ejemplo `T1`) y ejecuta:

```cypher
MATCH (t:Tarjeta {tarjeta_id:'T1'})<-[:USA]-(c:Cliente)
RETURN t, c
LIMIT 200;
```

**Qué mirar**

* Provincias distintas, perfiles variados, y muchos clientes colgando del mismo instrumento.

**Interpretación**

* Este subgrafo suele ser un “núcleo” para investigación.

## 5) Visualiza conexiones entre clientes por tarjetas (Cliente → Tarjeta → Cliente)

Ejecuta:

```cypher
MATCH (c1:Cliente {cliente_id:'C1'})-[:USA]->(t:Tarjeta)<-[:USA]-(c2:Cliente)
WHERE c1 <> c2
RETURN c1, t, c2
LIMIT 150;
```

**Qué mirar**

* ¿Cuántos clientes se conectan con `C1` por compartir tarjeta?
* ¿Aparece 1 tarjeta con muchos clientes o varias tarjetas con pequeños grupos?

**Interpretación**

* Sirve para detectar “vecindarios” sospechosos: si `C1` está implicado, sus conectados suelen ser relevantes.

## 6) Amplía el “radio” con rutas de 2 saltos (cadenas de colusión)

Ejecuta:

```cypher
MATCH (c1:Cliente {cliente_id:'C1'})-[:USA]->(:Tarjeta)<-[:USA]-(c2:Cliente)
MATCH (c2)-[:USA]->(:Tarjeta)<-[:USA]-(c3:Cliente)
WHERE c3 <> c1
RETURN c1, c2, c3
LIMIT 150;
```

**Qué mirar**

* Aparición de **cadenas**: C1 conectado a C3 pasando por un intermediario.
* Si ves “racimos”, es indicio de comunidad informal (posible colusión).

**Interpretación**

* Las redes de fraude rara vez son un único nodo: suelen tener varios “eslabones”.

## 7) Visualiza el grafo de pagos hacia comercios (bipartito Cliente → Comercio)

Primero identifica los comercios con más pagos ONLINE aprobados y luego dibuja su subgrafo:

```cypher
MATCH (c:Cliente)-[p:PAGA]->(m:Comercio)
WHERE p.canal='ONLINE' AND p.estado='APROBADO'
WITH m, count(*) AS n
ORDER BY n DESC
LIMIT 5
MATCH (c:Cliente)-[p:PAGA]->(m)
WHERE p.canal='ONLINE' AND p.estado='APROBADO'
RETURN c, p, m
LIMIT 250;
```

**Qué mirar**

* Comercios “atractores” (muchos clientes apuntan a pocos comercios).
* Propiedades del comercio: `categoria`, `riesgo_comercio`.

**Interpretación**

* La concentración puede ser normal (grandes comercios) o sospechosa (fraude focalizado). El riesgo del comercio ayuda a priorizar.

## 8) Filtra a “casos de investigación”: importes altos en comercios de riesgo

Ejecuta:

```cypher
MATCH (c:Cliente)-[p:PAGA]->(m:Comercio)
WHERE p.estado='APROBADO'
  AND p.importe >= 800
  AND m.riesgo_comercio >= 0.30
RETURN c, p, m
ORDER BY p.importe DESC
LIMIT 120;
```

**Qué mirar**

* Grafo más limpio: pocos nodos, relaciones con `importe`, `canal`, `dispositivo_ip`.
* Ideal para explicar “priorización”.

**Interpretación**

* Estás construyendo una lista corta: alto impacto económico + contexto de riesgo.

## 9) Detecta fraude automatizado: IPs repetidas con muchos pagos ONLINE

Ejecuta:

```cypher
MATCH (c:Cliente)-[p:PAGA]->(m:Comercio)
WHERE p.canal = 'ONLINE'
WITH p.dispositivo_ip AS ip, count(*) AS n, sum(p.importe) AS total
WHERE ip IS NOT NULL AND n >= 80
RETURN ip, n AS num_pagos, round(total,2) AS importe_total
ORDER BY num_pagos DESC
LIMIT 10;
```

**Qué mirar**

* Identifica una IP top (en este dataset suele aparecer `83.45.12.9`).

**Interpretación**

* Muchas transacciones online desde una misma IP sugieren automatización, bot, granja o abuso de VPN/proxy.

## 10) Dibuja el subgrafo de una IP sospechosa

Usa una IP del paso anterior (por ejemplo `83.45.12.9`):

```cypher
MATCH (c:Cliente)-[p:PAGA]->(m:Comercio)
WHERE p.dispositivo_ip='83.45.12.9' AND p.canal='ONLINE'
RETURN c, p, m
LIMIT 250;
```

**Qué mirar**

* “Racimos” de clientes y comercios conectados por la misma IP.
* Si se ve demasiado denso, reduce `LIMIT` a 120.

**Interpretación**

* Es evidencia estructural: no es un pago aislado, es un patrón repetido con conectividad.

## 11) Señal adicional: clientes con muchas tarjetas (posible suplantación)

Ejecuta:

```cypher
MATCH (c:Cliente)-[:USA]->(t:Tarjeta)
WITH c, count(t) AS n
WHERE n >= 3
RETURN c, n
ORDER BY n DESC
LIMIT 25;
```

**Qué mirar**

* Clientes con múltiples tarjetas asociadas: revisar si coincide con IP sospechosa o comercios de riesgo.

**Interpretación**

* En fraude es común ver “rotación” de instrumentos de pago.

## 12) Cierra con un ranking simple de clientes sospechosos (lista corta)

Combina señales: nº de tarjetas, gasto online, eventos en IP sospechosa.

```cypher
MATCH (c:Cliente)
OPTIONAL MATCH (c)-[:USA]->(t:Tarjeta)
WITH c, count(DISTINCT t) AS tarjetas
OPTIONAL MATCH (c)-[p:PAGA]->(:Comercio)
WITH c, tarjetas,
     sum(CASE WHEN p.canal='ONLINE' AND p.estado='APROBADO' THEN p.importe ELSE 0 END) AS gasto_online,
     sum(CASE WHEN p.dispositivo_ip='83.45.12.9' AND p.canal='ONLINE' THEN 1 ELSE 0 END) AS eventos_ip_sospechosa
RETURN c.cliente_id, c.nombre, c.provincia,
       tarjetas,
       round(gasto_online,2) AS gasto_online,
       eventos_ip_sospechosa
ORDER BY eventos_ip_sospechosa DESC, tarjetas DESC, gasto_online DESC
LIMIT 20;
```

**Qué mirar**

* Los “top” son candidatos para abrir investigación (ver su subgrafo con pasos 5, 7, 10).

**Interpretación**

* El grafo permite priorizar combinando contexto (relaciones) + señales (atributos).
