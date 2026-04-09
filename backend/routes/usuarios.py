from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import coleccion_usuarios
from models import UsuarioActualizar

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("") # Ruta para listar todos los usuarios
def listar_usuarios():
    usuarios = coleccion_usuarios.find()
    resultado = []
    for u in usuarios:
        resultado.append({
            "id": str(u["_id"]),
            "nombre": u.get("nombre", "Sin nombre"),
            "correo": u.get("correo", ""),
            "rol": u.get("rol", "cliente"),
            "telefono": u.get("telefono", ""),
        })
    return resultado

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


@router.get("/{user_id}")
def ver_perfil(user_id: str):
    usuario = coleccion_usuarios.find_one({
        "_id": ObjectId(user_id),
        "rol": "admin"
    })
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado o no es administrador")
    return {
        "id": str(usuario["_id"]),
        "nombre": usuario["nombre"],
        "correo": usuario["correo"],
        "telefono": usuario.get("telefono", ""),
        "direccion": usuario.get("direccion", ""),
        "rol": usuario.get("rol", "admin"),
    }

@router.get("/")
def listar_usuarios(rol: str | None = None):
    filtro = {}
    if rol:
        filtro["rol"] = rol

    usuarios = list(coleccion_usuarios.find(filtro))
    return [
        {
            "id": str(u["_id"]),
            "nombre": u["nombre"],
            "correo": u["correo"],
            "telefono": u.get("telefono", ""),
            "direccion": u.get("direccion", ""),
            "rol": u.get("rol", ""),
        }
        for u in usuarios
    ]