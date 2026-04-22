import random
import string
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import coleccion_restaurantes
from bson import ObjectId

router = APIRouter(prefix="/restaurantes", tags=["Restaurantes"])

class RestauranteCrear(BaseModel):
    nombre: str
    direccion: str

class RestauranteEditar(BaseModel):
    nombre: str
    direccion: str

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

@router.post("")
def crear_restaurante(datos: RestauranteCrear):
    codigo = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    nuevo = {
        "nombre": datos.nombre.strip(),
        "direccion": datos.direccion.strip(),
        "codigo": codigo,
    }
    resultado = coleccion_restaurantes.insert_one(nuevo)
    return {"id": str(resultado.inserted_id), "nombre": nuevo["nombre"], "direccion": nuevo["direccion"], "codigo": codigo}

@router.put("/{id}")
def editar_restaurante(id: str, datos: RestauranteEditar):
    resultado = coleccion_restaurantes.update_one(
        {"_id": ObjectId(id)},
        {"$set": {"nombre": datos.nombre.strip(), "direccion": datos.direccion.strip()}}
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    return {"mensaje": "Restaurante actualizado"}

@router.delete("/{id}")
def eliminar_restaurante(id: str):
    resultado = coleccion_restaurantes.delete_one({"_id": ObjectId(id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    return {"mensaje": "Restaurante eliminado"}