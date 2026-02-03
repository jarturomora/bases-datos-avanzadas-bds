import json
import os
from typing import Dict, Any, Iterable, Tuple, Optional

import pandas as pd
import requests
from datasets import load_dataset

# ============================================================
# CONFIGURACIÓN GENERAL
# ============================================================
# URL base de los volcados oficiales de IMDb (TSV comprimidos en .gz)
IMDB_BASE = "https://datasets.imdbws.com"

# Ficheros oficiales que vamos a usar:
# - title.basics.tsv.gz   -> metadatos de títulos (películas, series, etc.)
# - title.ratings.tsv.gz  -> rating medio y número de votos por título
BASICS = "title.basics.tsv.gz"
RATINGS = "title.ratings.tsv.gz"


# ============================================================
# UTILIDADES DE DESCARGA
# ============================================================
def download_if_missing(url: str, path: str) -> None:
    """
    Descarga el fichero 'url' a 'path' si no existe o está vacío.
    Se usa para cachear datos y no descargarlos cada vez.
    """
    if os.path.exists(path) and os.path.getsize(path) > 0:
        # Ya existe y tiene contenido -> no descargamos
        return

    os.makedirs(os.path.dirname(path), exist_ok=True)
    print(f"Descargando {url} -> {path}")

    # Descarga en streaming (por trozos) para no consumir mucha RAM
    with requests.get(url, stream=True, timeout=180) as r:
        r.raise_for_status()
        with open(path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)


