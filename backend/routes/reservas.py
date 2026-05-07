import logging
from fastapi import APIRouter, HTTPException, Query
from bson import ObjectId
from datetime import date
from database import coleccion_reservas, coleccion_mesas, coleccion_restaurantes
from models import ReservaCrear

logger = logging.getLogger("uvicorn")

router = APIRouter(prefix="/reservas", tags=["Reservas"])

DURACION_RESERVA_MIN = 90


def _hora_a_minutos(hora: str) -> int:
    partes = hora.split(":")
    return int(partes[0]) * 60 + int(partes[1])


def _hay_conflicto_horario(hora_a: str, hora_b: str) -> bool:
    inicio_a = _hora_a_minutos(hora_a)
    fin_a = inicio_a + DURACION_RESERVA_MIN
    inicio_b = _hora_a_minutos(hora_b)
    fin_b = inicio_b + DURACION_RESERVA_MIN
    return inicio_a < fin_b and inicio_b < fin_a


def _mesas_ocupadas_por_hora(
    fecha: str, hora: str, restaurante_id: str | None = None
) -> set:
    """Devuelve los `mesa_id` ya ocupados a esa hora. Si se pasa
    `restaurante_id`, solo considera reservas de esa sucursal — necesario
    para que las reservas de Madrid no marquen como ocupadas las mesas de
    Zaragoza (aunque los IDs son únicos, la búsqueda es más eficiente)."""
    filtro: dict = {"fecha": fecha, "estado": "Confirmada"}
    if restaurante_id:
        filtro["restaurante_id"] = restaurante_id
    reservas = coleccion_reservas.find(filtro)
    ocupadas = set()
    for r in reservas:
        if r.get("mesa_id") and r.get("hora") and _hay_conflicto_horario(
            r["hora"], hora
        ):
            ocupadas.add(r["mesa_id"])
    return ocupadas


@router.get("/mesas-disponibles")
def mesas_disponibles(
    fecha: str = Query(...),
    hora: str = Query(...),
    comensales: int = Query(1),
    restauranteId: str | None = Query(None),
    restaurante_id: str | None = Query(None),
):
    rid = restauranteId or restaurante_id
    ocupadas = _mesas_ocupadas_por_hora(fecha, hora, rid)
    # Filtramos las mesas candidatas también por sucursal: un cliente que
    # reserva en Madrid nunca debe ver mesas de Zaragoza.
    filtro_mesas: dict = {"capacidad": {"$gte": comensales}}
    if rid:
        filtro_mesas["restaurante_id"] = rid
    mesas = coleccion_mesas.find(filtro_mesas)
    resultado = []
    for m in mesas:
        mid = str(m["_id"])
        if mid not in ocupadas:
            resultado.append({
                "id": mid,
                "numero": m.get("numero", 0),
                "capacidad": m.get("capacidad", 0),
                "restauranteId": m.get("restaurante_id"),
            })
    return resultado


# ⚠️ Este endpoint debe estar ANTES de @router.get("") para que FastAPI no lo confunda
@router.get("/futuras")
def obtener_reservas_futuras(
    restauranteId: str | None = Query(None),
    restaurante_id: str | None = Query(None),
):
    """Devuelve todas las reservas desde hoy en adelante (para trabajadores).
    Si se pasa `restauranteId`, filtra por sucursal — necesario para que un
    trabajador de Madrid no vea las reservas de Zaragoza."""
    hoy = date.today().strftime("%Y-%m-%d")
    rid = restauranteId or restaurante_id
    filtro: dict = {"fecha": {"$gte": hoy}}
    if rid:
        filtro["restaurante_id"] = rid
    reservas = coleccion_reservas.find(filtro)
    resultado = []
    for r in reservas:
        item = {
            "id": str(r["_id"]),
            "usuarioId": r.get("usuario_id", ""),
            "nombreCompleto": r.get("nombre_completo", ""),
            "fecha": r.get("fecha", ""),
            "hora": r.get("hora", ""),
            "comensales": r.get("comensales", 0),
            "turno": r.get("turno", ""),
            "estado": r.get("estado", "Confirmada"),
            "mesaId": r.get("mesa_id", ""),
            "numeroMesa": r.get("numero_mesa"),
            "notas": r.get("notas", ""),
        }
        if item["numeroMesa"] is None and r.get("mesa_id"):
            try:
                mesa = coleccion_mesas.find_one({"_id": ObjectId(r["mesa_id"])})
                item["numeroMesa"] = mesa.get("numero", 0) if mesa else None
            except Exception:
                logger.warning("No se pudo obtener número de mesa para mesa_id=%s", r.get("mesa_id"))
                item["numeroMesa"] = None
        resultado.append(item)
    return resultado


