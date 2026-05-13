# ============================================================================
# backend/database.py
# ----------------------------------------------------------------------------
# Conexión a MongoDB y handles de las colecciones que usa la aplicación.
#
# Convenciones del proyecto:
#   - Cliente síncrono (`pymongo.MongoClient`): el código está escrito en
#     estilo bloqueante. Sí, FastAPI es async, pero MongoDB tiene un thread
#     pool propio y para una tienda con tráfico bajo-medio funciona bien.
#     Si en el futuro hubiera cuellos de botella, se podría migrar a
#     `motor` (driver async de Mongo) sin reescribir la lógica de negocio.
#   - Base de datos única: "comandas_db". Multi-tenant se implementa a nivel
#     de DOCUMENTO con el campo `restaurante_id`, no creando una BD por
#     restaurante (más simple de operar y de hacer queries cross-tenant).
#   - Las colecciones se exponen como variables módulo para que el resto del
#     código haga `from database import coleccion_pedidos`. Es un singleton
#     compartido: una sola conexión TCP, varios "handles" sobre ella.
#
# La conexión se establece en el momento del import (línea `cliente = ...`),
# que ocurre temprano gracias a `import config` (carga del .env). Por eso
# `MONGO_URI` ya está disponible aquí.
# ============================================================================
"""Conexión a MongoDB. La carga de .env se delega a `config.py`."""
import config  # carga .env una sola vez (efecto de import)
from pymongo import MongoClient

# `MongoClient` es lazy: la conexión TCP real se abre con la primera query.
# Aun así crea el pool de conexiones interno y valida la URI.
cliente = MongoClient(config.MONGO_URI)

# Base de datos por defecto del proyecto. "comandas_db" se llama así por
# motivos históricos (antes la app solo gestionaba comandas).
db = cliente['comandas_db']

# --- Handles de colecciones --------------------------------------------------
# Una "colección" en Mongo equivale a una tabla en SQL. Aquí solo creamos
# referencias; las colecciones se crean en Mongo automáticamente al insertar
# el primer documento (lazy). Los índices se gestionan aparte (ver scripts/
# o configuración manual en Atlas, ya documentada en MEMORY).
coleccion_usuarios = db['usuarios']             # cuentas (cliente, camarero, cocinero, admin, super_admin)
coleccion_productos = db['productos']           # carta: platos, bebidas, etc.
coleccion_categorias = db['categorias']         # entrantes, principales, postres...
coleccion_pedidos = db['pedidos']               # pedidos de cliente o de sala
coleccion_mesas = db['mesas']                   # mapa de mesas con QR
coleccion_reservas = db['reservas']             # reservas de mesa
coleccion_ingredientes = db['ingredientes']     # stock de ingredientes y composición
coleccion_restaurantes = db["restaurantes"]     # sucursales (multi-tenant)
coleccion_auditoria_pagos = db["auditoria_pagos"]  # eventos Stripe/PayPal (auditoría PCI)
coleccion_auditoria = db["auditoria"]           # auditoría general (cambios de rol, etc.)
coleccion_cupones = db["cupones"]               # códigos de descuento
coleccion_cierres_caja = db["cierres_caja"]     # cierres Z por turno/día
coleccion_avisos_falta = db["avisos_falta"]     # avisos a admin de stock bajo
