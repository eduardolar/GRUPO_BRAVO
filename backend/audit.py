import logging
from datetime import datetime, timezone

from fastapi import Request

from database import coleccion_auditoria_pagos

logger = logging.getLogger("uvicorn")


def _ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def registrar_pago(
    request: Request,
    evento: str,
    proveedor: str,
    estado: str = "ok",
    importe: float | None = None,
    moneda: str | None = None,
    referencia: str | None = None,
    detalle: str | None = None,
) -> None:
    """Inserta un evento de auditoría. Fire-and-forget: nunca lanza excepciones."""
    try:
        doc = {
            "fecha": datetime.now(timezone.utc).isoformat(),
            "evento": evento,
            "proveedor": proveedor,
            "estado": estado,
            "ip": _ip(request),
        }
        if importe is not None:
            doc["importe"] = round(importe, 2)
        if moneda:
            doc["moneda"] = moneda.upper()
        if referencia:
            doc["referencia"] = referencia
        if detalle:
            doc["detalle"] = detalle
        coleccion_auditoria_pagos.insert_one(doc)
    except Exception as exc:
        logger.error("Error registrando auditoría de pago [%s]: %s", evento, exc)
