import os
import random
import uuid
from datetime import date, timedelta, datetime, timezone

from faker import Faker
import psycopg2
from psycopg2.extras import execute_batch
from pymongo import MongoClient

fake = Faker("es_ES")

# ---- Config Postgres
PG = dict(
    host=os.getenv("PGHOST", "localhost"),
    port=int(os.getenv("PGPORT", "5432")),
    dbname=os.getenv("PGDATABASE", "rbnb"),
    user=os.getenv("PGUSER", "rbnb"),
    password=os.getenv("PGPASSWORD", "rbnb"),
)

# ---- Config Mongo
MONGO_URI = os.getenv("MONGO_URI", "mongodb://mongo:27017")
MONGO_DB = os.getenv("MONGO_DB", "rbnb")

# Volumen de datos (mantenemos los nombres ENV para no tocar docker-compose.yml)
N_ANFITRIONES = int(os.getenv("GEN_HOSTS", "200"))
N_HUESPEDES = int(os.getenv("GEN_GUESTS", "2000"))
N_APARTAMENTOS = int(os.getenv("GEN_APTS", "1000"))
N_RESERVAS = int(os.getenv("GEN_BOOKINGS", "10000"))

# Ciudades base
CIUDADES = [
    ("ES", "Madrid"), ("ES", "Barcelona"), ("ES", "Valencia"),
    ("ES", "Sevilla"), ("FR", "París"), ("PT", "Lisboa"),
]

def conectar_pg():
    return psycopg2.connect(**PG)

def conectar_mongo():
    return MongoClient(MONGO_URI)

def preparar_paises_y_ciudades(cur):
    cur.execute(
        "INSERT INTO pais(codigo_pais, nombre) VALUES (%s,%s) ON CONFLICT DO NOTHING",
        ("ES", "España"),
    )
    cur.execute(
        "INSERT INTO pais(codigo_pais, nombre) VALUES (%s,%s) ON CONFLICT DO NOTHING",
        ("FR", "Francia"),
    )
    cur.execute(
        "INSERT INTO pais(codigo_pais, nombre) VALUES (%s,%s) ON CONFLICT DO NOTHING",
        ("PT", "Portugal"),
    )

    ids_ciudad = {}
    for codigo_pais, nombre_ciudad in CIUDADES:
        cur.execute(
            "INSERT INTO ciudad(codigo_pais, nombre) VALUES (%s,%s) RETURNING id_ciudad",
            (codigo_pais, nombre_ciudad),
        )
        ids_ciudad[(codigo_pais, nombre_ciudad)] = cur.fetchone()[0]

    return ids_ciudad

def insertar_usuarios(cur, n, rol):
    """
    Inserta n usuarios y los asigna al rol:
    - rol = 'anfitrion' => tabla anfitrion
    - rol = 'huesped'   => tabla huesped
    """
    usuarios = []
    for _ in range(n):
        id_usuario = uuid.uuid4()
        correo = fake.unique.email()
        usuarios.append((str(id_usuario), correo, fake.name()))

    execute_batch(
        cur,
        "INSERT INTO usuario(id_usuario, correo, nombre_completo) VALUES (%s,%s,%s)",
        usuarios,
        page_size=2000,
    )

    if rol == "anfitrion":
        anfitriones = [(u[0], random.random() < 0.18) for u in usuarios]
        execute_batch(
            cur,
            "INSERT INTO anfitrion(id_anfitrion, superanfitrion) VALUES (%s,%s)",
            anfitriones,
            page_size=2000,
        )
    else:
        huespedes = [(u[0], fake.phone_number()) for u in usuarios]
        execute_batch(
            cur,
            "INSERT INTO huesped(id_huesped, telefono) VALUES (%s,%s)",
            huespedes,
            page_size=2000,
        )

    return [u[0] for u in usuarios]

