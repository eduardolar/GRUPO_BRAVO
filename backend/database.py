import os
from pathlib import Path
from pymongo import MongoClient
from dotenv import load_dotenv

# Cargar el archivo de entorno local llamado 'env' o 'env.local'
dotenv_path = Path(__file__).with_name("env")
dotenv_local_path = Path(__file__).with_name("env.local")
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
elif dotenv_local_path.exists():
    load_dotenv(dotenv_path=dotenv_local_path)
else:
    load_dotenv()
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
coleccion_auditoria_pagos = db["auditoria_pagos"]
coleccion_auditoria = db["auditoria"]
coleccion_cupones = db["cupones"]
