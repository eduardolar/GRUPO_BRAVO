import random
import string
import bcrypt
from fastapi import APIRouter, HTTPException, Header
from bson import ObjectId
from database import coleccion_usuarios
from models import UsuarioActualizar
from pydantic import BaseModel, EmailStr
from fastapi_mail import FastMail, MessageSchema, MessageType
from typing import Optional

# Importar la configuración de correo desde auth
from routes.auth import conf

async def _enviar_correo_activacion(email: str, nombre: str, codigo: str):
    html = f"""
    <div style="font-family: Arial, sans-serif; background-color: #FBF9F6; padding: 40px 20px; text-align: center;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 30px; border: 1px solid #E0DBD3;">
            <h2 style="color: #800020; margin-top: 0; font-family: serif; letter-spacing: 1px;">Restaurante Bravo</h2>
            <div style="height: 1px; background-color: #E0DBD3; margin: 20px 0;"></div>
            <p style="color: #2D2D2D; font-size: 16px;">Hola, <strong>{nombre}</strong>.</p>
            <p style="color: #2D2D2D; font-size: 15px; line-height: 1.6;">
                El administrador te ha creado una cuenta en <strong>Restaurante Bravo</strong>.<br>
                Usa el siguiente código en la app para establecer tu contraseña definitiva:
            </p>
            <div style="background-color: #800020; color: #ffffff; padding: 15px 25px; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 25px 0; display: inline-block;">
                {codigo}
            </div>
            <p style="color: #6B6B6B; font-size: 12px; margin-top: 25px; border-top: 1px solid #EEE; padding-top: 15px;">
                En la app ve a <em>Iniciar Sesión → Activar mi cuenta</em> e ingresa tu correo y este código.
            </p>
        </div>
    </div>
    """
    mensaje = MessageSchema(
        subject="Activa tu cuenta - Restaurante Bravo",
        recipients=[email],
        body=html,
        subtype=MessageType.html,
    )
    try:
        await FastMail(conf).send_message(mensaje)
    except Exception:
        pass

# Modelo pequeñito para recibir solo el texto del nuevo rol
class UsuarioActualizarRol(BaseModel):
    rol: str

class CambiarPassword(BaseModel):
    passwordActual: str
    nuevaPassword: str

# NUEVO: Modelo para crear usuarios desde el panel de Admin
class UsuarioCrear(BaseModel):
    nombre: str
    correo: EmailStr
    password: str = ''  # Opcional: si vacío, el backend genera una contraseña aleatoria
    rol: str
    restauranteId: str

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
            "restauranteId": str(res_id) if res_id else None
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
    if not bcrypt.checkpw(datos.passwordActual.encode("utf-8"), hash_almacenado):
        raise HTTPException(status_code=400, detail="La contraseña actual es incorrecta")

    nueva_hash = bcrypt.hashpw(datos.nuevaPassword.encode("utf-8"), bcrypt.gensalt())
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"password_hash": nueva_hash.decode("utf-8")}}
    )
    return {"mensaje": "Contraseña actualizada correctamente"}

# Roles que requieren que el caller tenga permisos elevados
_ROLES_PRIVILEGIADOS = {"super_admin", "superadministrador"}

# Ruta obligatoria para que funcione el botón de Flutter de "Cambiar Rol"
@router.put("/{user_id}/rol")
def actualizar_rol(
    user_id: str,
    datos: UsuarioActualizarRol,
    x_caller_id: Optional[str] = Header(default=None),
):
    rol_limpio = datos.rol.strip().lower()

    roles_permitidos = ["cliente", "cocinero", "camarero", "mesero", "trabajador", "admin", "administrador", "super_admin", "superadministrador"]

    if rol_limpio not in roles_permitidos:
        raise HTTPException(status_code=400, detail=f"Rol '{rol_limpio}' no válido")

    # Si se intenta asignar un rol privilegiado, verificar que el llamante sea super_admin
    if rol_limpio in _ROLES_PRIVILEGIADOS:
        if not x_caller_id:
            raise HTTPException(
                status_code=403,
                detail="Se requiere autenticación para asignar roles privilegiados (cabecera X-Caller-Id)"
            )
        caller = coleccion_usuarios.find_one({"_id": ObjectId(x_caller_id)})
        if not caller or caller.get("rol", "").lower() not in {"super_admin", "superadministrador"}:
            raise HTTPException(
                status_code=403,
                detail="Solo un super_admin puede asignar roles de administrador o super_admin"
            )

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
async def crear_usuario(datos: UsuarioCrear):
    correo_limpio = datos.correo.lower().strip()

    if coleccion_usuarios.find_one({"correo": correo_limpio}):
        raise HTTPException(status_code=400, detail="Este correo ya está registrado")

    # Si no viene contraseña (creación desde panel admin), se genera una aleatoria.
    # El empleado la reemplazará al activar su cuenta con el código de correo.
    password_real = datos.password if datos.password.strip() else ''.join(random.choices(string.ascii_letters + string.digits, k=16))
    hash_password = bcrypt.hashpw(password_real.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    # Código para que el empleado active su cuenta y establezca su contraseña
    reset_code = ''.join(random.choices(string.digits, k=6))

    nuevo_usuario = {
        "nombre": datos.nombre,
        "correo": correo_limpio,
        "password_hash": hash_password,
        "rol": datos.rol.lower().strip(),
        "restaurante_id": datos.restauranteId,
        "is_verified": False,  # Debe activar su cuenta vía email
        "telefono": "",
        "direccion": "",
        "verification_code": None,
        "reset_code": reset_code,
    }

    resultado = coleccion_usuarios.insert_one(nuevo_usuario)

    if resultado.inserted_id:
        await _enviar_correo_activacion(correo_limpio, datos.nombre, reset_code)
        return {
            "mensaje": "Usuario creado exitosamente. Se envió un correo de activación.",
            "id": str(resultado.inserted_id)
        }

    raise HTTPException(status_code=500, detail="No se pudo crear el usuario")