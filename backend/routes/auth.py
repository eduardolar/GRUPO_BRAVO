import hashlib
import os
import random
import secrets
import string
import bcrypt
import pyotp
from bson import ObjectId
from pathlib import Path
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, Request
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from pydantic import BaseModel, EmailStr

from database import coleccion_usuarios
from models import UsuarioRegistro, UsuarioLogin, VerificarRecuperacion
from limiter import limiter
from exceptions import (
    AppError, NotFoundError, ConflictError, ValidacionError,
    AutenticacionError, AutorizacionError,
)

# Cargar el archivo de entorno local llamado 'env'
dotenv_path = Path(__file__).resolve().parents[1] / "env"
load_dotenv(dotenv_path=dotenv_path, override=True)

router = APIRouter()


# ── Códigos de recuperación 2FA ───────────────────────────────────────────────

def _generar_codigos_recuperacion(n: int = 8) -> tuple[list[str], list[str]]:
    """Devuelve (codigos_en_claro, hashes_sha256)."""
    codigos, hashes = [], []
    for _ in range(n):
        raw = secrets.token_hex(8)  # 16 hex chars → 64 bits de entropía
        codigos.append(f"{raw[:8].upper()}-{raw[8:].upper()}")
        hashes.append(hashlib.sha256(raw.encode()).hexdigest())
    return codigos, hashes


def _buscar_codigo_recuperacion(codigo: str, hashes: list[str]) -> str | None:
    """Devuelve el hash coincidente o None. Acepta código con o sin guión."""
    normalizado = codigo.lower().replace("-", "").strip()
    h = hashlib.sha256(normalizado.encode()).hexdigest()
    return h if h in hashes else None

def normalizar_correo(correo: str) -> str:
    return correo.strip().lower()

conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME", "no-reply@bravo.com"), # Valor por defecto
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD", "password-falsa"),
    MAIL_FROM=os.getenv("MAIL_FROM", "no-reply@bravo.com"),
    MAIL_PORT=int(os.getenv("MAIL_PORT", 587)),
    MAIL_SERVER=os.getenv("MAIL_SERVER", "smtp.gmail.com"),
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True,
)

# Modelo para recibir el código desde Flutter
class VerificacionCodigo(BaseModel):
    correo: EmailStr
    codigo: str

class ResetPassword(BaseModel):
    correo: EmailStr
    codigo: str
    nueva_password: str

class Verificar2FA(BaseModel):
    user_id: str
    codigo: str

class Activar2FA(BaseModel):
    codigo: str

