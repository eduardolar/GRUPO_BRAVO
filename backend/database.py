from pymongo import MongoClient

MONGO_URI = "mongodb+srv://dam_grupo_bravo:cduEJRiDSc99ErTG@cluster0.wdmtidw.mongodb.net/?appName=Cluster0"
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