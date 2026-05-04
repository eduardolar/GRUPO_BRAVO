import random
import string
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, field_validator
from database import coleccion_restaurantes
from bson import ObjectId

router = APIRouter(prefix="/restaurantes", tags=["Restaurantes"])

class RestauranteCrear(BaseModel):
    nombre: str
    direccion: str

class RestauranteEditar(BaseModel):
    nombre: str
    direccion: str
    horario_apertura: Optional[str] = None
    horario_cierre: Optional[str] = None

    @field_validator("horario_apertura", "horario_cierre", mode="before")
    @classmethod
    def validar_hora(cls, v):
        if v is None or v == "":
            return v
        parts = str(v).split(":")
        if len(parts) != 2:
            raise ValueError("Formato inválido. Use HH:MM")
        h, m = int(parts[0]), int(parts[1])
        if not (0 <= h <= 23 and 0 <= m <= 59):
            raise ValueError("Hora fuera de rango")
        return f"{h:02d}:{m:02d}"

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
    set_data = {
        "nombre": datos.nombre.strip(),
        "direccion": datos.direccion.strip(),
    }
    unset_data = {}

    if datos.horario_apertura is not None:
        if datos.horario_apertura.strip():
            set_data["horario_apertura"] = datos.horario_apertura.strip()
        else:
            unset_data["horario_apertura"] = ""

    if datos.horario_cierre is not None:
        if datos.horario_cierre.strip():
            set_data["horario_cierre"] = datos.horario_cierre.strip()
        else:
            unset_data["horario_cierre"] = ""

    update_op: dict = {"$set": set_data}
    if unset_data:
        update_op["$unset"] = unset_data

    resultado = coleccion_restaurantes.update_one(
        {"_id": ObjectId(id)},
        update_op,
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    return {"mensaje": "Restaurante actualizado"}



class RestauranteActivo(BaseModel):
    activo: bool

@router.patch("/{id}/activo")
def toggle_activo_restaurante(id: str, datos: RestauranteActivo):
    resultado = coleccion_restaurantes.update_one(
        {"_id": ObjectId(id)},
        {"$set": {"activo": datos.activo}},
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    estado = "activado" if datos.activo else "suspendido"
    return {"mensaje": f"Restaurante {estado}"}

@router.delete("/{id}")
def eliminar_restaurante(id: str):
    resultado = coleccion_restaurantes.delete_one({"_id": ObjectId(id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    return {"mensaje": "Restaurante eliminado"}