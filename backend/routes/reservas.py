from fastapi import APIRouter, HTTPException, Query
from bson import ObjectId
from database import coleccion_reservas, coleccion_mesas
from models import ReservaCrear

router = APIRouter(prefix="/reservas", tags=["Reservas"])

DURACION_RESERVA_MIN = 90


def _hora_a_minutos(hora: str) -> int:
    """Convierte 'HH:MM' a minutos desde medianoche."""
    partes = hora.split(":")
    return int(partes[0]) * 60 + int(partes[1])


def _hay_conflicto_horario(hora_a: str, hora_b: str) -> bool:
    """Dos reservas de 90 min se solapan."""
    inicio_a = _hora_a_minutos(hora_a)
    fin_a = inicio_a + DURACION_RESERVA_MIN
    inicio_b = _hora_a_minutos(hora_b)
    fin_b = inicio_b + DURACION_RESERVA_MIN
    return inicio_a < fin_b and inicio_b < fin_a


def _mesas_ocupadas_por_hora(fecha: str, hora: str) -> set:
    """Devuelve los mesa_id con reserva que solapa la hora indicada."""
    reservas = coleccion_reservas.find({"fecha": fecha, "estado": "Confirmada"})
    ocupadas = set()
    for r in reservas:
        if r.get("mesa_id") and r.get("hora") and _hay_conflicto_horario(r["hora"], hora):
            ocupadas.add(r["mesa_id"])
    return ocupadas


@router.get("/mesas-disponibles")
def mesas_disponibles(
    fecha: str = Query(...),
    hora: str = Query(...),
    comensales: int = Query(1),
):
    """Devuelve las mesas libres para una fecha, hora y nº de comensales."""
    ocupadas = _mesas_ocupadas_por_hora(fecha, hora)
    mesas = coleccion_mesas.find({"capacidad": {"$gte": comensales}})
    resultado = []
    for m in mesas:
        mid = str(m["_id"])
        if mid not in ocupadas:
            resultado.append({
                "id": mid,
                "numero": m.get("numero", 0),
                "capacidad": m.get("capacidad", 0),
            })
    return resultado


@router.post("")
def crear_reserva(reserva: ReservaCrear):
    ocupadas = _mesas_ocupadas_por_hora(reserva.fecha, reserva.hora)

    if reserva.mesa_id:
        # Si se indica mesa, comprobar que existe y no está ya reservada
        mesa = coleccion_mesas.find_one({"_id": ObjectId(reserva.mesa_id)})
        if not mesa:
            raise HTTPException(status_code=404, detail="Mesa no encontrada")
        if mesa.get("capacidad", 0) < reserva.comensales:
            raise HTTPException(
                status_code=400,
                detail=f"La mesa tiene capacidad para {mesa.get('capacidad', 0)} personas, pero se solicitan {reserva.comensales}",
            )
        if reserva.mesa_id in ocupadas:
            raise HTTPException(
                status_code=409,
                detail="Esa mesa ya está reservada para esa fecha y hora",
            )
        mesa_asignada = mesa
    else:
        # Asignar automáticamente la mesa más pequeña con capacidad suficiente
        candidatas = coleccion_mesas.find(
            {"capacidad": {"$gte": reserva.comensales}}
        ).sort("capacidad", 1)
        mesa_asignada = None
        for m in candidatas:
            if str(m["_id"]) not in ocupadas:
                mesa_asignada = m
                break
        if not mesa_asignada:
            raise HTTPException(
                status_code=409,
                detail=f"No hay mesas disponibles para {reserva.comensales} comensales a las {reserva.hora}",
            )

    mesa_id = str(mesa_asignada["_id"])
    numero_mesa = mesa_asignada.get("numero", 0)

    reserva_dict = {k: v for k, v in reserva.dict().items() if v is not None}
    reserva_dict["mesa_id"] = mesa_id
    reserva_dict["numero_mesa"] = numero_mesa
    reserva_dict["estado"] = "Confirmada"
    resultado = coleccion_reservas.insert_one(reserva_dict)
    reserva_dict["id"] = str(resultado.inserted_id)
    reserva_dict.pop("_id", None)
    return reserva_dict

@router.get("")
def obtener_reservas(usuario_id: str = Query(...)):
    reservas = coleccion_reservas.find({"usuario_id": usuario_id})
    resultado = []
    for r in reservas:
        item = {
            "id": str(r["_id"]),
            "usuario_id": r.get("usuario_id", ""),
            "nombre_completo": r.get("nombre_completo", ""),
            "fecha": r.get("fecha", ""),
            "hora": r.get("hora", ""),
            "comensales": r.get("comensales", 0),
            "turno": r.get("turno", ""),
            "estado": r.get("estado", "Confirmada"),
            "mesa_id": r.get("mesa_id", ""),
            "numero_mesa": r.get("numero_mesa"),
            "notas": r.get("notas", ""),
        }
        # Si no tiene numero_mesa guardado, buscarlo desde la colección de mesas
        if item["numero_mesa"] is None and r.get("mesa_id"):
            try:
                mesa = coleccion_mesas.find_one({"_id": ObjectId(r["mesa_id"])})
                item["numero_mesa"] = mesa.get("numero", 0) if mesa else None
            except Exception:
                item["numero_mesa"] = None
        resultado.append(item)
    return resultado

@router.patch("/{reserva_id}")
def actualizar_reserva(reserva_id: str, datos: dict):
    campos = {k: v for k, v in datos.items() if k in ("comensales",) and v is not None}
    if not campos:
        raise HTTPException(status_code=400, detail="No hay campos válidos para actualizar")
    resultado = coleccion_reservas.update_one(
        {"_id": ObjectId(reserva_id)},
        {"$set": campos},
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")
    return {"mensaje": "Reserva actualizada"}

@router.delete("/{reserva_id}")
def eliminar_reserva(reserva_id: str):
    resultado = coleccion_reservas.delete_one({"_id": ObjectId(reserva_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")
    return {"mensaje": "Reserva eliminada"}
