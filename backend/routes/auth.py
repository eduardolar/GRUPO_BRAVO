# ============================================================================
# backend/routes/auth.py
# ----------------------------------------------------------------------------
# Endpoints de autenticación y 2FA.
#
# Visión global del flujo:
#
#   1) REGISTRO:
#        POST /registro                → crea usuario inactivo + envía OTP por email
#        POST /verificar-codigo        → marca is_verified=True
#
#   2) LOGIN normal:
#        POST /login                   → valida password
#                                        - Si rol=cliente y email_2fa_enabled=True
#                                          → manda código a email y exige paso 2.
#                                        - Si no → devuelve JWT directamente.
#        POST /verificar-login-2fa     → valida código y devuelve JWT.
#        POST /reenviar-login-2fa      → reenvía código si no llegó.
#
#   3) 2FA con app autenticadora (TOTP, ej. Google Authenticator):
#        POST /usuarios/{id}/2fa/setup       → devuelve secret + URI para escanear
#        POST /usuarios/{id}/2fa/activar     → confirma con primer código
#        POST /usuarios/{id}/2fa/desactivar  → apaga TOTP
#        POST /verificar-2fa                 → segundo factor TOTP en login
#        POST /verificar-2fa-recovery        → segundo factor con código de recuperación
#        POST /usuarios/{id}/2fa/regenerar-codigos
#
#   4) 2FA por email (alternativa más simple para clientes):
#        POST /usuarios/{id}/2fa-email/solicitar
#        POST /usuarios/{id}/2fa-email/activar
#        POST /usuarios/{id}/2fa-email/desactivar
#
# Hashing de contraseñas: bcrypt con salt automático (`bcrypt.gensalt()`).
# Rate limit: `@limiter.limit("N/minute")` en endpoints sensibles para
# frenar fuerza bruta. La IP la determina slowapi (`get_remote_address`).
# ============================================================================
import logging
import os
import random
import string
from datetime import datetime, timezone

import bcrypt
import pyotp
from bson import ObjectId
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

import config  # carga .env una sola vez (efecto de import)
from database import coleccion_usuarios
from models import CorreoStr, UsuarioLogin, UsuarioRegistro, VerificarRecuperacion
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
    correo: CorreoStr


class VerificarLogin2FA(BaseModel):
    correo: CorreoStr
    codigo: str


class VerificacionCodigo(BaseModel):
    correo: CorreoStr
    codigo: str


# --- ENDPOINT: LOGIN ---
# --- 2. FUNCIÓN PARA ENVIAR EL EMAIL ---
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from pydantic import EmailStr
import logging

# Configuración de logging para rastrear errores
logger = logging.getLogger("uvicorn")

async def enviar_correo_verificacion(email_destino: str, codigo: str):
    html = f"""
    <div style="font-family: Arial, sans-serif; background-color: #FBF9F6; padding: 40px 20px; text-align: center;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 30px; border: 1px solid #E0DBD3; border-radius: 10px;">
            <h2 style="color: #800020; margin-top: 0;">Restaurante Bravo</h2>
            <hr style="border: 0; border-top: 1px solid #E0DBD3; margin: 20px 0;">
            <p style="color: #2D2D2D; font-size: 16px; line-height: 1.5;">
                ¡Bienvenido! Para activar tu cuenta y empezar tu experiencia gastronómica, usa el siguiente código de seguridad:
            </p>
            <div style="background-color: #800020; color: #ffffff; padding: 15px 25px; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 25px 0; display: inline-block; border-radius: 5px;">
                {codigo}
            </div>
            <p style="color: #6B6B6B; font-size: 12px; margin-top: 25px; border-top: 1px solid #EEE; padding-top: 15px;">
                Este código es privado. Si no intentaste registrarte en <strong>Bravo</strong>, puedes ignorar este correo con seguridad.
            </p>
            {_FOOTER_RGPD}
        </div>
    </div>
    """

    mensaje = MessageSchema(
        subject="Código de Verificación - Restaurante Bravo",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html
    )

    fm = FastMail(conf) # Asegúrate de que 'conf' esté importado/disponible
    
    try:
        await fm.send_message(mensaje)
    except Exception as e:
        # Esto evita que la API devuelva un error 500 si el correo falla
        logger.error(f"Error enviando correo a {email_destino}: {str(e)}")
        return False
    
    return True

