from fastapi import APIRouter, Response, HTTPException
from bson import ObjectId
from pydantic import BaseModel
from database import coleccion_mesas
from models import ValidarQR
from services.qr_generator import generate_table_qr

class ActualizarEstadoMesa(BaseModel):
    disponible: bool

class CrearMesa(BaseModel):
    numero: int
    capacidad: int
    ubicacion: str = "interior"
    codigoQr: str

router = APIRouter(prefix="/mesas", tags=["Mesas"])

@router.get("")
def obtener_mesas():
    mesas = coleccion_mesas.find()
    resultado = []
    for m in mesas:
        resultado.append({
            "id": str(m["_id"]),
            "numero": m.get("numero", 0),
            "capacidad": m.get("capacidad", 0),
            "ubicacion": m.get("ubicacion", "interior"),
            "disponible": m.get("estado", "libre") == "libre",
            "codigoQr": m.get("codigoQr", m.get("codigo_qr", f"mesa_{m.get('numero', 0)}")),
        })
    return resultado

@router.post("")
def crear_mesa(datos: CrearMesa):
    existente = coleccion_mesas.find_one({"numero": datos.numero})
    if existente:
        raise HTTPException(status_code=409, detail="Ya existe una mesa con ese número")

    nueva = {
        "numero": datos.numero,
        "capacidad": datos.capacidad,
        "ubicacion": datos.ubicacion,
        "codigoQr": datos.codigoQr,
        "estado": "libre",
    }
    result = coleccion_mesas.insert_one(nueva)
    return {
        "id": str(result.inserted_id),
        "numero": datos.numero,
        "capacidad": datos.capacidad,
        "ubicacion": datos.ubicacion,
        "disponible": True,
        "codigoQr": datos.codigoQr,
    }


@router.patch("/{mesa_id}")
def actualizar_estado_mesa(mesa_id: str, datos: ActualizarEstadoMesa):
    try:
        object_id = ObjectId(mesa_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    nuevo_estado = "libre" if datos.disponible else "ocupada"
    result = coleccion_mesas.update_one(
        {"_id": object_id},
        {"$set": {"estado": nuevo_estado}}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")

    return {"ok": True, "estado": nuevo_estado}


@router.post("/validar-qr")
def validar_qr_mesa(datos: ValidarQR):
    mesa = coleccion_mesas.find_one({"codigoQr": datos.codigoQr}) or coleccion_mesas.find_one({"codigo_qr": datos.codigoQr})
    if not mesa:
        try:
            numero = int(datos.codigoQr.replace("mesa_", ""))
            mesa = coleccion_mesas.find_one({"numero": numero})
        except ValueError:
            pass
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")
    return {
        "mesaId": str(mesa["_id"]),
        "numeroMesa": mesa.get("numero", 0),
        "estado": "disponible" if mesa.get("estado", "libre") == "libre" else "ocupada",
    }
    return Response(content=image_bytes, media_type="image/png")