class Desactivar2FA(BaseModel):
    codigo: str

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
@router.post("/registro")
@limiter.limit("3/minute")
async def registrar_usuario(request: Request, usuario: UsuarioRegistro):
    try:
        correo_normalizado = normalizar_correo(usuario.correo)

        # Validar si el correo ya existe
        if coleccion_usuarios.find_one({"correo": correo_normalizado}):
            raise ConflictError("El correo ya está registrado")

        # Regla Senior: Validar restaurante_id para empleados
        if usuario.rol != "cliente" and not usuario.restauranteId:
            raise ValidacionError("Los empleados deben estar vinculados a un restauranteId")

        # Generar OTP de 6 dígitos
        codigo_otp = ''.join(random.choices(string.digits, k=6))

        # Hashear contraseña
        password_bytes = usuario.password.encode('utf-8')
        hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt())

        # Preparar documento para MongoDB (DB usa snake_case internamente)
        usuario_dict = {
            "nombre": usuario.nombre,
            "correo": correo_normalizado,
            "telefono": usuario.telefono,
            "direccion": usuario.direccion,
            "rol": usuario.rol,
            "restaurante_id": usuario.restauranteId,
            "password_hash": hashed_password.decode('utf-8'),
            "is_verified": False,
            "verification_code": codigo_otp,
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

    coincide_verificacion = codigo_recibido == codigo_verificacion and codigo_verificacion != ""
    coincide_reset = codigo_recibido == codigo_reset and codigo_reset != ""

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
# --- 5. ENDPOINT: LOGIN ---
@router.post("/login")
@limiter.limit("5/minute")
def iniciar_sesion(request: Request, credenciales: UsuarioLogin):
    correo_normalizado = normalizar_correo(credenciales.correo)
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if usuario_db:
        # Bloquear si no está verificado
        if not usuario_db.get("is_verified", False):
            raise AutorizacionError("Cuenta no verificada. Por favor, revisa tu correo.")

        password_escrita = credenciales.password.encode('utf-8')
        hash_almacenado = usuario_db["password_hash"].encode('utf-8')

        if bcrypt.checkpw(password_escrita, hash_almacenado):
            if usuario_db.get("totp_enabled"):
                return {
                    "requires_2fa": True,
                    "user_id": str(usuario_db["_id"]),
                }
            return {
                "id": str(usuario_db["_id"]),
                "nombre": usuario_db["nombre"],
                "correo": usuario_db["correo"],
                "rol": usuario_db.get("rol", "cliente"),
                "restauranteId": usuario_db.get("restaurante_id", ""),
                "totp_enabled": usuario_db.get("totp_enabled", False),
            }
   
    raise AutenticacionError("Credenciales incorrectas")

# ---6. ENDPOINT: SOLICITAR RECUPERACIÓN ---
@router.post("/recuperar-password")
@limiter.limit("3/minute")
async def recuperar_password(request: Request, datos: dict):
    correo = datos.get("correo")
    correo_normalizado = normalizar_correo(correo) if correo else None
    usuario_db = coleccion_usuarios.find_one({"correo": correo_normalizado})

    if not usuario_db:
        # Nota: En apps de alta seguridad se devuelve 200 aunque no exista, 
        # pero si prefieres el 404 para desarrollo, está perfecto.
        raise NotFoundError("No existe un usuario con ese correo")

    codigo_recuperacion = ''.join(random.choices(string.digits, k=6))

    coleccion_usuarios.update_one(
        {"correo": correo_normalizado},
        {"$set": {"reset_code": codigo_recuperacion}}
    )

    # Diseño unificado con el correo de bienvenida
    html = f"""
    <div style="font-family: Arial, sans-serif; background-color: #FBF9F6; padding: 40px 20px; text-align: center;">
        <div style="max-width: 500px; margin: 0 auto; background-color: #ffffff; padding: 30px; border: 1px solid #E0DBD3; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.05);">
            <h2 style="color: #800020; margin-top: 0;">Restaurante Bravo</h2>
            <div style="height: 1px; background-color: #E0DBD3; margin: 20px 0;"></div>
            
            <h3 style="color: #2D2D2D; font-size: 18px;">Restablecer Contraseña</h3>
            <p style="color: #2D2D2D; font-size: 15px; line-height: 1.5;">
                Recibimos una solicitud para acceder a tu cuenta. Utiliza el siguiente código para completar el proceso de recuperación:
            </p>
            
            <div style="background-color: #800020; color: #ffffff; padding: 15px 25px; font-size: 32px; font-weight: bold; letter-spacing: 8px; margin: 25px 0; display: inline-block; border-radius: 5px;">
                {codigo_recuperacion}
            </div>
            
            <p style="color: #6B6B6B; font-size: 12px; margin-top: 25px; border-top: 1px solid #EEE; padding-top: 15px;">
                Si tú no solicitaste este cambio, puedes ignorar este correo de forma segura. Tu contraseña actual no se verá afectada.
            </p>
        </div>
    </div>
    """
    
    mensaje = MessageSchema(
        subject="Restablecer Contraseña - Restaurante Bravo",
        recipients=[correo],
        body=html,
        subtype=MessageType.html
    )
    
    try:
        fm = FastMail(conf)
        await fm.send_message(mensaje)
    except Exception as e:
        logger.error(f"Error enviando correo de recuperación a {correo}: {e}")
        raise

    return {"mensaje": "Código de recuperación enviado"}

# --- 7. ENDPOINT: REENVIAR CÓDIGO DE VERIFICACIÓN ---
@router.post("/reenviar-codigo")
@limiter.limit("3/minute")
async def reenviar_codigo(request: Request, datos: dict):
    correo = datos.get("correo")
    usuario_db = coleccion_usuarios.find_one({"correo": correo})

    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    if usuario_db.get("is_verified", False):
        raise ConflictError("La cuenta ya está verificada")

    codigo_otp = ''.join(random.choices(string.digits, k=6))

    coleccion_usuarios.update_one(
        {"correo": correo},
        {"$set": {"verification_code": codigo_otp}}
    )

    await enviar_correo_verificacion(correo, codigo_otp)

    return {"mensaje": "Código reenviado correctamente"}

# --- 8. ENDPOINT: RESTABLECER CONTRASEÑA ---
@router.post("/reset-password")
@limiter.limit("10/minute")
async def reset_password(request: Request, datos: ResetPassword):
    usuario_db = coleccion_usuarios.find_one({"correo": datos.correo})

    if not usuario_db:
        raise NotFoundError("Usuario no encontrado")

    codigo_guardado = str(usuario_db.get("reset_code") or "").strip()
    if not codigo_guardado or datos.codigo.strip() != codigo_guardado:
        raise AutenticacionError("Código inválido o expirado")

    password_bytes = datos.nueva_password.encode('utf-8')
    hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt())

    coleccion_usuarios.update_one(
        {"correo": datos.correo},
        {"$set": {
            "password_hash": hashed_password.decode('utf-8'),
            "reset_code": None,
            "is_verified": True,
        }}
    )

    return {"mensaje": "Contraseña actualizada correctamente"}


