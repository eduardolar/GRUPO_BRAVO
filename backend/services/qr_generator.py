# ============================================================================
# backend/services/qr_generator.py
# ----------------------------------------------------------------------------
# Variante alternativa del generador de QR (legado).
#
# Diferencias con `backend/qr_generator.py`:
#   - Acepta un `table_id` numérico (int) en lugar de un string.
#   - El QR apunta a un endpoint del backend (`/mesas/validar-qr?mesa=...`)
#     en lugar de a una URL del frontend. Pensado para cuando el QR lo
#     valida el camarero desde la propia API.
#   - Lee la URL base de `API_BASE_URL` con load_dotenv().
#
# Si en el futuro unificamos los dos generadores, este se puede eliminar.
# Mantenemos ambos por compatibilidad con código que ya los importa.
# ============================================================================
import os
import qrcode
from io import BytesIO
from dotenv import load_dotenv

# Carga local de .env (este módulo se importó cuando aún no existía
# `config.py`). Ya cubierto por config; mantenerlo aquí no estorba.
load_dotenv()

def generate_table_qr(table_id: int) -> bytes:
    """Genera un PNG con el QR de validación para una mesa.

    Devuelve los bytes (no escribe a disco) para enviarlos directamente
    como respuesta HTTP.
    """
    # Default a localhost para que funcione en desarrollo sin configurar nada.
    # En producción se DEBE definir API_BASE_URL con el dominio público.
    base_url = os.getenv("API_BASE_URL", "http://127.0.0.1:8000")
    url = f"{base_url}/mesas/validar-qr?mesa={table_id}"

    # qrcode.make() crea el QR con parámetros por defecto (suficientes
    # para URLs cortas como ésta).
    qr = qrcode.make(url)
    buffer = BytesIO()
    qr.save(buffer, format="PNG")
    buffer.seek(0)  # rebobinar el buffer antes de leer

    return buffer.getvalue()
