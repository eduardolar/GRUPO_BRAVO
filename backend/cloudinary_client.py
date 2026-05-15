# ============================================================================
# backend/cloudinary_client.py
# ----------------------------------------------------------------------------
# Cliente Cloudinary para subida de imágenes (productos, logos de sucursal).
#
# Cloudinary es un servicio externo (cloudinary.com) que almacena y sirve
# imágenes con CDN, redimensionado on-the-fly y transformaciones. Lo usamos
# para no servir imágenes desde nuestra propia API (más lento y consume
# ancho de banda del servidor).
#
# Diseño "fail soft": si la librería NO está instalada o las credenciales
# NO están configuradas, el módulo marca `_DISPONIBLE = False`. Los routers
# que dependen de esto (uploads.py) deben comprobar ese flag y devolver
# 503 Service Unavailable en lugar de crashearse. Así el resto de la app
# sigue funcionando aunque no haya configuración de Cloudinary (útil en
# entornos de desarrollo donde no necesitas subir imágenes).
# ============================================================================
"""Cliente Cloudinary para subida de imágenes de productos.

Variables de entorno requeridas (añadir al .env del backend):
    CLOUDINARY_CLOUD_NAME=tu_cloud_name
    CLOUDINARY_API_KEY=tu_api_key
    CLOUDINARY_API_SECRET=tu_api_secret

Ejemplo de sección en backend/.env:
    CLOUDINARY_CLOUD_NAME=grupobravo
    CLOUDINARY_API_KEY=123456789012345
    CLOUDINARY_API_SECRET=AbCdEfGhIjKlMnOpQrStUvWxYz0

Importación segura: si la librería no está instalada (ej. CI sin `pip install`),
el módulo degrada a `_DISPONIBLE = False` y los endpoints devuelven 503.
"""
import logging
import os

_log = logging.getLogger("uvicorn")

# Importación condicional: no queremos que la ausencia del paquete
# rompa toda la aplicación cuando no se necesita la funcionalidad.
# Esto permite arrancar la API en una máquina sin la lib instalada y
# que solo fallen los endpoints de subida.
try:
    import cloudinary
    import cloudinary.uploader
    _LIB_DISPONIBLE = True
except ImportError:
    _LIB_DISPONIBLE = False
    _log.warning(
        "Librería 'cloudinary' no instalada. "
        "La subida de imágenes no estará disponible. "
        "Instala con: pip install 'cloudinary>=1.41,<2.0'"
    )

# Lee las tres credenciales necesarias. Si alguna falta → no se configura.
_CLOUD_NAME = os.getenv("CLOUDINARY_CLOUD_NAME", "")
_API_KEY = os.getenv("CLOUDINARY_API_KEY", "")
_API_SECRET = os.getenv("CLOUDINARY_API_SECRET", "")

# _DISPONIBLE controla si los endpoints pueden operar.
# Es True solo si la lib está instalada Y las tres vars están presentes.
# Los routers deben importar ESTE flag y comprobar antes de llamar.
_DISPONIBLE: bool = False

if _LIB_DISPONIBLE:
    if _CLOUD_NAME and _API_KEY and _API_SECRET:
        # Configuración global del SDK. Todas las llamadas posteriores
        # a cloudinary.uploader.* usarán estas credenciales.
        cloudinary.config(
            cloud_name=_CLOUD_NAME,
            api_key=_API_KEY,
            api_secret=_API_SECRET,
            secure=True,   # fuerza URLs https en las respuestas (no http)
        )
        _DISPONIBLE = True
        _log.info("Cloudinary configurado correctamente (cloud: %s)", _CLOUD_NAME)
    else:
        # La lib está pero faltan creds → degradación elegante.
        _log.warning(
            "Cloudinary no configurado: faltan variables de entorno. "
            "Necesarias: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET."
        )
