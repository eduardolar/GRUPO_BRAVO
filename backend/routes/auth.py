import random
import string
import bcrypt
from fastapi import APIRouter, HTTPException, status
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from pydantic import BaseModel, EmailStr
from typing import Optional

# Importamos tus dependencias locales
from database import coleccion_usuarios
from models import UsuarioRegistro, UsuarioLogin

router = APIRouter()

# --- 1. CONFIGURACIÓN DE CORREO (SMTP GMAIL) ---
# RECUERDA: La contraseña de 16 letras se genera en: 
# Mi Cuenta Google -> Seguridad -> Contraseñas de Aplicación
conf = ConnectionConfig(
    MAIL_USERNAME = "tu_correo@gmail.com",
    MAIL_PASSWORD = "xxxx xxxx xxxx xxxx",  # <--- COLOCA AQUÍ TUS 16 LETRAS
    MAIL_FROM = "tu_correo@gmail.com",
    MAIL_PORT = 587,
    MAIL_SERVER = "smtp.gmail.com",
    MAIL_STARTTLS = True,
    MAIL_SSL_TLS = False,
    USE_CREDENTIALS = True,
    VALIDATE_CERTS = True
)

# Modelo para recibir el código desde Flutter
class VerificacionCodigo(BaseModel):
    correo: EmailStr
    codigo: str

# --- 2. FUNCIÓN PARA ENVIAR EL EMAIL ---
async def enviar_correo_verificacion(email_destino: str, codigo: str):
    html = f"""
    <div style="font-family: 'Arial', sans-serif; background-color: #FBF9F6; padding: 30px; border: 1px solid #E0DBD3; text-align: center;">
        <h2 style="color: #800020;">Restaurante Bravo</h2>
        <p style="color: #2D2D2D; font-size: 16px;">Gracias por unirte. Tu código de verificación es:</p>
        <div style="background-color: #800020; color: white; padding: 15px; font-size: 28px; font-weight: bold; letter-spacing: 8px; margin: 20px 0; display: inline-block; min-width: 200px;">
            {codigo}
        </div>
        <p style="color: #6B6B6B; font-size: 12px;">Si no has solicitado este registro, ignora este mensaje.</p>
    </div>
    """
    
    mensaje = MessageSchema(
        subject="Verifica tu cuenta - Bravo",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html
    )

    fm = FastMail(conf)
    await fm.send_message(mensaje)

# --- 3. ENDPOINT: REGISTRO ---
@router.post("/registro")
async def registrar_usuario(usuario: UsuarioRegistro):
    try:
        # Validar si el correo ya existe
        if coleccion_usuarios.find_one({"correo": usuario.correo}):
            raise HTTPException(status_code=400, detail="El correo ya está registrado")

        # Regla Senior: Validar restaurante_id para empleados
        if usuario.rol != "cliente" and not usuario.restaurante_id:
            raise HTTPException(
                status_code=400, 
                detail="Los empleados deben estar vinculados a un restaurante_id"
            )

        # Generar OTP de 6 dígitos
        codigo_otp = ''.join(random.choices(string.digits, k=6))

        # Hashear contraseña
        password_bytes = usuario.password_hash.encode('utf-8')
        hashed_password = bcrypt.hashpw(password_bytes, bcrypt.gensalt())

        # Preparar documento para MongoDB
        usuario_dict = usuario.dict()
        usuario_dict["password_hash"] = hashed_password.decode('utf-8')
        usuario_dict["is_verified"] = False
        usuario_dict["verification_code"] = codigo_otp

        # Guardar en base de datos
        coleccion_usuarios.insert_one(usuario_dict)
        
        # Enviar correo real
        await enviar_correo_verificacion(usuario.correo, codigo_otp)

        return {"mensaje": "Registro exitoso. Verifica tu correo.", "correo": usuario.correo}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- 4. ENDPOINT: VERIFICAR CÓDIGO ---
@router.post("/verificar-codigo")
async def verificar_codigo(datos: VerificacionCodigo):
    usuario_db = coleccion_usuarios.find_one({"correo": datos.correo})

    if not usuario_db:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    if usuario_db.get("verification_code") == datos.codigo:
        # Actualizar a verificado y limpiar el código
        coleccion_usuarios.update_one(
            {"correo": datos.correo},
            {"$set": {"is_verified": True, "verification_code": None}}
        )
        return {"mensaje": "Cuenta verificada correctamente"}
    
    raise HTTPException(status_code=400, detail="Código de verificación incorrecto")

# --- 5. ENDPOINT: LOGIN ---
@router.post("/login")
def iniciar_sesion(credenciales: UsuarioLogin):
    usuario_db = coleccion_usuarios.find_one({"correo": credenciales.correo})

    if usuario_db:
        # Bloquear si no está verificado
        if not usuario_db.get("is_verified", False):
            raise HTTPException(
                status_code=403, 
                detail="Cuenta no verificada. Por favor, revisa tu correo."
            )

        password_escrita = credenciales.password_hash.encode('utf-8')
        hash_almacenado = usuario_db["password_hash"].encode('utf-8')

        if bcrypt.checkpw(password_escrita, hash_almacenado):
            return {
                "id": str(usuario_db["_id"]),
                "nombre": usuario_db["nombre"],
                "correo": usuario_db["correo"],
                "telefono": usuario_db.get("telefono", ""),
                "direccion": usuario_db.get("direccion", ""),
                "rol": usuario_db.get("rol", "cliente"),
                "restaurante_id": usuario_db.get("restaurante_id", "")
            }

    raise HTTPException(status_code=401, detail="Credenciales incorrectas")