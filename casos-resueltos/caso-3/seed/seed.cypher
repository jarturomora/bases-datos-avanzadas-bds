// ============================================================
// SEED — Detección de fraude sobre grafos de pagos (ES)
// Objetivo: 30.000 nodos exactos:
//   12.000 :Cliente + 12.000 :Tarjeta + 6.000 :Comercio
// Pagos como relaciones :PAGA con propiedades (no suma nodos).
// ============================================================

// ---------- LIMPIEZA (entorno de demo) ----------
MATCH (n) DETACH DELETE n;

// ---------- CONSTRAINTS + ÍNDICES ----------
CREATE CONSTRAINT cliente_id_unico IF NOT EXISTS
FOR (c:Cliente) REQUIRE c.cliente_id IS UNIQUE;

CREATE CONSTRAINT tarjeta_id_unico IF NOT EXISTS
FOR (t:Tarjeta) REQUIRE t.tarjeta_id IS UNIQUE;

CREATE CONSTRAINT comercio_id_unico IF NOT EXISTS
FOR (m:Comercio) REQUIRE m.comercio_id IS UNIQUE;

CREATE INDEX cliente_provincia IF NOT EXISTS
FOR (c:Cliente) ON (c.provincia);

CREATE INDEX comercio_categoria IF NOT EXISTS
FOR (m:Comercio) ON (m.categoria);

CREATE INDEX comercio_riesgo IF NOT EXISTS
FOR (m:Comercio) ON (m.riesgo_comercio);

// ---------- 1) CREAR 12.000 CLIENTES ----------
CALL apoc.periodic.iterate(
  "UNWIND range(1,12000) AS i RETURN i",
  "
  WITH i,
       ['Ana','Carlos','Lucía','Javier','María','Diego','Elena','Sergio','Paula','Raúl','Carmen','Hugo','Irene','Víctor','Nuria','Adrián','Laura','Óscar','Marta','Pablo'] AS nombres,
       ['López','Pérez','Martín','Ruiz','Sánchez','Fernández','Gómez','Navarro','Romero','Torres','Vargas','Molina','Ortega','Castro','Iglesias','Santos','Silva','Ramos','Cano','Suárez'] AS apellidos,
       ['Madrid','Barcelona','Valencia','Sevilla','Zaragoza','Málaga','Murcia','Palma','Bilbao','Alicante','Córdoba','Valladolid','Vigo','Gijón','Granada','Santander'] AS provincias
  CREATE (:Cliente {
    cliente_id: 'C' + toString(i),
    nombre: nombres[toInteger(rand()*size(nombres))] + ' ' + apellidos[toInteger(rand()*size(apellidos))],
    provincia: provincias[toInteger(rand()*size(provincias))],
    riesgo_base: round(0.02 + rand()*0.20, 3)
  })
  ",
  {batchSize: 1000, parallel: true}
);

// ---------- 2) CREAR 12.000 TARJETAS ----------
CALL apoc.periodic.iterate(
  "UNWIND range(1,12000) AS i RETURN i",
  "
  WITH i
  CREATE (:Tarjeta {
    tarjeta_id: 'T' + toString(i),
    marca: CASE WHEN rand() < 0.55 THEN 'Visa' ELSE 'Mastercard' END,
    tipo:  CASE WHEN rand() < 0.60 THEN 'Crédito' ELSE 'Débito' END,
    ultimos4: toString(1000 + toInteger(rand()*8999))
  })
  ",
  {batchSize: 1500, parallel: true}
);

// ---------- 3) CREAR 6.000 COMERCIOS ----------
CALL apoc.periodic.iterate(
  "UNWIND range(1,6000) AS i RETURN i",
  "
  WITH i,
       ['Electrónica','Supermercado','Videojuegos','Viajes','Conveniencia','Moda','Gasolinera','Restauración','Farmacia','Hogar','Deportes'] AS categorias,
       ['Madrid','Barcelona','Valencia','Sevilla','Zaragoza','Málaga','Murcia','Palma','Bilbao','Alicante','Córdoba','Valladolid','Vigo','Gijón','Granada','Santander'] AS ciudades
  WITH i, categorias, ciudades,
       categorias[toInteger(rand()*size(categorias))] AS categoria,
       ciudades[toInteger(rand()*size(ciudades))] AS ciudad
  CREATE (:Comercio {
    comercio_id: 'M' + toString(i),
    nombre: 'Comercio ' + toString(i),
    categoria: categoria,
    ciudad: ciudad,
    riesgo_comercio:
      CASE
        WHEN categoria IN ['Electrónica','Videojuegos','Conveniencia','Viajes'] THEN round(0.15 + rand()*0.40, 3)
        ELSE round(0.02 + rand()*0.10, 3)
      END
  })
  ",
  {batchSize: 1000, parallel: true}
);

