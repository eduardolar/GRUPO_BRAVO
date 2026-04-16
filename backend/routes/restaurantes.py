from fastapi import APIRouter, HTTPException
from database import coleccion_restaurantes
from bson import ObjectId

router = APIRouter(prefix="/restaurantes", tags=["Restaurantes"])

@router.get("")
def listar_restaurantes():
    try:
        # Buscamos todos los restaurantes en la base de datos
        restaurantes = list(coleccion_restaurantes.find())
        
        # Convertimos el ObjectId de Mongo a un String para que Flutter lo entienda
        for res in restaurantes:
            res["id"] = str(res["_id"])
            del res["_id"] # Limpiamos el original para evitar errores de JSON
            
        return restaurantes
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al obtener restaurantes: {str(e)}")

# Opcional: Ruta para obtener uno solo por ID
@router.get("/{id}")
def obtener_restaurante(id: str):
    restaurante = coleccion_restaurantes.find_one({"_id": ObjectId(id)})
    if restaurante:
        restaurante["id"] = str(restaurante["_id"])
        del restaurante["_id"]
        return restaurante
    raise HTTPException(status_code=404, detail="Restaurante no encontrado")