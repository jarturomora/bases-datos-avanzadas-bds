import os
from pymongo import MongoClient

MONGO_URI = os.getenv("MONGO_URI", "mongodb://mongo:27017/?replicaSet=rs0")
DB_NAME = os.getenv("DB_NAME", "eco_store")

client = MongoClient(MONGO_URI)
db = client[DB_NAME]