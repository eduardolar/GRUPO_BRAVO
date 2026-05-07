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

# Lee las tres credenciales necesarias
_CLOUD_NAME = os.getenv("CLOUDINARY_CLOUD_NAME", "")
_API_KEY = os.getenv("CLOUDINARY_API_KEY", "")
_API_SECRET = os.getenv("CLOUDINARY_API_SECRET", "")

# _DISPONIBLE controla si los endpoints pueden operar.
# Es True solo si la lib está instalada Y las tres vars están presentes.
_DISPONIBLE: bool = False

if _LIB_DISPONIBLE:
    if _CLOUD_NAME and _API_KEY and _API_SECRET:
        cloudinary.config(
            cloud_name=_CLOUD_NAME,
            api_key=_API_KEY,
            api_secret=_API_SECRET,
            secure=True,
        )
        _DISPONIBLE = True
        _log.info("Cloudinary configurado correctamente (cloud: %s)", _CLOUD_NAME)
    else:
        _log.warning(
            "Cloudinary no configurado: faltan variables de entorno. "
            "Necesarias: CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET."
        )
