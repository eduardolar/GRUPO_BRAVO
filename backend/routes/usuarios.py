import random
import string
from datetime import datetime, timezone
import bcrypt
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from typing import Optional
from database import coleccion_usuarios, coleccion_auditoria, coleccion_restaurantes
from exceptions import NotFoundError, ConflictError, ValidacionError, AutenticacionError, AutorizacionError
from bson import ObjectId
import audit_general as ag
from security import require_role, normalizar_rol, ROLES_CANONICOS
from limiter import limiter

from pydantic import BaseModel, EmailStr
from fastapi_mail import FastMail, MessageSchema, MessageType

# Importar helpers compartidos
from utils.auth_helpers import (
    conf,
    FOOTER_RGPD as _FOOTER_RGPD,
    hash_otp as _hash_otp_util,
    expiry_iso as _expiry_iso_util,
)

def _actor_de(request: Request) -> Optional[str]:
    """Devuelve el correo del usuario que ejecuta la acción, exclusivamente
    desde el JWT firmado (`Authorization: Bearer …`). Fuente de verdad
    inmutable por el cliente."""
    auth = request.headers.get("Authorization") or ""
    if auth.lower().startswith("bearer "):
        token = auth[7:].strip()
        try:
            from jose import JWTError, jwt
            from security import ALGORITHM, SECRET_KEY
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            correo = payload.get("correo")
            if isinstance(correo, str) and correo.strip():
                return correo.strip()
        except (JWTError, Exception):
            pass

    return None


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
            {_FOOTER_RGPD}
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

# Modelo que admin/super_admin usa para editar empleados.
# Incluye correo, activo y rol porque son exclusivos de admins
# (los clientes usan PUT /clientes/me que tiene su propio modelo restringido).
class UsuarioActualizar(BaseModel):
    nombre: str | None = None
    correo: str | None = None
    telefono: str | None = ""
    direccion: str | None = ""
    latitud: float | None = None
    longitud: float | None = None
    activo: bool | None = None
    rol: str | None = None

# Modelo para crear usuarios desde el panel de Admin
class UsuarioCrear(BaseModel):
    nombre: str
    correo: EmailStr
    password: str = ''  # Opcional: si vacío, el backend genera una contraseña aleatoria
    rol: str
    restaurante_id: str

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

