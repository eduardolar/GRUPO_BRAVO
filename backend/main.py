from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel
from typing import List

# Creamos la aplicación
app = FastAPI(title="API de Comandas grupo Bravo")

# --- CONEXIÓN A MONGO CLOUD ---

MONGO_URL = "mongodb+srv://dam_grupo_bravo:cduEJRiDSc99ErTG@cluster0.wdmtidw.mongodb.net/?appName=Cluster0" 
client = AsyncIOMotorClient(MONGO_URL)
db = client.comandas_db # Así se llama tu base de datos en la nube

# --- MODELO DE DATOS ---
# Esto le dice a Python cómo es un Producto (igual que JSON)
class Producto(BaseModel):
    nombre: str
    precio: float
    categoria: str

# --- RUTAS (Lo que la Tablet pedirá) ---

@app.get("/")
async def inicio():
    return {"mensaje": "Bienvenida al Backend, Grupo Bravo. El sistema está en línea."}

@app.get("/productos")
async def obtener_productos():
    # Buscamos en la colección 'productos' de MongoDB
    cursor = db.productos.find()
    productos = []
    async for documento in cursor:
        # Quitamos el ID de Mongo para que no dé problemas al enviarlo
        documento["_id"] = str(documento["_id"])
        productos.append(documento)
    return productos