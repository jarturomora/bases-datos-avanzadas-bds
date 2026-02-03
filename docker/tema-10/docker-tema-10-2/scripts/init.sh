#!/usr/bin/env bash
set -euo pipefail

echo "==> Esperando a Cassandra (cass1:9042)..."
until cqlsh cass1 9042 -e "SELECT release_version FROM system.local" >/dev/null 2>&1; do
  sleep 3
done

echo "==> Creando esquema..."
cat > /tmp/init.cql <<'CQL'
CREATE KEYSPACE IF NOT EXISTS ecommerce
WITH replication = {'class':'SimpleStrategy','replication_factor':3};

USE ecommerce;

CREATE TABLE IF NOT EXISTS products_by_id (
  product_id text PRIMARY KEY,
  name text,
  category text,
  price decimal,
  stock int
);

CREATE TABLE IF NOT EXISTS customers_by_id (
  customer_id text PRIMARY KEY,
  full_name text,
  email text,
  city text,
  created_at timestamp
);

CREATE TABLE IF NOT EXISTS orders_by_id (
  customer_id text,
  order_id text,
  order_ts timestamp,
  status text,
  total decimal,
  PRIMARY KEY ((customer_id), order_id)
);

CREATE TABLE IF NOT EXISTS order_items_by_order (
  order_id text,
  line_no int,
  product_id text,
  qty int,
  unit_price decimal,
  line_total decimal,
  PRIMARY KEY ((order_id), line_no)
);
CQL

echo "==> Generando ~1000 inserts..."
categories=(electronics books home fashion sports)
cities=(Madrid Barcelona Valencia Sevilla Bilbao Malaga Zaragoza Murcia Palma Vigo)

# 300 productos
for i in $(seq -w 1 300); do
  idx=$((10#$i))
  cat_idx=$((idx % 5))
  price_int=$(((idx % 100) + 5))
  stock=$(((idx % 50) + 10))
  printf "INSERT INTO ecommerce.products_by_id (product_id,name,category,price,stock) VALUES ('prod_%s','Product %s','%s',%d.99,%d);\n" \
    "$i" "$i" "${categories[$cat_idx]}" "$price_int" "$stock" >> /tmp/init.cql
done

# 200 clientes
for i in $(seq -w 1 200); do
  idx=$((10#$i))
  city_idx=$((idx % 10))
  printf "INSERT INTO ecommerce.customers_by_id (customer_id,full_name,email,city,created_at) VALUES ('cust_%s','Customer %s','cust%s@example.com','%s',toTimestamp(now()));\n" \
    "$i" "$i" "$i" "${cities[$city_idx]}" >> /tmp/init.cql
done

# 200 pedidos
for i in $(seq -w 1 200); do
  idx=$((10#$i))
  cust=$(((idx % 200) + 1))
  cust_id=$(printf "cust_%04d" "$cust")
  total_int=$(((idx % 120) + 20))
  status="PAID"
  printf "INSERT INTO ecommerce.orders_by_id (customer_id,order_id,order_ts,status,total) VALUES ('%s','order_%s',toTimestamp(now()),'%s',%d.50);\n" \
    "$cust_id" "$i" "$status" "$total_int" >> /tmp/init.cql
done

# 300 líneas de pedido
for j in $(seq -w 1 300); do
  idx=$((10#$j))
  ord=$(((idx % 200) + 1))
  order_id=$(printf "order_%04d" "$ord")

  prod=$(((idx % 300) + 1))
  product_id=$(printf "prod_%04d" "$prod")

  line_no=$(((idx % 4) + 1))
  qty=$(((idx % 3) + 1))
  unit_int=$(((prod % 100) + 5))
  line_total_int=$((unit_int * qty))

  printf "INSERT INTO ecommerce.order_items_by_order (order_id,line_no,product_id,qty,unit_price,line_total) VALUES ('%s',%d,'%s',%d,%d.99,%d.97);\n" \
    "$order_id" "$line_no" "$product_id" "$qty" "$unit_int" "$line_total_int" >> /tmp/init.cql
done

echo "==> Ejecutando CQL..."
cqlsh cass1 9042 -f /tmp/init.cql

echo "==> Conteos (esperado: 300/200/200/300)"
cqlsh cass1 9042 -e "SELECT count(*) FROM ecommerce.products_by_id;"
cqlsh cass1 9042 -e "SELECT count(*) FROM ecommerce.customers_by_id;"
cqlsh cass1 9042 -e "SELECT count(*) FROM ecommerce.orders_by_id;"
cqlsh cass1 9042 -e "SELECT count(*) FROM ecommerce.order_items_by_order;"

echo "==> Finalizado."