def insertar_apartamentos(cur, ids_anfitrion, ids_ciudad, n_apartamentos):
    apartamentos = []
    for _ in range(n_apartamentos):
        id_apartamento = str(uuid.uuid4())
        id_anfitrion = random.choice(ids_anfitrion)

        (codigo_pais, nombre_ciudad) = random.choice(CIUDADES)
        id_ciudad = ids_ciudad[(codigo_pais, nombre_ciudad)]

        titulo = f"{random.choice(['Ático', 'Loft', 'Estudio', 'Apartamento'])} en {nombre_ciudad}"
        direccion = fake.address().replace("\n", ", ")
        max_huespedes = random.choice([2, 3, 4, 5, 6])
        precio_base = round(random.uniform(45, 220), 2)

        apartamentos.append(
            (id_apartamento, id_anfitrion, str(id_ciudad), titulo, direccion, max_huespedes, precio_base)
        )

    execute_batch(
        cur,
        """
        INSERT INTO apartamento(id_apartamento, id_anfitrion, id_ciudad, titulo, direccion, max_huespedes, precio_base_eur)
        VALUES (%s,%s,%s,%s,%s,%s,%s)
        """,
        apartamentos,
        page_size=2000,
    )

    return apartamentos

def insertar_calendario(cur, apartamentos, dias=120):
    inicio = date.today()
    filas = []

    for (id_apartamento, _, _, _, _, _, precio_base) in apartamentos:
        for d in range(dias):
            dia = inicio + timedelta(days=d)
            disponible = random.random() < 0.75
            precio = round(float(precio_base) * random.uniform(0.85, 1.25), 2)
            filas.append((id_apartamento, dia, disponible, precio))

    execute_batch(
        cur,
        """
        INSERT INTO apartamento_dia(id_apartamento, dia, disponible, precio_eur)
        VALUES (%s,%s,%s,%s)
        ON CONFLICT (id_apartamento, dia) DO NOTHING
        """,
        filas,
        page_size=5000,
    )

def insertar_reservas_pagos_resenas(cur, apartamentos, ids_huesped, n_reservas):
    ids_apartamento = [a[0] for a in apartamentos]
    hoy = date.today()

    reservas = []
    pagos = []
    resenas = []

    for _ in range(n_reservas):
        id_reserva = str(uuid.uuid4())
        id_apartamento = random.choice(ids_apartamento)
        id_huesped = random.choice(ids_huesped)

        fecha_entrada = hoy + timedelta(days=random.randint(0, 90))
        noches = random.randint(2, 10)
        fecha_salida = fecha_entrada + timedelta(days=noches)

        estado = random.choices(
            ["PENDIENTE", "CONFIRMADA", "CANCELADA", "COMPLETADA"],
            weights=[0.08, 0.62, 0.10, 0.20],
            k=1,
        )[0]

        reservas.append((id_reserva, id_apartamento, id_huesped, fecha_entrada, fecha_salida, estado))

        # Pago (simplificado)
        importe = round(random.uniform(80, 1200), 2)
        if estado in ("CONFIRMADA", "COMPLETADA"):
            estado_pago = random.choices(["PAGADO", "FALLIDO"], weights=[0.97, 0.03], k=1)[0]
        elif estado == "CANCELADA":
            estado_pago = random.choice(["REEMBOLSADO", "INICIADO"])
        else:
            estado_pago = "INICIADO"

        pagado_en = datetime.now(timezone.utc) if estado_pago == "PAGADO" else None
        pagos.append((id_reserva, importe, estado_pago, pagado_en))

        # Reseña sólo si COMPLETADA
        if estado == "COMPLETADA" and random.random() < 0.65:
            id_resena = str(uuid.uuid4())
            valoracion = random.choices([3, 4, 5, 2, 1], weights=[0.12, 0.38, 0.42, 0.06, 0.02], k=1)[0]
            comentario = random.choice([None, fake.sentence(nb_words=12), fake.sentence(nb_words=18)])
            resenas.append((id_resena, id_reserva, valoracion, comentario))

    execute_batch(
        cur,
        """
        INSERT INTO reserva(id_reserva, id_apartamento, id_huesped, fecha_entrada, fecha_salida, estado)
        VALUES (%s,%s,%s,%s,%s,%s)
        """,
        reservas,
        page_size=5000,
    )

    execute_batch(
        cur,
        """
        INSERT INTO pago(id_reserva, importe_eur, estado, pagado_en)
        VALUES (%s,%s,%s,%s)
        ON CONFLICT (id_reserva) DO NOTHING
        """,
        pagos,
        page_size=5000,
    )

    if resenas:
        execute_batch(
            cur,
            """
            INSERT INTO resena(id_resena, id_reserva, valoracion, comentario)
            VALUES (%s,%s,%s,%s)
            ON CONFLICT (id_reserva) DO NOTHING
            """,
            resenas,
            page_size=5000,
        )

    return reservas

