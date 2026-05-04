import random
import string
import bcrypt
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from typing import Optional
from database import coleccion_usuarios, coleccion_auditoria
from exceptions import NotFoundError, ConflictError, ValidacionError, AutenticacionError
from bson import ObjectId
from database import coleccion_usuarios
import audit_general as ag
from models import UsuarioActualizar
from security import require_role, normalizar_rol, ROLES_CANONICOS
from pydantic import BaseModel, EmailStr
from fastapi_mail import FastMail, MessageSchema, MessageType

# Importar la configuración de correo desde auth
from routes.auth import conf

def _actor_de(request: Request) -> Optional[str]:
    """Lee el correo del usuario que ejecuta la acción desde la cabecera
    `X-Actor`. Es trivialmente falsificable (no hay auth real); cuando el
    proyecto migre a JWT, sustituir por la extracción del token."""
    valor = request.headers.get("X-Actor")
    return valor.strip() if valor and valor.strip() else None


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
    password_actual: str
    nueva_password: str

# NUEVO: Agregamos latitud y longitud
class UsuarioActualizar(BaseModel):
    nombre: str | None = None
    correo: str | None = None
    telefono: str | None = ""
    direccion: str | None = ""
    latitud: float | None = None
    longitud: float | None = None
    activo: bool | None = None    

# Modelo para crear usuarios desde el panel de Admin
class UsuarioCrear(BaseModel):
    nombre: str
    correo: EmailStr
    password: str = ''  # Opcional: si vacío, el backend genera una contraseña aleatoria
    rol: str
    restaurante_id: str

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/")
def listar_usuarios(
    rol: str | None = None,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
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
            # AGREGADO:
            "latitud": u.get("latitud"),
            "longitud": u.get("longitud"),
            "rol": u.get("rol", "cliente"),
            # Lo convertimos a str() por si en Mongo es un ObjectId
            "restaurante_id": str(res_id) if res_id else None,
            "activo": u.get("activo", True),
            "totp_enabled": u.get("totp_enabled", False),
            "email_2fa_enabled": u.get("email_2fa_enabled", False),
        })
    return resultado

# IMPORTANTE: las rutas con path literal (/auditoria) deben declararse ANTES
# que las rutas con parámetro (/{user_id}). FastAPI evalúa en orden y si la
# paramétrica va primero capturaría "auditoria" como user_id e intentaría
# convertirlo a ObjectId.
@router.get("/auditoria")
def obtener_auditoria_usuarios(
    accion: Optional[str] = Query(None),
    limite: int = Query(100, ge=1, le=500),
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    filtro = {}
    if accion:
        filtro["accion"] = accion
    eventos = list(
        coleccion_auditoria.find(filtro, {"_id": 0})
        .sort("fecha", -1)
        .limit(limite)
    )
    return eventos


@router.get("/{user_id}")
def ver_perfil(user_id: str):
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")
    return {
        "id": str(usuario["_id"]),
        "nombre": usuario.get("nombre", ""),
        "correo": usuario.get("correo", ""),
        "telefono": usuario.get("telefono", ""),
        "direccion": usuario.get("direccion", ""),
        "latitud": usuario.get("latitud"),
        "longitud": usuario.get("longitud"),
        "rol": usuario.get("rol", "cliente"),
    }
@router.put("/{user_id}")
def actualizar_perfil(user_id: str, datos: UsuarioActualizar, request: Request):
    # 1. Convertimos el modelo Pydantic a un diccionario de Python
    datos_dict = datos.dict()

    # Creamos un nuevo diccionario solo con los campos
    # que NO son None. Así no intentamos sobrescribir nombre/correo con nulos.
    actualizacion = {k: v for k, v in datos_dict.items() if v is not None}

    # Si por algún motivo el diccionario queda vacío, avisamos
    if not actualizacion:
        raise ValidacionError("No se enviaron datos válidos para actualizar")

    # 3. Ejecutamos la actualización en MongoDB usando solo los campos filtrados
    resultado = coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": actualizacion}
    )

    if resultado.matched_count == 0:
        raise NotFoundError("Usuario no encontrado")

    campos = ", ".join(actualizacion.keys())
    ag.registrar(ag.USUARIO_EDITADO,
        actor=_actor_de(request),
        objetivo=user_id,
        detalle=f"Campos: {campos}")
    return {"mensaje": "Perfil actualizado correctamente"}