@router.get("/", summary="Listar usuarios (admin) — paginado")
def listar_usuarios(
    response: Response,
    rol: str | None = None,
    limite: int = Query(200, ge=1, le=500, description="Máx. usuarios por página"),
    offset: int = Query(0, ge=0, description="Desplazamiento para paginar"),
    incluir_suspendidos: bool = Query(True, description="Incluir usuarios con activo=false"),
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Devuelve una lista de usuarios. La cabecera `X-Total-Count` indica el
    total de documentos que cumplen el filtro (útil para construir paginadores
    en el frontend sin romper la forma actual del JSON).

    Un admin solo ve usuarios de su propia sucursal. super_admin ve todos.
    El campo `activo` y `suspendido_at` se incluyen en la respuesta.
    """
    from security import normalizar_rol
    rol_actor = normalizar_rol(actor.get("rol", ""))

    filtro: dict = {}
    if rol:
        filtro["rol"] = rol

    # Aislamiento por sucursal: admin solo ve su restaurante
    if rol_actor != "super_admin":
        rid = actor.get("restaurante_id")
        if rid:
            filtro["restaurante_id"] = rid

    # Filtrar suspendidos si se solicita
    if not incluir_suspendidos:
        filtro["activo"] = {"$ne": False}

    response.headers["X-Total-Count"] = str(coleccion_usuarios.count_documents(filtro))
    usuarios = list(
        coleccion_usuarios.find(filtro)
        .sort("_id", -1)
        .skip(offset)
        .limit(limite)
    )
    resultado = []
    for u in usuarios:
        res_id = u.get("restaurante_id")
        resultado.append({
            "id": str(u["_id"]),
            "nombre": u.get("nombre", "Sin nombre"),
            "correo": u.get("correo", ""),
            "telefono": u.get("telefono", ""),
            "direccion": u.get("direccion", ""),
            "latitud": u.get("latitud"),
            "longitud": u.get("longitud"),
            "rol": u.get("rol", "cliente"),
            "restaurante_id": str(res_id) if res_id else None,
            "activo": u.get("activo", True),
            "suspendido_at": u.get("suspendido_at"),
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
def ver_perfil(user_id: str, _actor: dict = Depends(require_role(["admin", "super_admin"]))):
    """Obtiene el perfil de un usuario. Solo accesible por admin/super_admin.
    Los clientes usan GET /clientes/me para su propio perfil."""
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
def actualizar_perfil(user_id: str, datos: UsuarioActualizar, request: Request,
                      actor: dict = Depends(require_role(["admin", "super_admin"]))):
    """Edita los datos de un empleado. Solo accesible por admin/super_admin.
    Los clientes usan PUT /clientes/me para su propio perfil."""
    # Convertimos el modelo Pydantic a un diccionario de Python sin valores None.
    datos_dict = datos.dict()
    actualizacion = {k: v for k, v in datos_dict.items() if v is not None}

    # Si por algún motivo el diccionario queda vacío, avisamos
    if not actualizacion:
        raise ValidacionError("No se enviaron datos válidos para actualizar")

    # Normalizar rol si se envía
    if "rol" in actualizacion:
        rol_limpio = normalizar_rol(actualizacion["rol"])
        if rol_limpio not in ROLES_CANONICOS:
            raise ValidacionError(f"Rol '{rol_limpio}' no válido")
        actualizacion["rol"] = rol_limpio

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
def cambiar_password(user_id: str, datos: CambiarPassword,
                     _actor: dict = Depends(require_role(["admin", "super_admin"]))):
    """Cambia la contraseña de un empleado. Solo accesible por admin/super_admin.
    Los clientes usan PUT /clientes/me/password para su propia contraseña."""
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

# Ruta para eliminar (super_admin) o suspender (admin) un usuario.
@router.delete("/{user_id}")
def eliminar_usuario(
    user_id: str,
    request: Request,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    from security import normalizar_rol
    rol_actor = normalizar_rol(actor.get("rol", ""))

    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido")

    usuario = coleccion_usuarios.find_one({"_id": oid})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")

    if rol_actor != "super_admin":
        # Admin no puede tocarse a sí mismo
        if actor.get("sub") == user_id or actor.get("correo") == usuario.get("correo"):
            raise ValidacionError("No puedes suspender tu propia cuenta")

        # Aislamiento: admin solo puede tocar usuarios de su sucursal
        rid_actor = actor.get("restaurante_id")
        if not rid_actor:
            raise HTTPException(status_code=403, detail="Falta restaurante asignado en tu sesión")
        if usuario.get("restaurante_id") != rid_actor:
            raise HTTPException(status_code=403, detail="No puedes gestionar usuarios de otra sucursal")

        # Si el usuario YA está suspendido, el admin puede borrarlo
        # definitivamente (segundo DELETE = hard-delete). Esto permite hacer
        # limpieza de cuentas dadas de baja sin necesidad del super_admin.
        if usuario.get("activo", True) is False:
            coleccion_usuarios.delete_one({"_id": oid})
            ag.registrar(
                ag.USUARIO_ELIMINADO,
                actor=_actor_de(request),
                objetivo=usuario.get("correo", user_id),
                detalle=f"Rol: {usuario.get('rol', '?')} | Hard-delete por admin de sucursal {rid_actor} (ya estaba suspendido)",
            )
            return {"mensaje": "Usuario eliminado", "activo": False}

        # Soft-delete: marcar como suspendido (primer DELETE)
        ahora = datetime.now(timezone.utc).isoformat()
        coleccion_usuarios.update_one(
            {"_id": oid},
            {"$set": {"activo": False, "suspendido_at": ahora}},
        )
        ag.registrar(
            ag.USUARIO_SUSPENDIDO,
            actor=_actor_de(request),
            objetivo=usuario.get("correo", user_id),
            detalle=f"Rol: {usuario.get('rol', '?')} | Sucursal: {rid_actor}",
        )
        return {"mensaje": "Usuario suspendido", "activo": False}
    else:
        # super_admin: borrado físico siempre
        coleccion_usuarios.delete_one({"_id": oid})
        ag.registrar(
            ag.USUARIO_ELIMINADO,
            actor=_actor_de(request),
            objetivo=usuario.get("correo", user_id),
            detalle=f"Rol: {usuario.get('rol', '?')}",
        )
        return {"mensaje": "Usuario eliminado"}

# Roles que un admin puede asignar al crear empleados
_ROLES_ADMIN_PUEDE_CREAR = {"camarero", "cocinero"}
# Roles que super_admin puede crear (excluye super_admin; nadie lo crea desde la app)
_ROLES_SUPER_PUEDE_CREAR = {"camarero", "cocinero", "admin"}

# --- NUEVA RUTA PARA QUE EL ADMIN CREE USUARIOS ---
@router.post("/")
@limiter.limit("20/minute")
async def crear_usuario(
    request: Request,
    datos: UsuarioCrear,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    from security import normalizar_rol
    rol_actor = normalizar_rol(actor.get("rol", ""))
    rol_nuevo = normalizar_rol(datos.rol)

    # Whitelist de roles según quién crea
    if rol_actor == "super_admin":
        if rol_nuevo not in _ROLES_SUPER_PUEDE_CREAR:
            raise AutorizacionError(
                f"No puedes crear usuarios con rol '{rol_nuevo}'. "
                "Los super_admin solo pueden crear: camarero, cocinero, admin."
            )
        # super_admin debe indicar siempre la sucursal destino
        restaurante_id_final = datos.restaurante_id
        if not restaurante_id_final or not str(restaurante_id_final).strip():
            raise ValidacionError("Falta restaurante_id. El super_admin debe indicar la sucursal destino.")
        # Verificar que la sucursal existe en la BD
        if not coleccion_restaurantes.find_one({"_id": ObjectId(restaurante_id_final)}):
            raise NotFoundError("Sucursal no encontrada")
    else:
        # admin: solo puede crear camarero/cocinero
        if rol_nuevo not in _ROLES_ADMIN_PUEDE_CREAR:
            raise AutorizacionError(
                f"No puedes crear usuarios con rol '{rol_nuevo}'. "
                "Los admin solo pueden crear: camarero, cocinero."
            )
        # Forzar restaurante_id del JWT, ignorar el del body
        rid_jwt = actor.get("restaurante_id")
        if not rid_jwt:
            raise AutorizacionError("Falta restaurante asignado en tu sesión")
        restaurante_id_final = rid_jwt

    correo_limpio = datos.correo.lower().strip()

    if coleccion_usuarios.find_one({"correo": correo_limpio}):
        raise ConflictError("Este correo ya está registrado")

    # Si no viene contraseña (creación desde panel admin), se genera una aleatoria.
    # El empleado la reemplazará al activar su cuenta con el código de correo.
    password_real = datos.password if datos.password.strip() else ''.join(random.choices(string.ascii_letters + string.digits, k=16))
    hash_password = bcrypt.hashpw(password_real.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    # Código para que el empleado active su cuenta y establezca su contraseña
    reset_code = ''.join(random.choices(string.digits, k=6))
    reset_code_hash = _hash_otp_util(reset_code)

    nuevo_usuario = {
        "nombre": datos.nombre,
        "correo": correo_limpio,
        "password_hash": hash_password,
        "rol": rol_nuevo,
        "restaurante_id": restaurante_id_final,
        "is_verified": False,  # Debe activar su cuenta vía email
        "activo": True,
        "telefono": "",
        "direccion": "",
        "latitud": None,
        "longitud": None,
        "verification_code": None,
        "reset_code": reset_code_hash,
    }

    resultado = coleccion_usuarios.insert_one(nuevo_usuario)

    if resultado.inserted_id:
        await _enviar_correo_activacion(correo_limpio, datos.nombre, reset_code)
        ag.registrar(ag.USUARIO_CREADO,
            actor=_actor_de(request),
            objetivo=correo_limpio,
            detalle=f"Rol: {rol_nuevo} | Sucursal: {restaurante_id_final}")
        return {
            "mensaje": "Usuario creado exitosamente. Se envió un correo de activación.",
            "id": str(resultado.inserted_id)
        }

    raise RuntimeError("No se pudo crear el usuario")


@router.post("/{user_id}/reactivar", summary="Reactivar un usuario suspendido (admin/super_admin)")
def reactivar_usuario(
    user_id: str,
    request: Request,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Revierte una suspensión: pone activo=true y elimina suspendido_at.
    El admin solo puede reactivar usuarios de su misma sucursal."""
    from security import normalizar_rol
    rol_actor = normalizar_rol(actor.get("rol", ""))

    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido")

    usuario = coleccion_usuarios.find_one({"_id": oid})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")

    if rol_actor != "super_admin":
        rid_actor = actor.get("restaurante_id")
        if not rid_actor:
            raise HTTPException(status_code=403, detail="Falta restaurante asignado en tu sesión")
        if usuario.get("restaurante_id") != rid_actor:
            raise HTTPException(status_code=403, detail="No puedes gestionar usuarios de otra sucursal")

    coleccion_usuarios.update_one(
        {"_id": oid},
        {"$set": {"activo": True}, "$unset": {"suspendido_at": ""}},
    )
    ag.registrar(
        ag.USUARIO_REACTIVADO,
        actor=_actor_de(request),
        objetivo=usuario.get("correo", user_id),
        detalle=f"Rol: {usuario.get('rol', '?')}",
    )
    return {"mensaje": "Usuario reactivado", "activo": True}


# NOTE: GET /{user_id}/mis-datos y DELETE /{user_id}/mi-cuenta han sido
# eliminados. Los clientes usan GET /clientes/me/datos y DELETE /clientes/me.

