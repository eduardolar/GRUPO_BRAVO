# ============================================================================
# backend/tickets.py
# ----------------------------------------------------------------------------
# Gestión del "ticket abierto" de una mesa.
#
# Distinción importante:
#   - PEDIDO (`pedidos`): unidad de cocina. Cuando una mesa pide un plato,
#     se crea un pedido para cocina con sus items.
#   - TICKET (`tickets`): unidad de cobro de la mesa. Acumula todos los
#     pedidos de una mesa durante el servicio y se cobra al final.
#
# Un ticket pasa por:
#   "abierto" (acumulando items) → "cobrado" (cerrado al cobrar) →
#   posibilidad de imprimir factura/ticket simplificado.
#
# Endpoints clave:
#   POST /tickets/mesa/{mesa_id}        → añadir item al ticket abierto.
#                                         Si no existe, lo crea.
#   GET  /tickets/mesa/{mesa_id}        → consultar ticket abierto.
#   POST /tickets/{ticket_id}/cobrar    → cerrar y marcar como cobrado.
#
# El total se recalcula sumando subtotales en cada inserción para que el
# ticket sea siempre consistente.
# ============================================================================
from fastapi import APIRouter, HTTPException
from datetime import datetime, timezone
from database import db

router = APIRouter()

# pymongo es un driver SÍNCRONO; las funciones no llevan async ni await.
# Si en el futuro se migra a motor (driver async), restaurar async/await.

@router.post("/tickets/mesa/{mesa_id}", summary="Agregar item al ticket abierto de una mesa")
def agregar_item_ticket(mesa_id: str, item: dict):
    if not all(k in item for k in ("producto_id", "nombre", "cantidad", "precio")):
        raise HTTPException(status_code=400, detail="Faltan campos del item")

    ticket = db.tickets.find_one({"mesa_id": mesa_id, "estado": "abierto"})

    nuevo_item = {
        "producto_id": item["producto_id"],
        "nombre": item["nombre"],
        "cantidad": item["cantidad"],
        "precio_unitario": item["precio"],
        "subtotal": item["cantidad"] * item["precio"],
    }

    if not ticket:
        ticket_doc = {
            "mesa_id": mesa_id,
            "estado": "abierto",
            "items": [nuevo_item],
            "total": nuevo_item["subtotal"],
            "fecha": datetime.now(timezone.utc),
        }
        result = db.tickets.insert_one(ticket_doc)
        ticket_doc["_id"] = str(result.inserted_id)
        return ticket_doc

    items = ticket.get("items", []) + [nuevo_item]
    total = sum(i["subtotal"] for i in items)
    db.tickets.update_one(
        {"_id": ticket["_id"]},
        {"$set": {"items": items, "total": total}},
    )
    ticket["items"] = items
    ticket["total"] = total
    ticket["_id"] = str(ticket["_id"])
    return ticket


@router.get("/tickets/mesa/{mesa_id}", summary="Obtener el ticket abierto de una mesa")
def obtener_ticket(mesa_id: str):
    ticket = db.tickets.find_one({"mesa_id": mesa_id, "estado": "abierto"})
    if not ticket:
        return None
    ticket["_id"] = str(ticket["_id"])
    return ticket


@router.post("/tickets/mesa/{mesa_id}/cerrar", summary="Cerrar el ticket abierto de una mesa")
def cerrar_ticket(mesa_id: str):
    resultado = db.tickets.update_one(
        {"mesa_id": mesa_id, "estado": "abierto"},
        {"$set": {"estado": "cerrado", "fecha_cierre": datetime.now(timezone.utc)}},
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="No hay ticket abierto para esta mesa")
    return {"mensaje": "Ticket cerrado"}
