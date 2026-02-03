FROM python:3.11-slim

WORKDIR /app

# Dependencias del script
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY load_imdb_demo.py .

# Cache de descargas (para no bajar todo cada vez)
ENV HF_HOME=/cache/hf
ENV TRANSFORMERS_CACHE=/cache/hf
ENV HF_DATASETS_CACHE=/cache/hf

CMD ["python", "load_imdb_demo.py"]