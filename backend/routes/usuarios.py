import bcrypt
from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import coleccion_usuarios
from models import UsuarioActualizar
from pydantic import BaseModel, EmailStr  # Necesario para que la API entienda el rol que envía Flutter

# Modelo pequeñito para recibir solo el texto del nuevo rol
class UsuarioActualizarRol(BaseModel):
    rol: str

class CambiarPassword(BaseModel):
    password_actual: str
    nueva_password: str

# NUEVO: Modelo para crear usuarios desde el panel de Admin
class UsuarioCrear(BaseModel):
    nombre: str
    correo: EmailStr # Valida que el formato sea de email
    password: str
    rol: str
    restaurante_id: str    

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/")
def listar_usuarios(rol: str | None = None):
    filtro = {}
    if rol:
        filtro["rol"] = rol

    usuarios = list(coleccion_usuarios.find(filtro))
    resultado = []
    for u in usuarios:
        # Extraemos el restaurante_id de forma segura
        res_id = u.get("restaurante_id")
        
        resultado.append({
            "id": str(u["_id"]),
            "nombre": u.get("nombre", "Sin nombre"),
            "correo": u.get("correo", ""),
            "telefono": u.get("telefono", ""),
            "direccion": u.get("direccion", ""),
            "rol": u.get("rol", "cliente"),
            # Lo convertimos a str() por si en Mongo es un ObjectId
            "restaurante_id": str(res_id) if res_id else None
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

@router.put("/{user_id}/cambiar-password")
def cambiar_password(user_id: str, datos: CambiarPassword):
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    hash_almacenado = usuario.get("password_hash", "").encode("utf-8")
    if not bcrypt.checkpw(datos.password_actual.encode("utf-8"), hash_almacenado):
        raise HTTPException(status_code=400, detail="La contraseña actual es incorrecta")

    nueva_hash = bcrypt.hashpw(datos.nueva_password.encode("utf-8"), bcrypt.gensalt())
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"password_hash": nueva_hash.decode("utf-8")}}
    )
    return {"mensaje": "Contraseña actualizada correctamente"}

# Ruta obligatoria para que funcione el botón de Flutter de "Cambiar Rol"
@router.put("/{user_id}/rol")
def actualizar_rol(user_id: str, datos: UsuarioActualizarRol):
    rol_limpio = datos.rol.strip().lower()
    
    # Aquí aceptamos los trabajos, pero también el rol de "admin" y "super_admin" para futuras necesidades de administración.
    roles_permitidos = ["cliente", "cocinero", "camarero", "mesero", "trabajador", "admin", "administrador", "super_admin", "superadministrador"]
    
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

# --- NUEVA RUTA PARA QUE EL ADMIN CREE USUARIOS ---
@router.post("/")
def crear_usuario(datos: UsuarioCrear):
    # 1. Normalizar el correo (todo a minúsculas)
    correo_limpio = datos.correo.lower().strip()

    # 2. Verificar si el correo ya existe
    if coleccion_usuarios.find_one({"correo": correo_limpio}):
        raise HTTPException(status_code=400, detail="Este correo ya está registrado")

    # 3. Encriptar la contraseña usando bcrypt 
    password_bytes = datos.password.encode("utf-8")
    salt = bcrypt.gensalt()
    hash_password = bcrypt.hashpw(password_bytes, salt).decode("utf-8")

    # 4. Preparar el documento para la base de datos
    nuevo_usuario = {
        "nombre": datos.nombre,
        "correo": correo_limpio,
        "password_hash": hash_password,
        "rol": datos.rol.lower().strip(),
        "restaurante_id": datos.restaurante_id,
        "is_verified": True, # Se crea verificado por defecto
        "telefono": "",
        "direccion": "",
        "verification_code": None
    }

    # 5. Guardar en MongoDB
    resultado = coleccion_usuarios.insert_one(nuevo_usuario)
    
    if resultado.inserted_id:
        return {
            "mensaje": "Usuario creado exitosamente",
            "id": str(resultado.inserted_id)
        }
    
    raise HTTPException(status_code=500, detail="No se pudo crear el usuario")