// ---------- 4) RELACIÓN USA (base): cada cliente usa “su” tarjeta ----------
CALL apoc.periodic.iterate(
  "MATCH (c:Cliente) RETURN c",
  "
  WITH c, toInteger(substring(c.cliente_id, 1)) AS i
  MATCH (t:Tarjeta {tarjeta_id: 'T' + toString(i)})
  MERGE (c)-[:USA {desde: date() - duration({days: toInteger(rand()*365)})}]->(t)
  ",
  {batchSize: 1000, parallel: true}
);

// ---------- 5) PATRÓN FRAUDULENTO: tarjetas compartidas (200 tarjetas “calientes”) ----------
CALL apoc.periodic.iterate(
  "UNWIND range(1,200) AS k RETURN k",
  "
  WITH k
  MATCH (t:Tarjeta {tarjeta_id: 'T' + toString(k)})
  WITH t, 10 + toInteger(rand()*20) AS n
  UNWIND range(1,n) AS j
  WITH t, toInteger(1 + rand()*12000) AS cid
  MATCH (c:Cliente {cliente_id: 'C' + toString(cid)})
  MERGE (c)-[:USA {desde: date() - duration({days: toInteger(rand()*120)})}]->(t)
  ",
  {batchSize: 20, parallel: false}
);

// ---------- 6) PAGOS COMO RELACIONES Cliente -[:PAGA]-> Comercio (con propiedades) ----------
CALL apoc.periodic.iterate(
  "MATCH (c:Cliente) RETURN c",
  "
  WITH c,
       12 + toInteger(rand()*10) AS nPagos,
       ['ONLINE','TPV','APP'] AS canales
  MATCH (c)-[:USA]->(t:Tarjeta)
  WITH c, nPagos, canales, collect(t.tarjeta_id) AS tarjetas
  UNWIND range(1, nPagos) AS x
  WITH c, canales, tarjetas,
       'M' + toString(1 + toInteger(rand()*6000)) AS mid,
       canales[toInteger(rand()*size(canales))] AS canal,
       tarjetas[toInteger(rand()*size(tarjetas))] AS tarjetaElegida
  MATCH (m:Comercio {comercio_id: mid})
  WITH c, m, canal, tarjetaElegida,
       CASE
         WHEN tarjetaElegida IN ['T1','T2','T3','T4','T5','T6','T7','T8','T9','T10'] THEN '83.45.12.9'
         WHEN rand() < 0.05 THEN '83.45.12.9'
         ELSE toString(10 + toInteger(rand()*200)) + '.' + toString(toInteger(rand()*255)) + '.' + toString(toInteger(rand()*255)) + '.' + toString(1 + toInteger(rand()*254))
       END AS ip,
       CASE
         WHEN canal='ONLINE' AND m.categoria IN ['Electrónica','Videojuegos','Viajes','Conveniencia'] THEN round(150 + rand()*1400, 2)
         ELSE round(5 + rand()*300, 2)
       END AS importe,
       CASE
         WHEN m.riesgo_comercio > 0.35 AND rand() < 0.20 THEN 'RECHAZADO'
         ELSE 'APROBADO'
       END AS estado
  CREATE (c)-[:PAGA {
    pago_id: apoc.create.uuid(),
    fecha: datetime() - duration({seconds: toInteger(rand()*2592000)}),
    importe: importe,
    moneda: 'EUR',
    canal: canal,
    estado: estado,
    tarjeta_id: tarjetaElegida,
    dispositivo_ip: ip
  }]->(m)
  ",
  {batchSize: 200, parallel: true}
);

// ---------- 7) RESUMEN ----------
MATCH (c:Cliente) WITH count(c) AS clientes
MATCH (t:Tarjeta) WITH clientes, count(t) AS tarjetas
MATCH (m:Comercio) WITH clientes, tarjetas, count(m) AS comercios
RETURN clientes, tarjetas, comercios, (clientes+tarjetas+comercios) AS total_nodos;