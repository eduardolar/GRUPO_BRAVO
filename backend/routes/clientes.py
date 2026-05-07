"""Router de clientes — endpoints del rol "cliente" final que pide comida.

Prefijo: /api/v1/clientes

Endpoints públicos (sin auth):
  POST /clientes/registro              — auto-registro (rol forzado a "cliente")
  POST /clientes/verificar-email       — confirma código tras registro
  POST /clientes/reenviar-codigo       — reenvía código de verificación
  POST /clientes/recuperar-password    — envío de código de recuperación
  POST /clientes/restablecer-password  — confirma código y resetea contraseña

Endpoints autenticados (JWT con rol "cliente"):
  GET    /clientes/me                  — perfil propio
  PUT    /clientes/me                  — editar perfil propio (subset seguro)
  PUT    /clientes/me/password         — cambiar contraseña propia
  GET    /clientes/me/datos            — exportar RGPD (incluye pedidos)
  DELETE /clientes/me                  — baja RGPD (anonimización)

NOTA: Los endpoints de 2FA TOTP (setup, activar, desactivar, recuperación) se
mantienen en auth.py bajo /api/v1/usuarios/{user_id}/2fa/... porque los usan
TODOS los roles, no solo clientes.
"""
import logging
from datetime import datetime, timezone

import bcrypt
from bson import ObjectId
from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, EmailStr

import config  # carga .env una sola vez
from database import coleccion_usuarios, coleccion_pedidos
from exceptions import (
    AppError, NotFoundError, ConflictError, ValidacionError,
    AutenticacionError, AutorizacionError,
)
from limiter import limiter
from models import UsuarioRegistro
from security import crear_token, get_current_user, normalizar_rol
from utils.auth_helpers import (
    hash_otp,
    otp_coincide,
    codigo_expirado,
    expiry_iso,
    normalizar_correo,
    generar_otp,
    enviar_correo_verificacion,
    enviar_correo_recuperacion,
)

router = APIRouter(prefix="/clientes", tags=["Clientes"])

logger = logging.getLogger("uvicorn")

# Subset de campos que un cliente puede editar sobre su propio perfil.
# correo y activo quedan excluidos explícitamente.
_CAMPOS_EDITABLES = {"nombre", "telefono", "direccion", "latitud", "longitud"}


# ── Modelos Pydantic ──────────────────────────────────────────────────────────

class VerificacionCodigo(BaseModel):
    correo: EmailStr
    codigo: str


class RecuperarPassword(BaseModel):
    correo: EmailStr


class RestablecerPassword(BaseModel):
    correo: EmailStr
    codigo: str
    nueva_password: str


class PerfilClienteActualizar(BaseModel):
    nombre: str | None = None
    telefono: str | None = None
    direccion: str | None = None
    latitud: float | None = None
    longitud: float | None = None


class CambiarPassword(BaseModel):
    password_actual: str
    nueva_password: str


# ── Dependency: exige token con rol "cliente" ─────────────────────────────────

def _require_cliente(current_user: dict = Depends(get_current_user)) -> dict:
    rol = normalizar_rol(current_user.get("rol", ""))
    if rol != "cliente":
        raise AutorizacionError("Este endpoint es exclusivo para clientes")
    return current_user


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINTS PÚBLICOS
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/registro", summary="Auto-registro de cliente")
@limiter.limit("3/minute")
async def registro_cliente(request: Request, usuario: UsuarioRegistro):
    """Registro público. El rol se fuerza siempre a 'cliente' sin importar
    lo que envíe el body."""
    try:
        correo_normalizado = normalizar_correo(usuario.correo)

        if not usuario.consentimiento_rgpd:
            raise ValidacionError("Debes aceptar la Política de Privacidad para registrarte")

        if coleccion_usuarios.find_one({"correo": correo_normalizado}):
            raise ConflictError("El correo ya está registrado")

        codigo_otp = generar_otp()
        codigo_otp_hash = hash_otp(codigo_otp)

        password_bytes = usuario.password.encode("utf-8")
        hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt())

        ip_cliente = (
            request.headers.get("x-forwarded-for", "").split(",")[0].strip()
            or (request.client.host if request.client else "desconocida")
        )

        usuario_dict = {
            "nombre": usuario.nombre,
            "correo": correo_normalizado,
            "telefono": usuario.telefono,
            "direccion": usuario.direccion,
            "rol": "cliente",  # forzado
            "restaurante_id": usuario.restauranteId,
            "password_hash": hashed_password.decode("utf-8"),
            "is_verified": False,
            "verification_code": codigo_otp_hash,
            "verification_code_expiry": expiry_iso(),
            "consentimiento_rgpd": True,
            "consentimiento_fecha": datetime.now(timezone.utc).isoformat(),
            "consentimiento_ip": ip_cliente,
            "consentimiento_version": "1.0",
        }

        coleccion_usuarios.insert_one(usuario_dict)
        await enviar_correo_verificacion(usuario.correo, codigo_otp)

        return {
            "mensaje": "Registro exitoso. Revisa tu bandeja de entrada.",
            "correo": usuario.correo,
        }

    except AppError:
        raise
    except Exception:
        logger.error("Error inesperado en POST /clientes/registro", exc_info=True)
        raise


