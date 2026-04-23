from fastapi import APIRouter
from datetime import datetime
from bson import ObjectId
from database import db

router = APIRouter()

@router.post("/tickets/mesa/{mesa_id}")
async def agregar_item_ticket(mesa_id: str, item: dict):
    ticket = await db.tickets.find_one({"mesa_id": mesa_id, "estado": "abierto"})

    if not ticket:
        ticket = {
            "mesa_id": mesa_id,
            "estado": "abierto",
            "items": [],
            "total": 0,
            "fecha": datetime.now()
        }
        await db.tickets.insert_one(ticket)

    ticket["items"].append({
        "producto_id": item["producto_id"],
        "nombre": item["nombre"],
        "cantidad": item["cantidad"],
        "precio_unitario": item["precio"],
        "subtotal": item["cantidad"] * item["precio"]
    })

    ticket["total"] = sum(i["subtotal"] for i in ticket["items"])

    await db.tickets.update_one(
        {"mesa_id": mesa_id, "estado": "abierto"},
        {"$set": ticket}
    )

    return ticket


@router.get("/tickets/mesa/{mesa_id}")
async def obtener_ticket(mesa_id: str):
    return await db.tickets.find_one({"mesa_id": mesa_id, "estado": "abierto"})


@router.post("/tickets/mesa/{mesa_id}/cerrar")
async def cerrar_ticket(mesa_id: str):
    await db.tickets.update_one(
        {"mesa_id": mesa_id, "estado": "abierto"},
        {"$set": {"estado": "cerrado"}}
    )
    return {"mensaje": "Ticket cerrado"}
