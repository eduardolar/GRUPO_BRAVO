from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import coleccion_usuarios
from models import UsuarioActualizar
from pydantic import BaseModel # Necesario para que la API entienda el rol que envía Flutter

# Modelo pequeñito para recibir solo el texto del nuevo rol
class UsuarioActualizarRol(BaseModel):
    rol: str

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/")
def listar_usuarios(rol: str | None = None):
    filtro = {}
    if rol:
        filtro["rol"] = rol

    usuarios = list(coleccion_usuarios.find(filtro))
    resultado = []
    for u in usuarios:
        resultado.append({
            "id": str(u["_id"]),
            "nombre": u.get("nombre", "Sin nombre"),
            "correo": u.get("correo", ""),
            "telefono": u.get("telefono", ""),
            "direccion": u.get("direccion", ""),
            "rol": u.get("rol", "cliente"),
        })
    return resultado

@router.get("/{user_id}")
def ver_perfil(user_id: str):
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {
        "id": str(usuario["_id"]),
        "nombre": usuario.get("nombre", ""),
        "correo": usuario.get("correo", ""),
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

# Ruta obligatoria para que funcione el botón de Flutter de "Cambiar Rol"
@router.put("/{user_id}/rol")
def actualizar_rol(user_id: str, datos: UsuarioActualizarRol):
    rol_limpio = datos.rol.strip().lower()
    
    # Aquí aceptamos los trabajos, pero también el rol de "admin" y "super_admin" para futuras necesidades de administración.
    roles_permitidos = ["cliente", "cocinero", "camarero", "mesero", "admin", "super_admin"]
    
    if rol_limpio not in roles_permitidos:
        raise HTTPException(status_code=400, detail=f"Rol '{rol_limpio}' no válido")

    resultado = coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"rol": rol_limpio}}
    )
    
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"mensaje": f"Rol actualizado exitosamente a {rol_limpio}"}

# Ruta para eliminar un usuario, es buena tenerla para administración futura.
@router.delete("/{user_id}")
def eliminar_usuario(user_id: str):
    resultado = coleccion_usuarios.delete_one({"_id": ObjectId(user_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return {"mensaje": "Usuario eliminado"}