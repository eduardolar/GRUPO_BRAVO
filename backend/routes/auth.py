import logging
import os
import random
import string
from datetime import datetime, timezone

import bcrypt
import pyotp
from bson import ObjectId
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, EmailStr

import config  # carga .env una sola vez (efecto de import)
from database import coleccion_usuarios
from models import UsuarioLogin, VerificarRecuperacion
from limiter import limiter
from security import crear_token
from exceptions import (
    NotFoundError, ValidacionError,
    AutenticacionError, AutorizacionError,
)
from utils.auth_helpers import (
    conf,
    hash_otp,
    otp_coincide,
    codigo_expirado,
    expiry_iso,
    normalizar_correo,
    generar_codigos_recuperacion,
    buscar_codigo_recuperacion,
    generar_otp,
    enviar_correo_2fa,
)

router = APIRouter()

logger = logging.getLogger("uvicorn")

# ── Aliases internos para compatibilidad con routes/usuarios.py ───────────────
# usuarios.py importa `_hash_otp` directamente desde aquí; mantenemos el alias.
_hash_otp = hash_otp
_otp_coincide = otp_coincide
_codigo_expirado = codigo_expirado
_expiry_iso = expiry_iso


# Modelos Pydantic usados en auth

class Verificar2FA(BaseModel):
    user_id: str
    codigo: str


class Activar2FA(BaseModel):
    codigo: str


class Desactivar2FA(BaseModel):
    codigo: str


class ConfirmarEmail2FA(BaseModel):
    codigo: str


class Reenviar2FA(BaseModel):
    correo: EmailStr


class VerificarLogin2FA(BaseModel):
    correo: EmailStr
    codigo: str


# --- ENDPOINT: LOGIN ---
@router.post("/login")
@limiter.limit("5/minute")
async def iniciar_sesion(request: Request, credenciales: UsuarioLogin):
    correo_normalizado = normalizar_correo(credenciales.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if usuario_db:
        if not usuario_db.get("is_verified", False):
            raise AutorizacionError("Cuenta no verificada. Por favor, revisa tu correo.")

        if usuario_db.get("activo", True) is False:
            raise AutorizacionError(
                "Tu cuenta está suspendida. Contacta con el administrador.",
            )

        password_escrita = credenciales.password.encode("utf-8")
        hash_almacenado = usuario_db["password_hash"].encode("utf-8")

        if bcrypt.checkpw(password_escrita, hash_almacenado):
            rol = usuario_db.get("rol", "cliente")

            # CAMINO A: Cliente — comprueba si tiene email 2FA habilitado
            if rol == "cliente":
                email_2fa_habilitado = usuario_db.get("email_2fa_enabled", False)
                if email_2fa_habilitado:
                    codigo_2fa = generar_otp()
                    coleccion_usuarios.update_one(
                        {"_id": usuario_db["_id"]},
                        {"$set": {
                            "login_code_2fa": hash_otp(codigo_2fa),
                            "login_code_2fa_expiry": expiry_iso(),
                        }},
                    )
                    await enviar_correo_2fa(usuario_db["correo"], codigo_2fa)
                    return {
                        "requires_2fa": True,
                        "correo": usuario_db["correo"],
                        "mensaje": "Se ha enviado un código de seguridad a tu correo.",
                    }
                token = crear_token({
                    "sub": str(usuario_db["_id"]),
                    "correo": correo_normalizado,
                    "rol": rol,
                    "restaurante_id": usuario_db.get("restaurante_id"),
                })
                return {
                    "id": str(usuario_db["_id"]),
                    "nombre": usuario_db["nombre"],
                    "correo": usuario_db["correo"],
                    "rol": rol,
                    "restauranteId": usuario_db.get("restaurante_id", ""),
                    "email_2fa_enabled": False,
                    "access_token": token,
                    "token_type": "bearer",
                    "puntos": usuario_db.get("puntos", 0),
                }

            # CAMINO B: Trabajador, admin, cocinero — sin 2FA
            else:
                token = crear_token({
                    "sub": str(usuario_db["_id"]),
                    "correo": correo_normalizado,
                    "rol": rol,
                    "restaurante_id": usuario_db.get("restaurante_id"),
                })
                return {
                    "id": str(usuario_db["_id"]),
                    "nombre": usuario_db["nombre"],
                    "correo": usuario_db["correo"],
                    "rol": rol,
                    "restauranteId": usuario_db.get("restaurante_id", ""),
                    "access_token": token,
                    "token_type": "bearer",
                }

    raise AutenticacionError("Credenciales incorrectas")


# --- ENDPOINT: VERIFICAR LOGIN 2FA ---
@router.post("/verificar-login-2fa")
@limiter.limit("5/minute")
async def verificar_login_2fa(request: Request, datos: VerificarLogin2FA):
    correo_normalizado = normalizar_correo(datos.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if not usuario_db:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    hash_guardado_2fa = str(usuario_db.get("login_code_2fa") or "").strip()

    if (
        not hash_guardado_2fa
        or not otp_coincide(datos.codigo, hash_guardado_2fa)
        or codigo_expirado(usuario_db.get("login_code_2fa_expiry"))
    ):
        raise HTTPException(status_code=400, detail="Código incorrecto o expirado")

    coleccion_usuarios.update_one(
        {"_id": usuario_db["_id"]},
        {"$unset": {"login_code_2fa": "", "login_code_2fa_expiry": ""}},
    )

    rol = usuario_db.get("rol", "cliente")
    token = crear_token({
        "sub": str(usuario_db["_id"]),
        "correo": datos.correo,
        "rol": rol,
        "restaurante_id": usuario_db.get("restaurante_id"),
    })
    return {
        "id": str(usuario_db["_id"]),
        "nombre": usuario_db["nombre"],
        "correo": usuario_db["correo"],
        "rol": rol,
        "restauranteId": usuario_db.get("restaurante_id", ""),
        "email_2fa_enabled": usuario_db.get("email_2fa_enabled", False),
        "access_token": token,
        "token_type": "bearer",
        "puntos": usuario_db.get("puntos", 0),
    }


# --- ENDPOINT: REENVIAR LOGIN 2FA ---
@router.post("/reenviar-login-2fa")
async def reenviar_login_2fa(datos: Reenviar2FA):
    correo_normalizado = normalizar_correo(datos.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if not usuario_db:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    codigo_2fa = generar_otp()

    coleccion_usuarios.update_one(
        {"_id": usuario_db["_id"]},
        {"$set": {"login_code_2fa": hash_otp(codigo_2fa), "login_code_2fa_expiry": expiry_iso()}},
    )

    await enviar_correo_2fa(usuario_db["correo"], codigo_2fa)
    return {"mensaje": "Nuevo código de seguridad enviado"}


# ── TOTP 2FA — usados por TODOS los roles (cliente, admin, camarero, etc.) ────
# Quedan en auth.py porque no son exclusivos del rol cliente.

@router.post("/usuarios/{user_id}/2fa/setup")
def setup_2fa(user_id: str):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    secret = pyotp.random_base32()
    correo = usuario_db["correo"]
    uri = pyotp.totp.TOTP(secret).provisioning_uri(
        name=correo,
        issuer_name="Restaurante Bravo",
    )

    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"totp_secret_temp": secret}},
    )

    return {"secret": secret, "otpauth_uri": uri}