@router.get("")
def obtener_reservas(usuarioId: str = Query(...)):
    reservas = coleccion_reservas.find({"usuario_id": usuarioId})
    resultado = []
    for r in reservas:
        item = {
            "id": str(r["_id"]),
            "usuarioId": r.get("usuario_id", ""),
            "nombreCompleto": r.get("nombre_completo", ""),
            "fecha": r.get("fecha", ""),
            "hora": r.get("hora", ""),
            "comensales": r.get("comensales", 0),
            "turno": r.get("turno", ""),
            "estado": r.get("estado", "Confirmada"),
            "mesaId": r.get("mesa_id", ""),
            "numeroMesa": r.get("numero_mesa"),
            "notas": r.get("notas", ""),
        }
        if item["numeroMesa"] is None and r.get("mesa_id"):
            try:
                mesa = coleccion_mesas.find_one({"_id": ObjectId(r["mesa_id"])})
                item["numeroMesa"] = mesa.get("numero", 0) if mesa else None
            except Exception:
                logger.warning("No se pudo obtener número de mesa para mesa_id=%s", r.get("mesa_id"))
                item["numeroMesa"] = None
        resultado.append(item)
    return resultado


def _hora_en_rango(hora: str, apertura: str, cierre: str) -> bool:
    mins = _hora_a_minutos(hora)
    a = _hora_a_minutos(apertura)
    c = _hora_a_minutos(cierre)
    if c > a:
        return a <= mins < c
    else:  # cruza medianoche
        return mins >= a or mins < c


@router.post("")
def crear_reserva(reserva: ReservaCrear):
    # Validar horario del restaurante si se proporcionó
    if reserva.restauranteId:
        try:
            rest = coleccion_restaurantes.find_one({"_id": ObjectId(reserva.restauranteId)})
        except Exception:
            rest = None
        if rest:
            apertura = rest.get("horario_apertura")
            cierre = rest.get("horario_cierre")
            if apertura and cierre:
                if not _hora_en_rango(reserva.hora, apertura, cierre):
                    raise HTTPException(
                        status_code=400,
                        detail=f"El restaurante no acepta reservas a las {reserva.hora}. Horario de apertura: {apertura} – {cierre}",
                    )

    ocupadas = _mesas_ocupadas_por_hora(reserva.fecha, reserva.hora, reserva.restauranteId)

    if reserva.mesaId:
        mesa = coleccion_mesas.find_one({"_id": ObjectId(reserva.mesaId)})
        if not mesa:
            raise HTTPException(status_code=404, detail="Mesa no encontrada")
        # La mesa elegida debe pertenecer a la sucursal de la reserva: si no,
        # estaríamos reservando una mesa de Madrid para un cliente de Zaragoza.
        if reserva.restauranteId:
            rid_mesa = mesa.get("restaurante_id")
            if rid_mesa and rid_mesa != reserva.restauranteId:
                raise HTTPException(
                    status_code=400,
                    detail="La mesa pertenece a otra sucursal",
                )
        if mesa.get("capacidad", 0) < reserva.comensales:
            raise HTTPException(
                status_code=400,
                detail=f"La mesa tiene capacidad para {mesa.get('capacidad', 0)} personas, pero se solicitan {reserva.comensales}",
            )
        if reserva.mesaId in ocupadas:
            raise HTTPException(
                status_code=409,
                detail="Esa mesa ya está reservada para esa fecha y hora",
            )
        mesa_asignada = mesa
    else:
        # Asignación automática: solo entre mesas de la misma sucursal.
        filtro_candidatas: dict = {"capacidad": {"$gte": reserva.comensales}}
        if reserva.restauranteId:
            filtro_candidatas["restaurante_id"] = reserva.restauranteId
        candidatas = coleccion_mesas.find(filtro_candidatas).sort("capacidad", 1)
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

    # DB stores snake_case field names
    reserva_dict = {
        "usuario_id": reserva.usuarioId,
        "nombre_completo": reserva.nombreCompleto,
        "fecha": reserva.fecha,
        "hora": reserva.hora,
        "comensales": reserva.comensales,
        "turno": reserva.turno,
        "notas": reserva.notas,
        "mesa_id": mesa_id,
        "numero_mesa": numero_mesa,
        "estado": "Confirmada",
        "restaurante_id": reserva.restauranteId,
    }
    if reserva.notas is None:
        reserva_dict.pop("notas")
    resultado = coleccion_reservas.insert_one(reserva_dict)
    return {
        "id": str(resultado.inserted_id),
        "usuarioId": reserva.usuarioId,
        "nombreCompleto": reserva.nombreCompleto,
        "fecha": reserva.fecha,
        "hora": reserva.hora,
        "comensales": reserva.comensales,
        "turno": reserva.turno,
        "estado": "Confirmada",
        "mesaId": mesa_id,
        "numeroMesa": numero_mesa,
        "notas": reserva.notas,
    }


@router.patch("/{reserva_id}")
def actualizar_comensales(reserva_id: str, datos: dict):
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


@router.put("/{reserva_id}")
def actualizar_reserva_completa(reserva_id: str, datos: dict):
    campos_permitidos = {"fecha", "hora", "comensales", "turno", "notas", "estado"}
    campos = {k: v for k, v in datos.items() if k in campos_permitidos and v is not None}
    if not campos:
        raise HTTPException(status_code=400, detail="No hay campos válidos")
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