@router.put("/{user_id}/cambiar-password")
def cambiar_password(user_id: str, datos: CambiarPassword):
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")

    hash_almacenado = usuario.get("password_hash", "").encode("utf-8")
    if not bcrypt.checkpw(datos.password_actual.encode("utf-8"), hash_almacenado):
        raise AutenticacionError("La contraseña actual es incorrecta")

    nueva_hash = bcrypt.hashpw(datos.nueva_password.encode("utf-8"), bcrypt.gensalt())
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"password_hash": nueva_hash.decode("utf-8")}}
    )
    return {"mensaje": "Contraseña actualizada correctamente"}

# Ruta obligatoria para que funcione el botón de Flutter de "Cambiar Rol"
@router.put("/{user_id}/rol")
def actualizar_rol(
    user_id: str,
    datos: UsuarioActualizarRol,
    request: Request,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    # Normaliza alias (mesero→camarero, administrador→admin, etc.) al rol canónico
    rol_limpio = normalizar_rol(datos.rol)

    if rol_limpio not in ROLES_CANONICOS:
        raise ValidacionError(f"Rol '{rol_limpio}' no válido")

    resultado = coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"rol": rol_limpio}}
    )

    if resultado.matched_count == 0:
        raise NotFoundError("Usuario no encontrado")
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    ag.registrar(ag.ROL_CAMBIADO,
        actor=_actor_de(request),
        objetivo=usuario.get("correo", user_id) if usuario else user_id,
        detalle=f"Nuevo rol: {rol_limpio}")
    return {"mensaje": f"Rol actualizado exitosamente a {rol_limpio}"}

# Ruta para eliminar un usuario, es buena tenerla para administración futura.
@router.delete("/{user_id}")
def eliminar_usuario(
    user_id: str,
    request: Request,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    resultado = coleccion_usuarios.delete_one({"_id": ObjectId(user_id)})
    if resultado.deleted_count == 0:
        raise NotFoundError("Usuario no encontrado")
    if usuario:
        ag.registrar(ag.USUARIO_ELIMINADO,
            actor=_actor_de(request),
            objetivo=usuario.get("correo", user_id),
            detalle=f"Rol: {usuario.get('rol', '?')}")
    return {"mensaje": "Usuario eliminado"}

# --- NUEVA RUTA PARA QUE EL ADMIN CREE USUARIOS ---
@router.post("/")
async def crear_usuario(
    datos: UsuarioCrear,
    request: Request,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    correo_limpio = datos.correo.lower().strip()

    if coleccion_usuarios.find_one({"correo": correo_limpio}):
        raise ConflictError("Este correo ya está registrado")

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
        "restaurante_id": datos.restaurante_id,
        "is_verified": False,  # Debe activar su cuenta vía email
        "telefono": "",
        "direccion": "",
        # AGREGADO: Inicializamos coordenadas en None
        "latitud": None,
        "longitud": None,
        "verification_code": None,
        "reset_code": reset_code,
    }

    resultado = coleccion_usuarios.insert_one(nuevo_usuario)

    if resultado.inserted_id:
        await _enviar_correo_activacion(correo_limpio, datos.nombre, reset_code)
        ag.registrar(ag.USUARIO_CREADO,
            actor=_actor_de(request),
            objetivo=correo_limpio,
            detalle=f"Rol: {datos.rol} | Sucursal: {datos.restaurante_id}")
        return {
            "mensaje": "Usuario creado exitosamente. Se envió un correo de activación.",
            "id": str(resultado.inserted_id)
        }

    raise RuntimeError("No se pudo crear el usuario")


