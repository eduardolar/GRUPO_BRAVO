# ============================================================================
# backend/routes/uploads.py
# ----------------------------------------------------------------------------
# Subida y borrado de imágenes (productos y logos de sucursales).
#
# Usamos Cloudinary como almacenamiento externo (más rápido que servir
# bytes desde nuestra API y con CDN automático). Si Cloudinary no está
# configurado, los endpoints devuelven 503 en lugar de crashear (ver
# `cloudinary_client._DISPONIBLE`).
#
# Endpoints registrados bajo el prefijo /api/v1 de main.py:
#     POST   /productos/{producto_id}/imagen     — sube/reemplaza imagen de producto
#     DELETE /productos/{producto_id}/imagen     — borra imagen de producto
#     POST   /restaurantes/{id}/logo             — sube/reemplaza logo de sucursal (super_admin)
#     DELETE /restaurantes/{id}/logo             — borra logo de sucursal (super_admin)
#
# Al subir guardamos en BD dos campos:
#   - imagen_url        → URL pública para servir (CDN)
#   - imagen_public_id  → ID interno en Cloudinary (necesario para borrar)
# ============================================================================
"""Endpoints de subida y borrado de imágenes (productos y logos de restaurantes).

Usa Cloudinary (tier gratuito) como almacenamiento externo.
La disponibilidad depende de que `cloudinary_client._DISPONIBLE` sea True.

Endpoints registrados bajo el prefijo /api/v1 de main.py:
    POST   /productos/{producto_id}/imagen     — sube/reemplaza imagen de producto
    DELETE /productos/{producto_id}/imagen     — borra imagen de producto
    POST   /restaurantes/{id}/logo             — sube/reemplaza logo de sucursal (super_admin)
    DELETE /restaurantes/{id}/logo             — borra logo de sucursal (super_admin)
"""
import logging

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, File, UploadFile
from fastapi.responses import JSONResponse

import cloudinary_client
from database import coleccion_productos, coleccion_restaurantes
from security import require_role, get_current_user, normalizar_rol

_log = logging.getLogger("uvicorn")

# Router sin prefijo: las rutas llevan la ruta completa para poder agrupar
# tanto /productos/... como /restaurantes/... sin duplicar el registro en main.py
router = APIRouter(tags=["Uploads de imagen"])

# Tipos MIME aceptados
_MIME_PERMITIDOS = {"image/jpeg", "image/png", "image/webp"}
# Límite de tamaño: 5 MB
_MAX_BYTES = 5 * 1024 * 1024

# Mensaje estándar cuando Cloudinary no está configurado
_MSG_503 = (
    "Subida de imágenes no disponible. El backend necesita configurar Cloudinary "
    "(CLOUDINARY_CLOUD_NAME/API_KEY/API_SECRET)."
)


def _validar_oid(entity_id: str, entidad: str = "producto") -> ObjectId:
    """Convierte string a ObjectId; 400 si el formato es inválido."""
    try:
        return ObjectId(entity_id)
    except (InvalidId, TypeError):
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=f"ID de {entidad} inválido")


