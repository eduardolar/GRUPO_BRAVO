import os
from pathlib import Path
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv(dotenv_path=Path(__file__).parent / ".env")

MONGO_URI = os.getenv("MONGO_URI")
cliente = MongoClient(MONGO_URI)
db = cliente['comandas_db']

coleccion_usuarios = db['usuarios']
coleccion_productos = db['productos']
coleccion_categorias = db['categorias']
coleccion_pedidos = db['pedidos']
coleccion_mesas = db['mesas']
coleccion_reservas = db['reservas']
coleccion_ingredientes = db['ingredientes']
coleccion_restaurantes = db["restaurantes"]