# -------------------------
# Mongo (colecciones en español)
# -------------------------
def sincronizar_mongo(mdb, apartamentos, mapa_ciudad_por_id):
    """
    Colecciones:
    - anuncios_busqueda: documento “desnormalizado” para búsquedas
    - disponibilidad_cache: disponibilidad diaria (consulta rápida por ciudad+fecha)
    - eventos_reserva: eventos (write-heavy, time-series)
    """
    anuncios = mdb["anuncios_busqueda"]
    disponibilidad = mdb["disponibilidad_cache"]
    eventos = mdb["eventos_reserva"]

    anuncios.delete_many({})
    disponibilidad.delete_many({})
    eventos.delete_many({})

    docs_anuncios = []
    docs_disponibilidad = []

    inicio = date.today()
    dias_cache = 60

    for (id_apartamento, id_anfitrion, id_ciudad, titulo, direccion, max_huespedes, precio_base) in apartamentos:
        nombre_ciudad = mapa_ciudad_por_id.get(id_ciudad, "Desconocida")
        valoracion = round(max(1.0, min(5.0, random.gauss(4.4, 0.4))), 2)

        docs_anuncios.append({
            "_id": str(uuid.uuid4()),
            "id_anuncio": id_apartamento,
            "id_anfitrion": id_anfitrion,
            "ciudad": nombre_ciudad,
            "titulo": titulo,
            "direccion": direccion,
            "max_huespedes": max_huespedes,
            "precio": float(precio_base),
            "valoracion": valoracion,
            "etiquetas": random.sample(
                ["centrico", "wifi", "cocina", "terraza", "vistas", "parking", "admite_mascotas"],
                k=3
            ),
            "actualizado_en": datetime.now(timezone.utc)
        })

        for d in range(dias_cache):
            dia = inicio + timedelta(days=d)
            disponible = random.random() < 0.75
            precio = round(float(precio_base) * random.uniform(0.85, 1.25), 2)

            docs_disponibilidad.append({
                "ciudad": nombre_ciudad,
                "id_apartamento": id_apartamento,
                "dia": dia.isoformat(),
                "disponible": disponible,
                "precio": precio
            })

    if docs_anuncios:
        anuncios.insert_many(docs_anuncios, ordered=False)

    if docs_disponibilidad:
        chunk = 20000
        for i in range(0, len(docs_disponibilidad), chunk):
            disponibilidad.insert_many(docs_disponibilidad[i:i + chunk], ordered=False)

def main():
    print("Conectando a Postgres...")
    pg = conectar_pg()
    pg.autocommit = False

    print("Conectando a Mongo...")
    mc = conectar_mongo()
    mdb = mc[MONGO_DB]

    with pg.cursor() as cur:
        print("Preparando países y ciudades...")
        ids_ciudad = preparar_paises_y_ciudades(cur)

        # Para Mongo: id_ciudad (uuid str) -> nombre
        mapa_ciudad_por_id = {str(v): k[1] for k, v in ids_ciudad.items()}

        print(f"Insertando {N_ANFITRIONES} anfitriones...")
        ids_anfitrion = insertar_usuarios(cur, N_ANFITRIONES, "anfitrion")

        print(f"Insertando {N_HUESPEDES} huéspedes...")
        ids_huesped = insertar_usuarios(cur, N_HUESPEDES, "huesped")

        print(f"Insertando {N_APARTAMENTOS} apartamentos...")
        apartamentos = insertar_apartamentos(cur, ids_anfitrion, ids_ciudad, N_APARTAMENTOS)

        print("Insertando calendario (120 días por apartamento)...")
        insertar_calendario(cur, apartamentos, dias=120)

        print(f"Insertando {N_RESERVAS} reservas/pagos/reseñas...")
        insertar_reservas_pagos_resenas(cur, apartamentos, ids_huesped, N_RESERVAS)

        pg.commit()
        print("Postgres OK ✅")

    print("Sincronizando Mongo (anuncios/disponibilidad)...")
    sincronizar_mongo(mdb, apartamentos, mapa_ciudad_por_id)
    print("Mongo OK ✅")
    print("Dataset listo.")

if __name__ == "__main__":
    main()