# ═══════════════════════════════════════════════════════════════════════════════
# Endpoints de imagen para PRODUCTOS
# ═══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/productos/{producto_id}/imagen",
    summary="Subir o reemplazar imagen de un producto (admin)",
)
def subir_imagen(
    producto_id: str,
    file: UploadFile = File(...),
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    # 1. Verificar disponibilidad de Cloudinary antes de leer el fichero
    if not cloudinary_client._DISPONIBLE:
        return JSONResponse(status_code=503, content={"detail": _MSG_503})

    # 2. Validar MIME
    if file.content_type not in _MIME_PERMITIDOS:
        return JSONResponse(
            status_code=400,
            content={
                "detail": (
                    f"Tipo de archivo no permitido: '{file.content_type}'. "
                    "Se aceptan: image/jpeg, image/png, image/webp."
                )
            },
        )

    # 3. Leer bytes y validar tamaño
    contenido = file.file.read()
    if len(contenido) > _MAX_BYTES:
        return JSONResponse(
            status_code=413,
            content={"detail": "El archivo supera el límite de 5 MB."},
        )

    # 4. Verificar que el producto existe y pertenece a la sucursal del admin
    oid = _validar_oid(producto_id)
    producto = coleccion_productos.find_one({"_id": oid})
    if not producto:
        return JSONResponse(status_code=404, content={"detail": "Producto no encontrado"})

    rol = usuario.get("rol", "")
    if rol != "super_admin":
        # Admin solo puede operar sobre productos de su restaurante
        restaurante_id_usuario = usuario.get("restaurante_id")
        restaurante_id_producto = producto.get("restaurante_id")
        if restaurante_id_usuario != restaurante_id_producto:
            return JSONResponse(
                status_code=403,
                content={"detail": "No tienes permiso para modificar este producto"},
            )

    # 5. Subir a Cloudinary
    restaurante_id = producto.get("restaurante_id", "sin_sucursal")
    try:
        import cloudinary.uploader
        result = cloudinary.uploader.upload(
            contenido,
            folder=f"grupo_bravo/productos/{restaurante_id}",
            # Usar el producto_id como public_id garantiza overwrite automático
            # si ya existía una imagen con el mismo identificador en esa carpeta.
            public_id=str(producto_id),
            overwrite=True,
            eager=[
                {
                    "width": 1200,
                    "height": 1200,
                    "crop": "limit",
                    "quality": "auto:good",
                    "fetch_format": "auto",
                }
            ],
            resource_type="image",
        )
    except Exception as exc:
        _log.error("Error subiendo imagen a Cloudinary para producto %s: %s", producto_id, exc)
        return JSONResponse(
            status_code=502,
            content={"detail": "Error subiendo a Cloudinary"},
        )

    nueva_url = result["secure_url"]
    nuevo_public_id = result["public_id"]

    # 6. Si el producto tenía un public_id DIFERENTE al nuevo, borrar la imagen vieja.
    # Si es el mismo (overwrite idempotente), Cloudinary ya hizo el reemplazo.
    public_id_anterior = producto.get("imagen_public_id")
    if public_id_anterior and public_id_anterior != nuevo_public_id:
        try:
            import cloudinary.uploader
            cloudinary.uploader.destroy(public_id_anterior)
        except Exception as exc:
            # No es crítico: la imagen nueva ya está. Solo logueamos.
            _log.warning("No se pudo borrar imagen anterior '%s' de Cloudinary: %s", public_id_anterior, exc)

    # 7. Persistir la nueva URL y el public_id en la BD
    coleccion_productos.update_one(
        {"_id": oid},
        {"$set": {"imagen": nueva_url, "imagen_public_id": nuevo_public_id}},
    )

    return {"imagen": nueva_url, "imagen_public_id": nuevo_public_id}


@router.delete(
    "/productos/{producto_id}/imagen",
    summary="Eliminar imagen de un producto (admin)",
)
def borrar_imagen(
    producto_id: str,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    # 1. Verificar disponibilidad de Cloudinary
    if not cloudinary_client._DISPONIBLE:
        return JSONResponse(status_code=503, content={"detail": _MSG_503})

    # 2. Verificar que el producto existe y pertenece a la sucursal del admin
    oid = _validar_oid(producto_id)
    producto = coleccion_productos.find_one({"_id": oid})
    if not producto:
        return JSONResponse(status_code=404, content={"detail": "Producto no encontrado"})

    rol = usuario.get("rol", "")
    if rol != "super_admin":
        restaurante_id_usuario = usuario.get("restaurante_id")
        restaurante_id_producto = producto.get("restaurante_id")
        if restaurante_id_usuario != restaurante_id_producto:
            return JSONResponse(
                status_code=403,
                content={"detail": "No tienes permiso para modificar este producto"},
            )

    # 3. Borrar de Cloudinary si hay public_id registrado
    public_id = producto.get("imagen_public_id")
    if public_id:
        try:
            import cloudinary.uploader
            cloudinary.uploader.destroy(public_id)
        except Exception as exc:
            _log.warning("No se pudo borrar imagen '%s' de Cloudinary: %s", public_id, exc)

    # 4. Limpiar los campos en BD. Usamos $set con string vacío en lugar de
    # $unset porque el schema validator de productos puede exigir que el campo
    # `imagen` exista y sea string (rechaza null o ausencia).
    coleccion_productos.update_one(
        {"_id": oid},
        {"$set": {"imagen": "", "imagen_public_id": ""}},
    )

    return {"mensaje": "Imagen eliminada correctamente"}


# ═══════════════════════════════════════════════════════════════════════════════
# Endpoints de logo para RESTAURANTES (solo super_admin)
# ═══════════════════════════════════════════════════════════════════════════════

@router.post(
    "/restaurantes/{restaurante_id}/logo",
    summary="Subir o reemplazar el logo de una sucursal (super_admin global; admin solo su sucursal)",
)
def subir_logo_restaurante(
    restaurante_id: str,
    file: UploadFile = File(...),
    usuario: dict = Depends(get_current_user),
):
    # 0. Comprobar autorización: super_admin global, admin solo su sucursal
    rol = normalizar_rol(usuario.get("rol", ""))
    if rol == "super_admin":
        pass  # acceso global
    elif rol == "admin":
        if str(usuario.get("restaurante_id", "")) != str(restaurante_id):
            return JSONResponse(
                status_code=403,
                content={"detail": "No tienes permiso para modificar el logo de esta sucursal"},
            )
    else:
        return JSONResponse(
            status_code=403,
            content={"detail": "No tienes permiso para esta acción"},
        )

    # 1. Verificar disponibilidad de Cloudinary
    if not cloudinary_client._DISPONIBLE:
        return JSONResponse(status_code=503, content={"detail": _MSG_503})

    # 2. Validar MIME
    if file.content_type not in _MIME_PERMITIDOS:
        return JSONResponse(
            status_code=400,
            content={
                "detail": (
                    f"Tipo de archivo no permitido: '{file.content_type}'. "
                    "Se aceptan: image/jpeg, image/png, image/webp."
                )
            },
        )

    # 3. Leer bytes y validar tamaño
    contenido = file.file.read()
    if len(contenido) > _MAX_BYTES:
        return JSONResponse(
            status_code=413,
            content={"detail": "El archivo supera el límite de 5 MB."},
        )

    # 4. Verificar que la sucursal existe
    oid = _validar_oid(restaurante_id, "restaurante")
    restaurante = coleccion_restaurantes.find_one({"_id": oid})
    if not restaurante:
        return JSONResponse(status_code=404, content={"detail": "Sucursal no encontrada"})

    # 5. Subir a Cloudinary con transformación cuadrada (logos suelen ser cuadrados)
    try:
        import cloudinary.uploader
        result = cloudinary.uploader.upload(
            contenido,
            folder=f"grupo_bravo/restaurantes/{restaurante_id}",
            public_id=str(restaurante_id),
            overwrite=True,
            eager=[
                {
                    "width": 800,
                    "height": 800,
                    "crop": "limit",
                    "quality": "auto:good",
                    "fetch_format": "auto",
                }
            ],
            resource_type="image",
        )
    except Exception as exc:
        _log.error("Error subiendo logo a Cloudinary para restaurante %s: %s", restaurante_id, exc)
        return JSONResponse(
            status_code=502,
            content={"detail": "Error subiendo a Cloudinary"},
        )

    nueva_url = result["secure_url"]
    nuevo_public_id = result["public_id"]

    # 6. Si el restaurante tenía un logo con public_id DIFERENTE, borrar el anterior
    public_id_anterior = restaurante.get("logo_public_id")
    if public_id_anterior and public_id_anterior != nuevo_public_id:
        try:
            import cloudinary.uploader
            cloudinary.uploader.destroy(public_id_anterior)
        except Exception as exc:
            _log.warning("No se pudo borrar logo anterior '%s' de Cloudinary: %s", public_id_anterior, exc)

    # 7. Persistir en BD
    coleccion_restaurantes.update_one(
        {"_id": oid},
        {"$set": {"logo_url": nueva_url, "logo_public_id": nuevo_public_id}},
    )

    return {"logo_url": nueva_url, "logo_public_id": nuevo_public_id}


@router.delete(
    "/restaurantes/{restaurante_id}/logo",
    summary="Eliminar el logo de una sucursal (super_admin global; admin solo su sucursal)",
)
def borrar_logo_restaurante(
    restaurante_id: str,
    usuario: dict = Depends(get_current_user),
):
    # 0. Comprobar autorización: super_admin global, admin solo su sucursal
    rol = normalizar_rol(usuario.get("rol", ""))
    if rol == "super_admin":
        pass  # acceso global
    elif rol == "admin":
        if str(usuario.get("restaurante_id", "")) != str(restaurante_id):
            return JSONResponse(
                status_code=403,
                content={"detail": "No tienes permiso para modificar el logo de esta sucursal"},
            )
    else:
        return JSONResponse(
            status_code=403,
            content={"detail": "No tienes permiso para esta acción"},
        )

    # 1. Verificar disponibilidad de Cloudinary
    if not cloudinary_client._DISPONIBLE:
        return JSONResponse(status_code=503, content={"detail": _MSG_503})

    # 2. Verificar que la sucursal existe
    oid = _validar_oid(restaurante_id, "restaurante")
    restaurante = coleccion_restaurantes.find_one({"_id": oid})
    if not restaurante:
        return JSONResponse(status_code=404, content={"detail": "Sucursal no encontrada"})

    # 3. Borrar de Cloudinary si hay public_id registrado
    public_id = restaurante.get("logo_public_id")
    if public_id:
        try:
            import cloudinary.uploader
            cloudinary.uploader.destroy(public_id)
        except Exception as exc:
            _log.warning("No se pudo borrar logo '%s' de Cloudinary: %s", public_id, exc)

    # 4. Limpiar en BD con $set a string vacío (mismo patrón que borrar imagen de producto)
    coleccion_restaurantes.update_one(
        {"_id": oid},
        {"$set": {"logo_url": "", "logo_public_id": ""}},
    )

    return {"mensaje": "Logo eliminado correctamente"}