# --- 3. ENDPOINT: REGISTRO ---
# Flujo:
#   1) Validamos consentimiento RGPD + unicidad de correo.
#   2) Si el rol no es cliente, exige restaurante_id (un camarero existe
#      siempre dentro de una sucursal).
#   3) Generamos OTP de 6 dígitos, hasheamos password con bcrypt y guardamos
#      el documento como is_verified=False.
#   4) Enviamos el OTP por correo. El usuario debe llamar /verificar-codigo
#      con ese código para activar su cuenta.
@router.post("/registro")
@limiter.limit("3/minute")
async def registrar_usuario(request: Request, usuario: UsuarioRegistro):
    try:
        correo_normalizado = normalizar_correo(usuario.correo)

        # RGPD: consentimiento explícito obligatorio (no se permite "implícito").
        # Guardamos también fecha + IP + versión de la política como prueba.
        if not usuario.consentimiento_rgpd:
            raise ValidacionError("Debes aceptar la Política de Privacidad para registrarte")

        # Validar si el correo ya existe (correo es la clave única natural).
        if coleccion_usuarios.find_one({"correo": correo_normalizado}):
            raise ConflictError("El correo ya está registrado")

        # Regla de negocio: solo los clientes pueden registrarse "huérfanos".
        # Los empleados deben pertenecer a una sucursal específica para que
        # las consultas multi-tenant funcionen.
        if usuario.rol != "cliente" and not usuario.restauranteId:
            raise ValidacionError("Los empleados deben estar vinculados a un restauranteId")

        # Generar OTP de 6 dígitos. random.choices basta para OTPs de un solo
        # uso con expiración corta; no se necesita secrets aquí (no es clave).
        codigo_otp = ''.join(random.choices(string.digits, k=6))

        # Hashear contraseña con bcrypt. `gensalt()` produce un salt aleatorio
        # único por usuario → dos usuarios con la misma password tienen hashes
        # distintos. Bcrypt internamente codifica el salt dentro del hash.
        password_bytes = usuario.password.encode('utf-8')
        hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt())

        # Extraer IP del cliente para prueba de consentimiento
        ip_cliente = (
            request.headers.get("x-forwarded-for", "").split(",")[0].strip()
            or request.client.host
            if request.client else "desconocida"
        )

        # Preparar documento para MongoDB (DB usa snake_case internamente)
        usuario_dict = {
            "nombre": usuario.nombre,
            "correo": correo_normalizado,
            "telefono": usuario.telefono,
            "direccion": usuario.direccion,
            "rol": usuario.rol,
            "restaurante_id": usuario.restaurante_id,
            "password_hash": hashed_password.decode('utf-8'),
            "activo": True,
            "is_verified": False,
            "verification_code": codigo_otp,
            "verification_code_expiry": _expiry_iso(),
            "consentimiento_rgpd": True,
            "consentimiento_fecha": datetime.now(timezone.utc).isoformat(),
            "consentimiento_ip": ip_cliente,
            "consentimiento_version": "1.0",
        }

        # Guardar en base de datos
        coleccion_usuarios.insert_one(usuario_dict)

        # Enviar correo real a la bandeja del usuario
        await enviar_correo_verificacion(usuario.correo, codigo_otp)

        return {"mensaje": "Registro exitoso. Revisa tu bandeja de entrada.", "correo": usuario.correo}

    except AppError:
        raise
    except Exception:
        logger.error("Error inesperado en /registro", exc_info=True)
        raise