@router.post("/usuarios/{user_id}/2fa/activar")
def activar_2fa(user_id: str, datos: Activar2FA):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    secret_temp = usuario_db.get("totp_secret_temp")
    if not secret_temp:
        raise ValidacionError("Primero inicia el proceso de configuración 2FA")

    totp = pyotp.TOTP(secret_temp)
    if not totp.verify(datos.codigo.strip(), valid_window=1):
        raise AutenticacionError("Código incorrecto")

    codigos, hashes = generar_codigos_recuperacion()
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {
            "$set": {"totp_secret": secret_temp, "totp_enabled": True, "recovery_codes": hashes},
            "$unset": {"totp_secret_temp": ""},
        },
    )

    return {
        "mensaje": "Autenticación de dos factores activada correctamente",
        "codigosRecuperacion": codigos,
    }


@router.post("/usuarios/{user_id}/2fa/desactivar")
def desactivar_2fa(user_id: str, datos: Desactivar2FA):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    if not usuario_db.get("totp_enabled"):
        raise ValidacionError("El 2FA no está activado")

    secret = usuario_db.get("totp_secret")
    if not secret:
        raise NotFoundError("Configuración 2FA no encontrada")

    totp = pyotp.TOTP(secret)
    if not totp.verify(datos.codigo.strip(), valid_window=1):
        raise AutenticacionError("Código incorrecto")

    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"totp_enabled": False}, "$unset": {"totp_secret": ""}},
    )

    return {"mensaje": "Autenticación de dos factores desactivada"}


