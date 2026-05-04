"""Conexión a MongoDB. La carga de .env se delega a `config.py`."""
import config  # carga .env una sola vez (efecto de import)
from pymongo import MongoClient

cliente = MongoClient(config.MONGO_URI)
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
