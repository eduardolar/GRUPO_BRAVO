import os
from pathlib import Path
from pymongo import MongoClient
from dotenv import load_dotenv

# Cargar el archivo de entorno local llamado 'env'
dotenv_path = Path(__file__).with_name("env")
load_dotenv(dotenv_path=dotenv_path)

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