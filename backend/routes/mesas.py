from fastapi import APIRouter,Response, HTTPException
from database import coleccion_mesas
from models import ValidarQR
from services.qr_generator import generate_table_qr

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
            "disponible": m.get("estado", "libre") == "libre",
            "codigoQr": m.get("codigoQr", f"mesa_{m.get('numero', 0)}"),
        })
    return resultado

@router.post("/validar-qr")
def validar_qr_mesa(datos: ValidarQR):
    mesa = coleccion_mesas.find_one({"codigoQr": datos.codigo_qr})
    if not mesa:
        try:
            numero = int(datos.codigo_qr.replace("mesa_", ""))
            mesa = coleccion_mesas.find_one({"numero": numero})
        except ValueError:
            pass
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")
    return {
        "mesa_id": str(mesa["_id"]),
        "numero_mesa": mesa.get("numero", 0),
        "estado": "disponible" if mesa.get("estado", "libre") == "libre" else "ocupada",
    }
    return Response(content=image_bytes, media_type="image/png")