# ============================================================
# CARGA Y PREPARACIÓN DE METADATOS IMDb (basics + ratings)
# ============================================================
def load_imdb_metadata(basics_path: str, ratings_path: str) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Lee los TSV oficiales (comprimidos) y devuelve dos DataFrames:
    - df_basics: metadatos de títulos (filtrado a titleType='movie')
    - df_ratings: rating medio y numVotes
    """
    # IMDb usa '\N' para valores nulos
    na = ["\\N"]

    # Leemos los TSV comprimidos (.gz) directamente con pandas
    df_basics = pd.read_csv(
        basics_path,
        sep="\t",
        compression="gzip",
        dtype=str,         # leemos todo como string inicialmente (más robusto)
        na_values=na,
        low_memory=False
    )
    df_ratings = pd.read_csv(
        ratings_path,
        sep="\t",
        compression="gzip",
        dtype=str,
        na_values=na,
        low_memory=False
    )

    # Nos quedamos solo con películas (no series, no episodios, etc.)
    df_basics = df_basics[df_basics["titleType"] == "movie"].copy()

    # Convertimos algunos campos a numérico (si falla, se pone NaN)
    df_basics["startYear"] = pd.to_numeric(df_basics["startYear"], errors="coerce")
    df_basics["runtimeMinutes"] = pd.to_numeric(df_basics["runtimeMinutes"], errors="coerce")

    df_ratings["averageRating"] = pd.to_numeric(df_ratings["averageRating"], errors="coerce")
    df_ratings["numVotes"] = pd.to_numeric(df_ratings["numVotes"], errors="coerce")

    return df_basics, df_ratings


def build_lookup_tables(df_basics: pd.DataFrame, df_ratings: pd.DataFrame) -> Dict[str, Dict[str, Any]]:
    """
    Une df_basics con df_ratings por 'tconst' (id de IMDb tipo tt1234567)
    y crea un diccionario:
        lookup[movie_id] -> { title, year, genres, runtime_minutes, imdb_average_rating, imdb_num_votes }
    para enriquecer las reviews luego.
    """
    # Hacemos un join (left) para conservar todas las películas aunque no tengan rating
    df = df_basics.merge(df_ratings, how="left", on="tconst")

    lookup: Dict[str, Dict[str, Any]] = {}

    # itertuples es más rápido que iterrows en pandas
    for row in df.itertuples(index=False):
        movie_id = getattr(row, "tconst")  # ej: tt0111161
        genres = getattr(row, "genres")    # ej: "Drama,Crime"

        lookup[movie_id] = {
            "title": getattr(row, "primaryTitle"),
            "year": None if pd.isna(getattr(row, "startYear")) else int(getattr(row, "startYear")),
            "genres": [] if pd.isna(genres) else str(genres).split(","),
            "runtime_minutes": None if pd.isna(getattr(row, "runtimeMinutes")) else int(getattr(row, "runtimeMinutes")),
            "imdb_average_rating": None if pd.isna(getattr(row, "averageRating")) else float(getattr(row, "averageRating")),
            "imdb_num_votes": None if pd.isna(getattr(row, "numVotes")) else int(getattr(row, "numVotes")),
        }

    return lookup


# ============================================================
# UTILIDADES PARA LEER EL DATASET DE REVIEWS (Hugging Face)
# ============================================================
def pick_first_key(d: Dict[str, Any], candidates: Iterable[str]) -> Optional[str]:
    """
    Dado un diccionario d y una lista de claves candidatas,
    devuelve la primera clave que exista en el diccionario.
    Esto permite adaptarnos a datasets con nombres de campo distintos.
    """
    for k in candidates:
        if k in d:
            return k
    return None


def hf_records(dataset_name: str, splits: Iterable[str]) -> Iterable[Tuple[str, Dict[str, Any]]]:
    """
    Itera sobre varios splits posibles (train/test/unsupervised, etc.).
    Devuelve tuplas (split, record_dict).
    """
    for sp in splits:
        try:
            ds = load_dataset(dataset_name, split=sp)
        except Exception:
            # Si el split no existe o falla, lo saltamos
            continue
        for rec in ds:
            yield sp, rec


# ============================================================
# INDEXACIÓN: BULK API EN ELASTICSEARCH (NDJSON)
# ============================================================
def iter_bulk_lines(index: str, docs: Iterable[Dict[str, Any]]) -> Iterable[str]:
    """
    Genera líneas NDJSON para el endpoint _bulk.
    Para cada documento hay 2 líneas:
      1) acción: {"index": {"_index": "...", "_id": "..."}}
      2) documento JSON
    """
    for doc in docs:
        rid = doc.get("review_id")
        action = {"index": {"_index": index, "_id": rid}}
        yield json.dumps(action, ensure_ascii=False)
        yield json.dumps(doc, ensure_ascii=False)


def bulk_send(es: str, lines: Iterable[str], chunk_docs: int = 1000) -> None:
    """
    Envía a Elasticsearch mediante Bulk API en lotes de 'chunk_docs' documentos.
    Cada documento son 2 líneas NDJSON.
    """
    bulk_url = es.rstrip("/") + "/_bulk"
    headers = {"Content-Type": "application/x-ndjson"}

    buffer_lines = []
    docs_in_buffer = 0

    def flush():
        """
        Envía el buffer actual a Elasticsearch.
        Importante: el payload NDJSON debe terminar en '\n'.
        """
        nonlocal buffer_lines, docs_in_buffer
        if not buffer_lines:
            return

        payload = "\n".join(buffer_lines) + "\n"
        resp = requests.post(bulk_url, headers=headers, data=payload.encode("utf-8"), timeout=180)
        resp.raise_for_status()

        out = resp.json()
        if out.get("errors"):
            # Si hay errores, mostramos algunos ejemplos para depurar
            errors = [it for it in out.get("items", []) if list(it.values())[0].get("error")]
            print(f"\nBulk terminó con errores: {len(errors)} items fallaron.")
            print(json.dumps(errors[:3], indent=2)[:2000])
            raise RuntimeError("Bulk indexing devolvió errores.")

        # Limpiamos buffer
        buffer_lines = []
        docs_in_buffer = 0

    # Vamos acumulando líneas; cada 2 líneas añadimos 1 doc
    for line in lines:
        buffer_lines.append(line)
        if len(buffer_lines) % 2 == 0:
            docs_in_buffer += 1

        if docs_in_buffer >= chunk_docs:
            flush()

    flush()


# ============================================================
# PROGRAMA PRINCIPAL
# ============================================================
def main():
    """
    Flujo general:
      1) Lee variables de entorno (para Docker)
      2) Descarga TSV oficiales de IMDb (si faltan)
      3) Carga metadata de películas + ratings medio
      4) Carga reviews desde Hugging Face
      5) Une/enriquece por movie_id (tt...)
      6) Indexa en Elasticsearch con Bulk API
    """
    # Variables pensadas para docker-compose (pero funcionan también fuera)
    es_url = os.environ.get("ES_URL", "http://localhost:9200")
    index_name = os.environ.get("INDEX_NAME", "imdb_reviews")
    max_docs = int(os.environ.get("MAX_DOCS", "20000"))

    # Carpeta de cache (en docker la montamos en un volumen)
    cache_dir = os.environ.get("CACHE_DIR", "/cache/imdb")
    basics_path = os.path.join(cache_dir, BASICS)
    ratings_path = os.path.join(cache_dir, RATINGS)

    # 1) Descarga IMDb official (solo si hace falta)
    download_if_missing(f"{IMDB_BASE}/{BASICS}", basics_path)
    download_if_missing(f"{IMDB_BASE}/{RATINGS}", ratings_path)

    # 2) Carga y prepara metadatos + ratings
    print("Cargando metadatos de IMDb...")
    df_basics, df_ratings = load_imdb_metadata(basics_path, ratings_path)
    lookup = build_lookup_tables(df_basics, df_ratings)
    print(f"Metadatos listos para {len(lookup):,} películas.")

    # 3) Dataset de reviews
    # Nota: este dataset (fgiobergia/imdb-id) incluye movie_id tipo tt... y score 1..10
    dataset_name = "fgiobergia/imdb-id"
    splits_to_try = ["train", "test", "unsupervised"]

    # 4) Detectamos automáticamente los campos (text, movie_id, score, label)
    first = None
    for sp, rec in hf_records(dataset_name, splits_to_try):
        first = (sp, rec)
        break
    if first is None:
        raise RuntimeError("No se pudo cargar ningún split del dataset de reviews.")

    _, sample = first
    k_text = pick_first_key(sample, ["text", "review", "review_text", "content"])
    k_movie = pick_first_key(sample, ["movie_id", "movieid", "imdb_id", "id"])
    k_score = pick_first_key(sample, ["score", "rating", "stars", "raw_score"])
    k_label = pick_first_key(sample, ["label", "sentiment", "polarity"])

    if not (k_text and k_movie):
        raise RuntimeError(f"No encuentro campos de texto/movie_id. Keys disponibles: {list(sample.keys())}")

    print(f"Campos detectados: texto={k_text}, movie_id={k_movie}, score={k_score}, label={k_label}")

    # 5) Construimos documentos listos para Elasticsearch
    docs = []
    n = 0

    for sp, rec in hf_records(dataset_name, splits_to_try):
        if n >= max_docs:
            break

        # movie_id es el tconst (ttXXXXXXX)
        movie_id = str(rec.get(k_movie))

        # Texto de la review
        review_text = rec.get(k_text, "")

        # Score/rating del usuario (idealmente 1..10)
        score = rec.get(k_score) if k_score else None

        # Label opcional (p.ej. pos/neg)
        label = rec.get(k_label) if k_label else None

        # Normalización del rating a entero
        user_rating = None
        if score is not None:
            try:
                user_rating = int(float(score))
            except Exception:
                user_rating = None

        # Enriquecimiento con metadatos oficiales IMDb (si existe esa película)
        meta = lookup.get(movie_id, {})

        doc = {
            # ID único de la review en el índice
            "review_id": f"{sp}-{n}",
            "movie_id": movie_id,

            # Dataset split (train/test/...)
            "split": sp,

            # Etiqueta opcional (sentimiento)
            "sentiment_label": str(label) if label is not None else None,

            # Rating del usuario (1..10)
            "user_rating": user_rating,

            # Texto completo de la review
            "review_text": str(review_text) if review_text is not None else "",

            # Campos enriquecidos (IMDb official)
            "title": meta.get("title"),
            "year": meta.get("year"),
            "genres": meta.get("genres", []),
            "runtime_minutes": meta.get("runtime_minutes"),
            "imdb_average_rating": meta.get("imdb_average_rating"),
            "imdb_num_votes": meta.get("imdb_num_votes"),
        }

        # Quitamos campos None para no ensuciar el índice (opcional)
        doc = {k: v for k, v in doc.items() if v is not None}

        docs.append(doc)
        n += 1

    print(f"Documentos preparados: {len(docs):,}. Indexando en Elasticsearch...")

    # 6) Enviamos a Elasticsearch por Bulk API
    bulk_send(es_url, iter_bulk_lines(index_name, docs), chunk_docs=1000)

    print("Carga finalizada ✅")


if __name__ == "__main__":
    main()