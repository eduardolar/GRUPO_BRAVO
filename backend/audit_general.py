"""
Auditoría general de acciones de usuario y sistema.
Uso: registrar(accion, detalle, actor, objetivo)  — fire-and-forget, nunca lanza excepciones.
"""
import logging
from datetime import datetime, timezone
from database import coleccion_auditoria

logger = logging.getLogger("uvicorn")

# Categorías de eventos
USUARIO_CREADO     = "usuario.creado"
USUARIO_ELIMINADO  = "usuario.eliminado"
USUARIO_EDITADO    = "usuario.editado"
ROL_CAMBIADO       = "usuario.rol_cambiado"
ESTADO_CAMBIADO    = "usuario.estado_cambiado"
LOGIN_OK           = "auth.login_ok"
LOGIN_FALLIDO      = "auth.login_fallido"
RESTAURANTE_CREADO = "restaurante.creado"
RESTAURANTE_EDITADO= "restaurante.editado"


def registrar(
    accion: str,
    *,
    actor: str | None = None,
    objetivo: str | None = None,
    detalle: str | None = None,
    extra: dict | None = None,
) -> None:
    """Inserta un evento de auditoría. Fire-and-forget."""
    try:
        doc: dict = {
            "fecha": datetime.now(timezone.utc).isoformat(),
            "accion": accion,
        }
        if actor:   doc["actor"]   = actor
        if objetivo: doc["objetivo"] = objetivo
        if detalle:  doc["detalle"]  = detalle
        if extra:    doc.update(extra)
        coleccion_auditoria.insert_one(doc)
    except Exception as exc:
        logger.error("Error registrando auditoría [%s]: %s", accion, exc)
