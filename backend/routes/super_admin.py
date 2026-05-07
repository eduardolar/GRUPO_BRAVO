"""Endpoints exclusivos para el rol super_admin.

Prefijo: /super-admin
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends

from pydantic import BaseModel

import audit_general as ag
from database import (
    coleccion_cierres_caja,
    coleccion_ingredientes,
    coleccion_pedidos,
    coleccion_reservas,
    coleccion_restaurantes,
)
from exceptions import ConflictError, NotFoundError, ValidacionError
from security import require_role

logger = logging.getLogger("uvicorn")

router = APIRouter(prefix="/super-admin", tags=["Super Admin"])

# Las constantes de auditoría viven en audit_general para que todos los módulos
# las compartan sin duplicarlas.
_SUSPENDIDO = ag.RESTAURANTE_SUSPENDIDO
_REACTIVADO = ag.RESTAURANTE_REACTIVADO

# Estados de pedido que se consideran "en cocina" (pendiente de ser servidos)
_ESTADOS_EN_COCINA = {"pendiente", "preparando", "listo"}

# Umbral de stock bajo: un ingrediente está "bajo" si su cantidad_actual
# cae por debajo de este porcentaje de la cantidad_minima definida, o
# directamente si cantidad_actual <= cantidad_minima.
# Usamos el criterio sencillo: cantidad_actual <= cantidad_minima.
_CAMPO_STOCK_MINIMO = "cantidad_minima"
_CAMPO_STOCK_ACTUAL = "cantidad_actual"


# ── Helpers internos ──────────────────────────────────────────────────────────

def _hoy_str() -> str:
    """Fecha de hoy en formato YYYY-MM-DD (UTC)."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _stock_bajo_count(restaurante_id: str) -> int:
    """Cuenta ingredientes con stock bajo para una sucursal.

    Un ingrediente se considera "bajo" cuando su cantidad_actual es menor o
    igual a su cantidad_minima (si ese campo existe) o cuando es <= 0.
    """
    filtro = {
        "restaurante_id": restaurante_id,
        "$expr": {
            "$lte": [
                {"$ifNull": [f"${_CAMPO_STOCK_ACTUAL}", 0]},
                {"$ifNull": [f"${_CAMPO_STOCK_MINIMO}", 0]},
            ]
        },
    }
    return coleccion_ingredientes.count_documents(filtro)


# ── KPIs globales del día ─────────────────────────────────────────────────────

@router.get("/kpis-hoy", summary="KPIs globales del día (super_admin)")
def kpis_hoy(
    actor: dict = Depends(require_role(["super_admin"])),
):
    """Devuelve agregados globales para el dashboard del super_admin.

    Todas las métricas son del día actual (UTC). Se consultan en paralelo
    lógico usando múltiples queries optimizadas; ninguna descarga datos en
    memoria salvo donde el volumen diario es necesariamente acotado.
    """
    hoy = _hoy_str()

    # ── 1. Restaurantes ────────────────────────────────────────────────────────
    todos_restaurantes = list(coleccion_restaurantes.find())
    sucursales_total = len(todos_restaurantes)
    ids_restaurantes = [str(r["_id"]) for r in todos_restaurantes]

    # Sucursales con al menos un cierre "abierto" hoy → se consideran "abiertas"
    ids_con_cierre_abierto: set[str] = set()
    for doc in coleccion_cierres_caja.find({"fecha": hoy, "estado": "abierto"}):
        rid = doc.get("restaurante_id")
        if rid:
            ids_con_cierre_abierto.add(rid)
    sucursales_abiertas = len(ids_con_cierre_abierto)

    # ── 2. Cierres pendientes (abiertos de hoy, sin cerrar) ───────────────────
    cierres_pendientes = coleccion_cierres_caja.count_documents(
        {"fecha": hoy, "estado": "abierto"}
    )

    # ── 3. Reservas de hoy ────────────────────────────────────────────────────
    reservas_hoy = coleccion_reservas.count_documents({"fecha": hoy})

    # ── 4. Pedidos e ingresos globales de hoy ─────────────────────────────────
    # El campo "fecha" en pedidos es ISO 8601 con hora; usamos rango string
    fecha_inicio_iso = f"{hoy}T00:00:00"
    fecha_fin_iso    = f"{hoy}T23:59:59"

    filtro_pedidos_hoy = {
        "fecha": {"$gte": fecha_inicio_iso, "$lte": fecha_fin_iso},
    }
    pedidos_hoy_docs = list(coleccion_pedidos.find(filtro_pedidos_hoy))

    ingresos_hoy = 0.0
    pedidos_hoy_count = 0
    items_vendidos = 0
    pedidos_en_cocina = 0

    # Acumuladores por sucursal: {restaurante_id: {ingresos, pedidos, en_cocina}}
    por_sucursal_acc: dict[str, dict] = {}

    for p in pedidos_hoy_docs:
        rid = p.get("restaurante_id", "")
        estado = (p.get("estado") or "").lower()
        total_p = float(p.get("total", 0))

        pedidos_hoy_count += 1

        if estado in {"listo", "entregado"}:
            ingresos_hoy += total_p
            items_vendidos += sum(
                it.get("cantidad", 1) for it in p.get("items", [])
            )

        if estado in _ESTADOS_EN_COCINA:
            pedidos_en_cocina += 1

        # Acumular por sucursal (todos los pedidos, no solo ventas)
        acc = por_sucursal_acc.setdefault(rid, {
            "ingresos_hoy": 0.0,
            "pedidos_hoy": 0,
            "pedidos_en_cocina": 0,
        })
        acc["pedidos_hoy"] += 1
        if estado in {"listo", "entregado"}:
            acc["ingresos_hoy"] += total_p
        if estado in _ESTADOS_EN_COCINA:
            acc["pedidos_en_cocina"] += 1

    # ── 5. Stock bajo global ───────────────────────────────────────────────────
    # Suma de ingredientes con stock bajo de todas las sucursales.
    # Una única query con $or filtra todos los restaurantes a la vez.
    stock_bajo_total = 0
    if ids_restaurantes:
        stock_bajo_total = coleccion_ingredientes.count_documents({
            "restaurante_id": {"$in": ids_restaurantes},
            "$expr": {
                "$lte": [
                    {"$ifNull": [f"${_CAMPO_STOCK_ACTUAL}", 0]},
                    {"$ifNull": [f"${_CAMPO_STOCK_MINIMO}", 0]},
                ]
            },
        })

    # ── 6. Ticket medio ───────────────────────────────────────────────────────
    # Calculado solo sobre pedidos en estado venta para no distorsionar
    pedidos_venta = sum(
        1 for p in pedidos_hoy_docs
        if (p.get("estado") or "").lower() in {"listo", "entregado"}
    )
    ticket_medio = round(ingresos_hoy / pedidos_venta, 2) if pedidos_venta else 0.0

    # ── 7. Construir detalle por sucursal ─────────────────────────────────────
    por_sucursal = []
    for r in todos_restaurantes:
        rid_str = str(r["_id"])
        acc = por_sucursal_acc.get(rid_str, {
            "ingresos_hoy": 0.0,
            "pedidos_hoy": 0,
            "pedidos_en_cocina": 0,
        })
        por_sucursal.append({
            "restaurante_id": rid_str,
            "nombre": r.get("nombre", ""),
            "ingresos_hoy": round(acc["ingresos_hoy"], 2),
            "pedidos_hoy": acc["pedidos_hoy"],
            "pedidos_en_cocina": acc["pedidos_en_cocina"],
            "abierta": rid_str in ids_con_cierre_abierto,
        })

    return {
        "fecha": hoy,
        "totales": {
            "ingresos_hoy": round(ingresos_hoy, 2),
            "pedidos_hoy": pedidos_hoy_count,
            "ticket_medio": ticket_medio,
            "items_vendidos": items_vendidos,
            "pedidos_en_cocina": pedidos_en_cocina,
            "reservas_hoy": reservas_hoy,
            "stock_bajo_total": stock_bajo_total,
            "cierres_pendientes": cierres_pendientes,
            "sucursales_abiertas": sucursales_abiertas,
            "sucursales_total": sucursales_total,
        },
        "por_sucursal": por_sucursal,
    }