@router.post("/verificar-email", summary="Verificar código de activación de cuenta")
@limiter.limit("10/minute")
async def verificar_email(request: Request, datos: VerificacionCodigo):
    correo_normalizado = normalizar_correo(datos.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    codigo_recibido = str(datos.codigo).strip()

    hash_verificacion = str(usuario_db.get("verification_code") or "").strip()
    hash_reset = str(usuario_db.get("reset_code") or "").strip()

    coincide_verificacion = (
        hash_verificacion != ""
        and otp_coincide(codigo_recibido, hash_verificacion)
        and not codigo_expirado(usuario_db.get("verification_code_expiry"))
    )
    coincide_reset = (
        hash_reset != ""
        and otp_coincide(codigo_recibido, hash_reset)
        and not codigo_expirado(usuario_db.get("reset_code_expiry"))
    )

    if not coincide_verificacion and not coincide_reset:
        raise AutenticacionError("Código incorrecto o expirado")

    campos: dict = {"is_verified": True}
    if coincide_verificacion:
        campos["verification_code"] = None
    if coincide_reset:
        campos["reset_code"] = None

    resultado = coleccion_usuarios.update_one(
        {"correo": correo_normalizado},
        {"$set": campos},
    )

    if resultado.modified_count > 0:
        return {"mensaje": "¡Cuenta verificada con éxito! Ya puedes hacer login."}
    return {"mensaje": "La cuenta ya estaba verificada."}


@router.post("/reenviar-codigo", summary="Reenviar código de verificación de cuenta")
@limiter.limit("3/minute")
async def reenviar_codigo(request: Request, datos: dict):
    correo = datos.get("correo")
    if not correo:
        raise ValidacionError("Falta el campo 'correo'")
    correo_normalizado = normalizar_correo(correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    if usuario_db.get("is_verified", False):
        raise ConflictError("La cuenta ya está verificada")

    codigo_otp = generar_otp()
    codigo_otp_hash = hash_otp(codigo_otp)

    coleccion_usuarios.update_one(
        {"correo": correo_normalizado},
        {"$set": {"verification_code": codigo_otp_hash, "verification_code_expiry": expiry_iso()}},
    )

    await enviar_correo_verificacion(correo_normalizado, codigo_otp)
    return {"mensaje": "Código reenviado correctamente"}


@router.post("/recuperar-password", summary="Solicitar código de recuperación de contraseña")
@limiter.limit("3/minute")
async def recuperar_password(request: Request, datos: RecuperarPassword):
    correo_normalizado = normalizar_correo(datos.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if not usuario_db:
        raise NotFoundError("No existe un usuario con ese correo")

    codigo = generar_otp()
    coleccion_usuarios.update_one(
        {"correo": correo_normalizado},
        {"$set": {"reset_code": hash_otp(codigo), "reset_code_expiry": expiry_iso()}},
    )

    await enviar_correo_recuperacion(correo_normalizado, codigo)
    return {"mensaje": "Código de recuperación enviado"}


@router.post("/restablecer-password", summary="Confirmar código y cambiar contraseña")
@limiter.limit("10/minute")
async def restablecer_password(request: Request, datos: RestablecerPassword):
    correo_normalizado = normalizar_correo(datos.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    hash_guardado = str(usuario_db.get("reset_code") or "").strip()
    if (
        not hash_guardado
        or not otp_coincide(datos.codigo, hash_guardado)
        or codigo_expirado(usuario_db.get("reset_code_expiry"))
    ):
        raise AutenticacionError("Código inválido o expirado")

    hashed_password = bcrypt.hashpw(datos.nueva_password.encode("utf-8"), bcrypt.gensalt())

    coleccion_usuarios.update_one(
        {"correo": correo_normalizado},
        {"$set": {
            "password_hash": hashed_password.decode("utf-8"),
            "reset_code": None,
            "is_verified": True,
        }},
    )

    return {"mensaje": "Contraseña actualizada correctamente"}


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINTS AUTENTICADOS — solo rol "cliente"
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/me", summary="Perfil propio del cliente")
def ver_perfil_propio(current_user: dict = Depends(_require_cliente)):
    user_id = current_user.get("sub")
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido en token")

    usuario = coleccion_usuarios.find_one({"_id": oid})
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
        "totp_enabled": usuario.get("totp_enabled", False),
        "email_2fa_enabled": usuario.get("email_2fa_enabled", False),
    }


@router.put("/me", summary="Editar perfil propio del cliente (subset seguro)")
def actualizar_perfil_propio(
    datos: PerfilClienteActualizar,
    current_user: dict = Depends(_require_cliente),
):
    user_id = current_user.get("sub")
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido en token")

    actualizacion = {
        k: v
        for k, v in datos.model_dump().items()
        if v is not None and k in _CAMPOS_EDITABLES
    }

    if not actualizacion:
        raise ValidacionError("No se enviaron datos válidos para actualizar")

    resultado = coleccion_usuarios.update_one(
        {"_id": oid},
        {"$set": actualizacion},
    )

    if resultado.matched_count == 0:
        raise NotFoundError("Usuario no encontrado")

    return {"mensaje": "Perfil actualizado correctamente"}


@router.put("/me/password", summary="Cambiar contraseña propia del cliente")
def cambiar_password_propio(
    datos: CambiarPassword,
    current_user: dict = Depends(_require_cliente),
):
    user_id = current_user.get("sub")
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido en token")

    usuario = coleccion_usuarios.find_one({"_id": oid})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")

    hash_almacenado = usuario.get("password_hash", "").encode("utf-8")
    if not bcrypt.checkpw(datos.password_actual.encode("utf-8"), hash_almacenado):
        raise AutenticacionError("La contraseña actual es incorrecta")

    nueva_hash = bcrypt.hashpw(datos.nueva_password.encode("utf-8"), bcrypt.gensalt())
    coleccion_usuarios.update_one(
        {"_id": oid},
        {"$set": {"password_hash": nueva_hash.decode("utf-8")}},
    )

    return {"mensaje": "Contraseña actualizada correctamente"}


@router.get("/me/datos", summary="Exportar datos RGPD del cliente (art. 15/20)")
def exportar_datos_propios(current_user: dict = Depends(_require_cliente)):
    """RGPD art. 15/20 — Derecho de acceso y portabilidad.
    Devuelve los datos personales del cliente en JSON descargable,
    incluyendo su historial de pedidos ordenado del más reciente al más antiguo."""
    user_id = current_user.get("sub")
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido en token")

    usuario = coleccion_usuarios.find_one({"_id": oid})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")

    pedidos_cursor = coleccion_pedidos.find(
        {"usuario_id": user_id},
        {
            "_id": 1,
            "fecha": 1,
            "total": 1,
            "items": 1,
            "estado": 1,
            "tipo_entrega": 1,
            "metodo_pago": 1,
            "direccion_entrega": 1,
            "numero_mesa": 1,
            "notas": 1,
        },
    ).sort("fecha", -1)

    pedidos_export = []
    for p in pedidos_cursor:
        entry: dict = {
            "id": str(p["_id"]),
            "fecha": p.get("fecha", ""),
            "total": p.get("total", 0),
            "estado": p.get("estado", ""),
            "tipo_entrega": p.get("tipo_entrega", ""),
            "metodo_pago": p.get("metodo_pago", ""),
            "notas": p.get("notas", ""),
        }
        if p.get("direccion_entrega"):
            entry["direccion_entrega"] = p["direccion_entrega"]
        if p.get("numero_mesa") is not None:
            entry["numero_mesa"] = p["numero_mesa"]
        items_raw = p.get("items", [])
        entry["productos"] = [
            {
                "nombre": it.get("nombre") or it.get("producto_nombre") or "",
                "cantidad": it.get("cantidad", 0),
                "precio_unitario": it.get("precio", 0),
            }
            for it in items_raw
            if isinstance(it, dict)
        ]
        pedidos_export.append(entry)

    return {
        "id": str(usuario["_id"]),
        "nombre": usuario.get("nombre", ""),
        "correo": usuario.get("correo", ""),
        "telefono": usuario.get("telefono", ""),
        "direccion": usuario.get("direccion", ""),
        "rol": usuario.get("rol", ""),
        "is_verified": usuario.get("is_verified", False),
        "consentimiento_rgpd": usuario.get("consentimiento_rgpd", False),
        "consentimiento_fecha": usuario.get("consentimiento_fecha"),
        "fecha_registro": str(oid.generation_time.isoformat()),
        "totp_enabled": usuario.get("totp_enabled", False),
        "email_2fa_enabled": usuario.get("email_2fa_enabled", False),
        "pedidos": pedidos_export,
    }


@router.delete("/me", summary="Baja RGPD — anonimización del cliente (art. 17)")
def solicitar_baja_propia(current_user: dict = Depends(_require_cliente)):
    """RGPD art. 17 — Derecho de supresión. Anonimiza los datos personales del
    cliente conservando el documento para integridad contable de pedidos."""
    user_id = current_user.get("sub")
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise ValidacionError("ID de usuario inválido en token")

    usuario = coleccion_usuarios.find_one({"_id": oid})
    if not usuario:
        raise NotFoundError("Usuario no encontrado")

    correo_anonimo = f"baja_{user_id}@bravo.eliminado"

    coleccion_usuarios.update_one(
        {"_id": oid},
        {"$set": {
            "nombre": "Usuario eliminado",
            "correo": correo_anonimo,
            "telefono": "",
            "direccion": "",
            "latitud": None,
            "longitud": None,
            "password_hash": "",
            "is_verified": False,
            "activo": False,
            "rgpd_baja": True,
            "rgpd_baja_fecha": datetime.now(timezone.utc).isoformat(),
            "totp_enabled": False,
            "totp_secret": None,
            "email_2fa_enabled": False,
            "verification_code": None,
            "reset_code": None,
            "login_code_2fa": None,
            "recovery_codes": [],
        }},
    )

    return {
        "mensaje": "Cuenta eliminada. Tus datos personales han sido anonimizados conforme al RGPD."
    }
