# ============================================================================
# backend/utils/auth_helpers.py
# ----------------------------------------------------------------------------
# Helpers compartidos entre los endpoints de autenticación: utilidades para
# generar/validar OTPs, normalizar correos, enviar plantillas HTML por
# correo electrónico (verificación, 2FA, recuperación de contraseña) y
# configurar la conexión SMTP.
#
# Diseño:
#   - SHA-256 + comparación en tiempo constante (hmac.compare_digest) para
#     los OTPs almacenados, en lugar de guardar el código en claro.
#   - TTL configurable por código (15 min por defecto) → reduce ventana de
#     ataque por fuerza bruta.
#   - El pie RGPD se incluye en todos los correos automáticos por
#     obligación legal de transparencia.
#   - Funciones de envío son fail-soft: si el SMTP falla, logueamos y
#     devolvemos False / pasamos en lugar de propagar la excepción
#     (excepción: enviar_correo_recuperacion sí re-lanza porque ahí el
#     usuario NO puede continuar sin haber recibido el código).
# ============================================================================
"""Helpers compartidos de autenticación y correo.

Usados por routes/auth.py, routes/clientes.py y routes/usuarios.py.
No importar nunca valores secretos de .env aquí; se leen mediante os.getenv
en tiempo de ejecución para no exponer credenciales en logs.
"""
import hashlib
import hmac
import logging
import os
import random
import secrets
import string
from datetime import datetime, timedelta, timezone

from fastapi_mail import ConnectionConfig, FastMail, MessageSchema, MessageType
from pydantic import EmailStr

logger = logging.getLogger("uvicorn")

# ── TTL por defecto para códigos OTP ─────────────────────────────────────────
_CODE_TTL_MINUTES = 15

# ── Pie RGPD común para todos los correos ────────────────────────────────────
FOOTER_RGPD = """
<div style="color:#9B9B9B;font-size:11px;margin-top:20px;padding-top:12px;
            border-top:1px solid #E0DBD3;text-align:center;line-height:1.6;">
  <strong>Restaurante Bravo</strong> — Responsable del tratamiento.<br>
  Tus datos son tratados conforme al RGPD (UE) 2016/679 y la LOPDGDD 3/2018.<br>
  <a href="https://grupobravo.com/privacidad" style="color:#800020;">
    Política de Privacidad</a> &nbsp;·&nbsp;
  <a href="mailto:privacidad@grupobravo.com" style="color:#800020;">
    Ejercer derechos ARSULIPO</a>
</div>
"""

# ── Configuración SMTP (leída en tiempo de import) ────────────────────────────
conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME", "no-reply@bravo.com"),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD", "password-falsa"),
    MAIL_FROM=os.getenv("MAIL_FROM", "no-reply@bravo.com"),
    MAIL_PORT=int(os.getenv("MAIL_PORT", 587)),
    MAIL_SERVER=os.getenv("MAIL_SERVER", "smtp.gmail.com"),
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True,
)


# ── Utilidades de tiempo y normalización ─────────────────────────────────────

def expiry_iso(minutes: int = _CODE_TTL_MINUTES) -> str:
    """Devuelve la fecha de expiración en ISO 8601 UTC."""
    return (datetime.now(timezone.utc) + timedelta(minutes=minutes)).isoformat()


def codigo_expirado(expiry_str: str | None) -> bool:
    """True si el código ha expirado. Códigos sin TTL (legacy) se consideran válidos."""
    if not expiry_str:
        return False
    try:
        expiry = datetime.fromisoformat(expiry_str)
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        return datetime.now(timezone.utc) > expiry
    except ValueError:
        return True


def normalizar_correo(correo: str) -> str:
    return correo.strip().lower()


# ── Hash y comparación de OTPs ────────────────────────────────────────────────

def hash_otp(codigo: str) -> str:
    """SHA-256 del código OTP normalizado (strip + lower).

    Por qué hashear OTPs si solo viven 15 minutos:
        - Si alguien lee la BD (backup robado, leak), no puede usar OTPs
          activos directamente.
        - SHA-256 sin sal basta porque el espacio es pequeño (6 dígitos)
          y la ventana corta: bcrypt sería overkill.
    """
    return hashlib.sha256(codigo.strip().lower().encode()).hexdigest()