# ── Suspender / Reactivar sucursal ────────────────────────────────────────────

class SuspenderBody(BaseModel):
    motivo: Optional[str] = None


@router.patch(
    "/restaurantes/{restaurante_id}/suspender",
    summary="Suspender (soft-delete) una sucursal",
)
def suspender_restaurante(
    restaurante_id: str,
    body: SuspenderBody = SuspenderBody(),
    actor: dict = Depends(require_role(["super_admin"])),
):
    """Marca la sucursal como inactiva (soft-delete).

    - 404 si no existe.
    - 409 si ya está suspendida.
    Registra en auditoría con motivo opcional.
    """
    try:
        oid = ObjectId(restaurante_id)
    except (InvalidId, TypeError):
        raise ValidacionError("ID de restaurante inválido")

    doc = coleccion_restaurantes.find_one({"_id": oid})
    if not doc:
        raise NotFoundError("Sucursal no encontrada")

    # activo puede estar ausente en docs legacy → se trata como True
    if not doc.get("activo", True) or "suspendido_at" in doc:
        raise ConflictError("La sucursal ya está suspendida")

    ahora = datetime.now(timezone.utc).isoformat()
    coleccion_restaurantes.update_one(
        {"_id": oid},
        {"$set": {"activo": False, "suspendido_at": ahora}},
    )

    ag.registrar(
        _SUSPENDIDO,
        actor=actor.get("correo"),
        objetivo=restaurante_id,
        detalle=body.motivo or "Sin motivo indicado",
    )

    return {
        "mensaje": "Sucursal suspendida",
        "restaurante_id": restaurante_id,
        "suspendido_at": ahora,
    }


@router.post(
    "/restaurantes/{restaurante_id}/reactivar",
    summary="Reactivar una sucursal suspendida",
)
def reactivar_restaurante(
    restaurante_id: str,
    actor: dict = Depends(require_role(["super_admin"])),
):
    """Reactiva una sucursal previamente suspendida.

    - 404 si no existe.
    - 409 si ya está activa (no suspendida).
    """
    try:
        oid = ObjectId(restaurante_id)
    except (InvalidId, TypeError):
        raise ValidacionError("ID de restaurante inválido")

    doc = coleccion_restaurantes.find_one({"_id": oid})
    if not doc:
        raise NotFoundError("Sucursal no encontrada")

    if doc.get("activo", True) and "suspendido_at" not in doc:
        raise ConflictError("La sucursal ya está activa")

    coleccion_restaurantes.update_one(
        {"_id": oid},
        {
            "$set": {"activo": True},
            "$unset": {"suspendido_at": ""},
        },
    )

    ag.registrar(
        _REACTIVADO,
        actor=actor.get("correo"),
        objetivo=restaurante_id,
    )

    return {
        "mensaje": "Sucursal reactivada",
        "restaurante_id": restaurante_id,
    }