# --- 9. ENDPOINT: SETUP 2FA ---
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
        issuer_name="Restaurante Bravo"
    )

    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"totp_secret_temp": secret}}
    )

    return {"secret": secret, "otpauth_uri": uri}


# --- 10. ENDPOINT: ACTIVAR 2FA ---
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

    codigos, hashes = _generar_codigos_recuperacion()
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


# --- 11. ENDPOINT: DESACTIVAR 2FA ---
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
        {"$set": {"totp_enabled": False}, "$unset": {"totp_secret": ""}}
    )

    return {"mensaje": "Autenticación de dos factores desactivada"}


# --- 12. ENDPOINT: VERIFICAR CÓDIGO 2FA EN LOGIN ---
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

    return {
        "id": str(usuario_db["_id"]),
        "nombre": usuario_db["nombre"],
        "correo": usuario_db["correo"],
        "rol": usuario_db.get("rol", "cliente"),
        "restauranteId": usuario_db.get("restaurante_id", ""),
        "totp_enabled": True,
    }


# --- 13. ENDPOINT: LOGIN CON CÓDIGO DE RECUPERACIÓN ---
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

    hash_usado = _buscar_codigo_recuperacion(datos.codigo, hashes)
    if not hash_usado:
        raise AutenticacionError("Código de recuperación inválido")

    coleccion_usuarios.update_one(
        {"_id": ObjectId(datos.user_id)},
        {"$pull": {"recovery_codes": hash_usado}},
    )

    codigos_restantes = len(hashes) - 1
    return {
        "id": str(usuario_db["_id"]),
        "nombre": usuario_db["nombre"],
        "correo": usuario_db["correo"],
        "rol": usuario_db.get("rol", "cliente"),
        "restauranteId": usuario_db.get("restaurante_id", ""),
        "totp_enabled": True,
        "codigosRestantes": codigos_restantes,
    }


# --- 14. ENDPOINT: REGENERAR CÓDIGOS DE RECUPERACIÓN ---
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

    codigos, hashes = _generar_codigos_recuperacion()
    coleccion_usuarios.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"recovery_codes": hashes}},
    )
    return {"codigosRecuperacion": codigos}
