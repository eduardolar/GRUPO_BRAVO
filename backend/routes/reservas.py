from fastapi import APIRouter, HTTPException, Query
from bson import ObjectId
from database import coleccion_reservas
from models import ReservaCrear

router = APIRouter(prefix="/reservas", tags=["Reservas"])

@router.post("")
def crear_reserva(reserva: ReservaCrear):
    reserva_dict = {k: v for k, v in reserva.dict().items() if v is not None}
    resultado = coleccion_reservas.insert_one(reserva_dict)
    reserva_dict["id"] = str(resultado.inserted_id)
    reserva_dict.pop("_id", None)
    return reserva_dict

@router.get("")
def obtener_reservas(usuario_id: str = Query(...)):
    reservas = coleccion_reservas.find({"usuario_id": usuario_id})
    resultado = []
    for r in reservas:
        resultado.append({
            "id": str(r["_id"]),
            "usuario_id": r.get("usuario_id", ""),
            "fecha": r.get("fecha", ""),
            "hora": r.get("hora", ""),
            "comensales": r.get("comensales", 0),
            "turno": r.get("turno", ""),
            "notas": r.get("notas", ""),
        })
    return resultado

@router.delete("/{reserva_id}")
def eliminar_reserva(reserva_id: str):
    resultado = coleccion_reservas.delete_one({"_id": ObjectId(reserva_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")
    return {"mensaje": "Reserva eliminada"}
