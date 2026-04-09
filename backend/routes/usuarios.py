from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import coleccion_usuarios
from models import UsuarioActualizar

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/{user_id}")
def ver_perfil(user_id: str):
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {
        "id": str(usuario["_id"]),
        "nombre": usuario["nombre"],
        "correo": usuario["correo"],
        "telefono": usuario.get("telefono", ""),
        "direccion": usuario.get("direccion", ""),
        "rol": usuario.get("rol", "cliente"),
    }

@router.put("/{user_id}")
def actualizar_perfil(user_id: str, datos: UsuarioActualizar):
    resultado = coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {
            "nombre": datos.nombre,
            "correo": datos.correo,
            "telefono": datos.telefono,
            "direccion": datos.direccion,
        }}
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"mensaje": "Perfil actualizado"}

@router.delete("/{user_id}")
def eliminar_usuario(user_id: str):
    resultado = coleccion_usuarios.delete_one({"_id": ObjectId(user_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"mensaje": "Usuario eliminado"}