# --- 4. ENDPOINT: VERIFICAR CÓDIGO ---
@router.post("/verificar-codigo")
@limiter.limit("10/minute")
async def verificar_codigo(request: Request, datos: VerificacionCodigo):
    correo_normalizado = normalizar_correo(datos.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})
    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    codigo_recibido = str(datos.codigo).strip()

    # Clientes usan verification_code; empleados creados por admin usan reset_code
    codigo_verificacion = str(usuario_db.get("verification_code") or "").strip()
    codigo_reset = str(usuario_db.get("reset_code") or "").strip()

    coincide_verificacion = (
        codigo_recibido == codigo_verificacion
        and codigo_verificacion != ""
        and not _codigo_expirado(usuario_db.get("verification_code_expiry"))
    )
    coincide_reset = (
        codigo_recibido == codigo_reset
        and codigo_reset != ""
        and not _codigo_expirado(usuario_db.get("reset_code_expiry"))
    )

    if not coincide_verificacion and not coincide_reset:
        raise AutenticacionError("Código incorrecto o expirado")

    campos = {"is_verified": True}
    if coincide_verificacion:
        campos["verification_code"] = None
    if coincide_reset:
        campos["reset_code"] = None

    resultado = coleccion_usuarios.update_one(
        {"correo": correo_normalizado},
        {"$set": campos}
    )

    if resultado.modified_count > 0:
        return {"mensaje": "¡Cuenta verificada con éxito! Ya puedes hacer login."}
    return {"mensaje": "La cuenta ya estaba verificada."}
# --- NUEVA FUNCIÓN PARA EL CORREO 2FA ---
async def enviar_correo_2fa(email_destino: str, codigo: str):
    html = f"""
    <div style="font-family: Arial, sans-serif; background-color: #FBF9F6; padding: 40px 20px; text-align: center;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 30px; border: 1px solid #E0DBD3; border-radius: 10px;">
            <h2 style="color: #800020; margin-top: 0;">Restaurante Bravo - Seguridad</h2>
            <hr style="border: 0; border-top: 1px solid #E0DBD3; margin: 20px 0;">
            <p style="color: #2D2D2D; font-size: 16px; line-height: 1.5;">
                Hemos detectado un intento de inicio de sesión. Usa este código para confirmar que eres tú:
            </p>
            <div style="background-color: #800020; color: #ffffff; padding: 15px 25px; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 25px 0; display: inline-block; border-radius: 5px;">
                {codigo}
            </div>
            <p style="color: #6B6B6B; font-size: 12px; margin-top: 25px; border-top: 1px solid #EEE; padding-top: 15px;">
                Si no estás intentando iniciar sesión, por favor cambia tu contraseña inmediatamente.
            </p>
            {_FOOTER_RGPD}
        </div>
    </div>
    """
    mensaje = MessageSchema(
        subject="Código de Acceso - Restaurante Bravo",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html
    )
    try:
        fm = FastMail(conf)
        await fm.send_message(mensaje)
    except Exception as e:
        logger.error(f"Error enviando 2FA a {email_destino}: {str(e)}")


# --- 5. ENDPOINT: LOGIN (SOLO CLIENTES TIENEN 2FA OPCIONAL) ---
# Flujo:
#   1) Buscamos por correo normalizado.
#   2) Si la cuenta no está verificada o está suspendida → 403.
#   3) bcrypt.checkpw compara la contraseña en tiempo constante (resistente
#      a timing attacks).
#   4) Si rol=cliente y email_2fa_enabled=True → mandamos OTP por email y
#      el cliente DEBE completar /verificar-login-2fa para obtener el JWT.
#   5) En cualquier otro caso devolvemos el JWT directamente.
#
# Rate limit 5/min/IP: balance entre proteger contra fuerza bruta y no
# bloquear usuarios legítimos que se equivocan al teclear.
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
#
# TOTP = Time-based One-Time Password. La app autenticadora (Google
# Authenticator, Authy, 1Password...) genera códigos de 6 dígitos a partir
# de un `secret` compartido y de la hora actual. El backend verifica
# regenerando el código localmente y comparándolo.
#
# Flujo de alta:
#   /setup → genera secret + URI provisional, NO se activa todavía.
#   /activar → el usuario escanea el QR con el TOTP URI, prueba que
#              funciona enviando su primer código, y SOLO entonces se
#              persisten el secret y los códigos de recuperación.

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