def otp_coincide(recibido: str, hash_almacenado: str) -> bool:
    """Comparación en tiempo constante del hash del OTP recibido con el almacenado.

    `hmac.compare_digest` impide timing attacks: tarda lo mismo aunque la
    cadena difiera en el primer carácter o en el último. Importante en
    web: un atacante puede medir tiempos de respuesta para deducir el
    código si usáramos `==` simple.
    """
    if not recibido or not hash_almacenado:
        return False
    return hmac.compare_digest(hash_otp(recibido), hash_almacenado)


# ── Códigos de recuperación 2FA ───────────────────────────────────────────────

def generar_codigos_recuperacion(n: int = 8) -> tuple[list[str], list[str]]:
    """Devuelve (codigos_en_claro, hashes_sha256).

    Códigos de recuperación: el usuario los apunta en papel cuando activa
    2FA TOTP. Si pierde el móvil con la app autenticadora, puede usar
    uno de estos para volver a entrar.

    En BD guardamos SOLO los hashes (igual que con contraseñas). Los
    códigos en claro se devuelven UNA vez (al activar) y nunca más.
    Formato `XXXXXXXX-XXXXXXXX` para que sea fácil de transcribir.
    """
    codigos, hashes = [], []
    for _ in range(n):
        raw = secrets.token_hex(8)  # 16 hex chars → 64 bits de entropía
        codigos.append(f"{raw[:8].upper()}-{raw[8:].upper()}")
        hashes.append(hashlib.sha256(raw.encode()).hexdigest())
    return codigos, hashes


def buscar_codigo_recuperacion(codigo: str, hashes: list[str]) -> str | None:
    """Devuelve el hash coincidente o None. Acepta código con o sin guión."""
    normalizado = codigo.lower().replace("-", "").strip()
    h = hashlib.sha256(normalizado.encode()).hexdigest()
    return h if h in hashes else None


def generar_otp(n: int = 6) -> str:
    """Genera un código OTP numérico de n dígitos."""
    return "".join(random.choices(string.digits, k=n))


# ── Funciones de envío de correo ──────────────────────────────────────────────

async def enviar_correo_verificacion(email_destino: str, codigo: str) -> bool:
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
            {FOOTER_RGPD}
        </div>
    </div>
    """
    mensaje = MessageSchema(
        subject="Código de Verificación - Restaurante Bravo",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html,
    )
    try:
        await FastMail(conf).send_message(mensaje)
        return True
    except Exception as e:
        logger.error("Error enviando correo de verificación a %s: %s", email_destino, e)
        return False


async def enviar_correo_2fa(email_destino: str, codigo: str) -> None:
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
            {FOOTER_RGPD}
        </div>
    </div>
    """
    mensaje = MessageSchema(
        subject="Código de Acceso - Restaurante Bravo",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html,
    )
    try:
        await FastMail(conf).send_message(mensaje)
    except Exception as e:
        logger.error("Error enviando 2FA a %s: %s", email_destino, e)


async def enviar_correo_recuperacion(correo: str, codigo: str) -> None:
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
                {codigo}
            </div>
            <p style="color: #6B6B6B; font-size: 12px; margin-top: 25px; border-top: 1px solid #EEE; padding-top: 15px;">
                Si tú no solicitaste este cambio, puedes ignorar este correo de forma segura. Tu contraseña actual no se verá afectada.
            </p>
            {FOOTER_RGPD}
        </div>
    </div>
    """
    mensaje = MessageSchema(
        subject="Restablecer Contraseña - Restaurante Bravo",
        recipients=[correo],
        body=html,
        subtype=MessageType.html,
    )
    try:
        await FastMail(conf).send_message(mensaje)
    except Exception as e:
        logger.error("Error enviando correo de recuperación a %s: %s", correo, e)
        raise