@router.post("/verificar-2fa")
@limiter.limit("5/minute")
def verificar_2fa(request: Request, datos: Verificar2FA):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(datos.user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    secret = usuario_db.get("totp_secret")
    if not secret:
        raise ValidacionError("2FA no configurado")

    totp = pyotp.TOTP(secret)
    if not totp.verify(datos.codigo.strip(), valid_window=1):
        raise AutenticacionError("Código incorrecto. Verifica tu Google Authenticator")

    rol = usuario_db.get("rol", "cliente")
    token = crear_token({
        "sub": str(usuario_db["_id"]),
        "correo": usuario_db["correo"],
        "rol": rol,
        "restaurante_id": usuario_db.get("restaurante_id"),
    })
    return {
        "id": str(usuario_db["_id"]),
        "nombre": usuario_db["nombre"],
        "correo": usuario_db["correo"],
        "rol": rol,
        "restauranteId": usuario_db.get("restaurante_id", ""),
        "totp_enabled": True,
        "access_token": token,
        "token_type": "bearer",
        "puntos": usuario_db.get("puntos", 0),
    }


@router.post("/verificar-2fa-recovery")
@limiter.limit("5/minute")
def verificar_2fa_recovery(request: Request, datos: VerificarRecuperacion):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(datos.user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    hashes = usuario_db.get("recovery_codes") or []
    if not hashes:
        raise ValidacionError("No hay códigos de recuperación configurados")

    hash_usado = buscar_codigo_recuperacion(datos.codigo, hashes)
    if not hash_usado:
        raise AutenticacionError("Código de recuperación inválido")

    coleccion_usuarios.update_one(
        {"_id": ObjectId(datos.user_id)},
        {"$pull": {"recovery_codes": hash_usado}},
    )

    codigos_restantes = len(hashes) - 1
    rol = usuario_db.get("rol", "cliente")
    token = crear_token({
        "sub": str(usuario_db["_id"]),
        "correo": usuario_db["correo"],
        "rol": rol,
        "restaurante_id": usuario_db.get("restaurante_id"),
    })
    return {
        "id": str(usuario_db["_id"]),
        "nombre": usuario_db["nombre"],
        "correo": usuario_db["correo"],
        "rol": rol,
        "restauranteId": usuario_db.get("restaurante_id", ""),
        "totp_enabled": True,
        "codigosRestantes": codigos_restantes,
        "access_token": token,
        "token_type": "bearer",
        "puntos": usuario_db.get("puntos", 0),
    }


@router.post("/usuarios/{user_id}/2fa/regenerar-codigos")
@limiter.limit("3/minute")
def regenerar_codigos_recuperacion(request: Request, user_id: str, datos: Activar2FA):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")
    if not usuario_db.get("totp_enabled"):
        raise ValidacionError("El 2FA no está activado")

    secret = usuario_db.get("totp_secret")
    if not secret:
        raise NotFoundError("Configuración 2FA no encontrada")

    totp = pyotp.TOTP(secret)
    if not totp.verify(datos.codigo.strip(), valid_window=1):
        raise AutenticacionError("Código TOTP incorrecto")

    codigos, hashes = generar_codigos_recuperacion()
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"recovery_codes": hashes}},
    )
    return {"codigosRecuperacion": codigos}


# ── Email 2FA (opción en perfil) — disponible para todos los roles ─────────────

@router.post("/usuarios/{user_id}/2fa-email/solicitar")
@limiter.limit("3/minute")
async def solicitar_codigo_email_2fa(request: Request, user_id: str):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    codigo = generar_otp()
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"email_2fa_code_temp": hash_otp(codigo)}},
    )
    await enviar_correo_2fa(usuario_db["correo"], codigo)
    return {"mensaje": "Código enviado a tu correo"}


@router.post("/usuarios/{user_id}/2fa-email/activar")
@limiter.limit("5/minute")
def activar_email_2fa(request: Request, user_id: str, datos: ConfirmarEmail2FA):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    hash_temp = str(usuario_db.get("email_2fa_code_temp") or "").strip()
    if not hash_temp or not otp_coincide(datos.codigo, hash_temp):
        raise AutenticacionError("Código incorrecto o expirado")

    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"email_2fa_enabled": True}, "$unset": {"email_2fa_code_temp": ""}},
    )
    return {"mensaje": "Verificación por correo activada correctamente"}


@router.post("/usuarios/{user_id}/2fa-email/desactivar")
@limiter.limit("5/minute")
def desactivar_email_2fa(request: Request, user_id: str, datos: ConfirmarEmail2FA):
    try:
        usuario_db = coleccion_usuarios.find_one({"_id": ObjectId(user_id)})
    except Exception:
        raise ValidacionError("ID de usuario inválido")
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    hash_temp = str(usuario_db.get("email_2fa_code_temp") or "").strip()
    if not hash_temp or not otp_coincide(datos.codigo, hash_temp):
        raise AutenticacionError("Código incorrecto o expirado")

    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"email_2fa_enabled": False}, "$unset": {"email_2fa_code_temp": ""}},
    )
    return {"mensaje": "Verificación por correo desactivada"}
