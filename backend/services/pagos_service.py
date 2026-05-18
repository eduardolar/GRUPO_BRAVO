# ============================================================================
# backend/services/pagos_service.py
# ----------------------------------------------------------------------------
# PILOTO de capa de servicios (recomendación 6.2.3 de la revisión integral).
#
# Objetivo: empezar a separar lógica de negocio de los routers SIN reescribir
# todo pagos.py de golpe. Aquí viven las funciones autocontenidas y puras
# (en el sentido de "sin manejar request/response HTTP directamente") que
# antes estaban inline en pagos.py:
#
#   - _exigir_stripe       : guarda de configuración de Stripe.
#   - _total_pedido        : total server-side de un pedido (anti-manipulación).
#   - _autorizar_pedido    : autorización multi-tenant sobre un pedido.
#   - _autorizar_intent    : recupera PaymentIntent y valida propiedad.
#
# Se mantienen los nombres EXACTOS (incluido el guion bajo inicial) para que
# `pagos.py` siga llamándolos igual: el contrato de la API no cambia y la
# suite de tests sigue siendo válida sin tocarse. `pagos.py` ahora hace
# `from services.pagos_service import (...)`.
#
# Nota sobre Stripe: `stripe` es un módulo singleton. `pagos.py` fija
# `stripe.api_key` al importarse (lo hace main.py al arrancar), así que
# cuando estas funciones leen `stripe.api_key` ven el mismo valor. No se
# duplica la configuración aquí a propósito (responsabilidad única).
# ============================================================================
"""Capa de servicios de pagos (piloto de extracción desde pagos.py)."""
import logging

import stripe
from bson import ObjectId
from fastapi import HTTPException

from security import normalizar_rol
from database import coleccion_pedidos

logger = logging.getLogger("uvicorn.error")


def _exigir_stripe() -> None:
    """Detiene la petición con 503 si Stripe no está configurado.

    No revela detalles internos como el nombre de la variable que falta:
    eso aparece sólo en el log del servidor.
    """
    if not stripe.api_key:
        logger.error("STRIPE_SECRET_KEY ausente: el servicio de pagos no puede operar.")
        raise HTTPException(status_code=503, detail="Servicio de pagos no disponible")


def _total_pedido(pedido_id: str) -> float:
    """Return the server-calculated total for a pedido; never trust client amounts."""
    if not ObjectId.is_valid(pedido_id):
        raise HTTPException(status_code=400, detail="pedido_id inválido")
    pedido = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)}, {"total": 1})
    if not pedido:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")
    return float(pedido["total"])


def _autorizar_pedido(pedido_id: str, current_user: dict) -> dict:
    """Verifica que el caller tiene permiso sobre el pedido y devuelve el doc.

    - cliente: solo su propio pedido (usuario_id == sub).
    - camarero/admin: solo pedidos de su restaurante_id.
    - super_admin: sin restricción.
    Lanza 403 si no tiene permiso.
    """
    if not ObjectId.is_valid(pedido_id):
        raise HTTPException(status_code=400, detail="pedido_id inválido")
    pedido = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    if not pedido:
        raise HTTPException(status_code=404, detail="Pedido no encontrado")

    rol = normalizar_rol(current_user.get("rol", ""))
    if rol == "cliente":
        if pedido.get("usuario_id") != current_user.get("sub"):
            raise HTTPException(status_code=403, detail="No puedes acceder a este pedido")
    elif rol in {"camarero", "admin"}:
        rid = current_user.get("restaurante_id")
        if rid and pedido.get("restaurante_id") and pedido["restaurante_id"] != rid:
            raise HTTPException(status_code=403, detail="No puedes acceder a pedidos de otra sucursal")
    # super_admin: sin restricción
    return pedido


def _autorizar_intent(payment_intent_id: str, current_user: dict) -> dict:
    """Recupera el PaymentIntent y verifica propiedad si lleva pedido_id.

    Los `*/confirm` y `*/verify` recibían un payment_intent_id opaco SIN
    autenticación: un cliente legítimo podía confirmar/consultar intents
    ajenos y filtrar metadata (p. ej. `platform`). Ahora:

      - El endpoint exige `Depends(get_current_user)` (no más anónimo).
      - Si el intent tiene `metadata.pedido_id`, se valida propiedad con
        `_autorizar_pedido` (cliente: su pedido; camarero/admin: su
        sucursal; super_admin: todo).
      - Si NO hay pedido_id (flujo legacy: el pedido se crea DESPUÉS del
        pago), no hay propiedad que comprobar todavía, pero la
        autenticación ya elimina el acceso anónimo.

    Devuelve el intent recuperado para que el llamante lo reutilice y no
    haga una segunda llamada a Stripe.
    """
    _exigir_stripe()
    if not payment_intent_id or not payment_intent_id.strip():
        raise HTTPException(status_code=400, detail="payment_intent_id requerido")
    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id.strip())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
    pedido_id = (intent.get("metadata") or {}).get("pedido_id")
    if pedido_id:
        _autorizar_pedido(pedido_id, current_user)
    return intent
