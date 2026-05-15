# ============================================================================
# backend/audit.py
# ----------------------------------------------------------------------------
# Auditoría ESPECÍFICA de pagos (Stripe, PayPal, efectivo en caja).
#
# ¿Por qué una auditoría aparte de la general (`audit_general.py`)?
#   - Los pagos los exige PCI-DSS / RGPD con campos específicos (importe,
#     moneda, referencia, IP).
#   - Suele consultarse en bloque para conciliar con extractos bancarios
#     o para soporte ("¿qué pasó con este pago?").
#   - Conviene tener una colección dedicada con índices propios y políticas
#     de retención distintas a la auditoría general.
#
# Política "fire-and-forget":
#   La función NUNCA lanza. Si Mongo está caído o hay un error de red, la
#   ruta de pagos sigue funcionando. Auditoría es importante pero NO debe
#   bloquear un cobro al cliente. Si falla, logueamos el error y seguimos.
# ============================================================================
import logging
from datetime import datetime, timezone

from fastapi import Request

from database import coleccion_auditoria_pagos

logger = logging.getLogger("uvicorn")


def _ip(request: Request) -> str:
    """Devuelve la IP "real" del cliente, considerando proxies (X-Forwarded-For).

    Si estamos detrás de un balanceador/proxy (Cloudflare, Nginx, ALB...),
    `request.client.host` es la IP del proxy, no la del usuario. Por eso
    miramos primero `X-Forwarded-For` (que el proxy debería rellenar) y
    tomamos la PRIMERA IP de la lista (el cliente original; el resto son
    proxies intermedios).

    Aviso de seguridad: `X-Forwarded-For` se puede falsificar si NO hay un
    proxy reverso de confianza que lo limpie. En producción, asegúrate de
    que solo tu proxy escribe ese header.
    """
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    # Sin proxy: la IP directa del cliente. Puede ser None si la conexión
    # se cerró antes de leer (raro pero posible) → "unknown".
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
    """Inserta un evento de auditoría. Fire-and-forget: nunca lanza excepciones.

    Parámetros:
        evento: nombre semántico ("checkout.creado", "webhook.recibido",
                "pago.cobrado", "pago.fallido"...).
        proveedor: "stripe", "paypal", "efectivo", etc.
        estado: "ok" / "error" / "rechazado" — útil para filtrar dashboards.
        importe / moneda: si aplica (puede no aplicar a ciertos eventos).
        referencia: PaymentIntent ID, transaction ID, etc.
        detalle: texto libre con info adicional (NO meter datos sensibles
                 aquí; el log_redactor cubre logs pero esto va a Mongo).
    """
    try:
        # Construimos el doc dinámicamente para no guardar claves con None.
        # Las colecciones quedan más limpias y los índices más eficientes.
        doc = {
            "fecha": datetime.now(timezone.utc).isoformat(),
            "evento": evento,
            "proveedor": proveedor,
            "estado": estado,
            "ip": _ip(request),
        }
        if importe is not None:
            doc["importe"] = round(importe, 2)  # céntimos limpios
        if moneda:
            doc["moneda"] = moneda.upper()  # EUR, USD...
        if referencia:
            doc["referencia"] = referencia
        if detalle:
            doc["detalle"] = detalle
        coleccion_auditoria_pagos.insert_one(doc)
    except Exception as exc:
        # No relanzamos: la auditoría NO debe bloquear el flujo de pago.
        # Logueamos para que sysadmin lo investigue después.
        logger.error("Error registrando auditoría de pago [%s]: %s", evento, exc)
