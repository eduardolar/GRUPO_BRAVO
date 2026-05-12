import logging
import re
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, field_validator
from bson import ObjectId
from bson.errors import InvalidId

from database import coleccion_cupones
from security import require_role, get_current_user, normalizar_rol
import audit_general as ag

logger = logging.getLogger("uvicorn")

router = APIRouter(prefix="/cupones", tags=["Cupones"])


# ─── Modelos Pydantic ──────────────────────────────────────────────────────────

class CuponCrear(BaseModel):
    codigo: str
    tipo: str  # "porcentaje" | "fijo"
    valor: float
    descripcion: Optional[str] = ""
    usos_maximos: Optional[int] = None
    fecha_inicio: Optional[str] = None  # ISO date string "YYYY-MM-DD"
    fecha_fin: Optional[str] = None
    restaurante_id: Optional[str] = None

    @field_validator("codigo")
    @classmethod
    def validar_codigo(cls, v: str) -> str:
        v = v.strip().upper()
        if not v:
            raise ValueError("El código no puede estar vacío")
        if not re.match(r"^[A-Z0-9_-]{2,20}$", v):
            raise ValueError("El código solo puede contener letras, números, guiones y guiones bajos")
        return v

class CuponValidar(BaseModel):
    codigo: str
    subtotal: float
    coste_envio: float = 0.0
    restaurante_id: Optional[str] = None


# ─── Utilidades Internas ──────────────────────────────────────────────────────

def _cupon_vigente(cupon: dict) -> Optional[str]:
    """Verifica si el cupón está activo, en fecha y con usos disponibles."""
    if not cupon.get("activo", True):
        return "El cupón está desactivado"
    
    hoy = date.today().isoformat()
    if cupon.get("fecha_inicio") and hoy < cupon["fecha_inicio"]:
        return "El cupón aún no está vigente"
    if cupon.get("fecha_fin") and hoy > cupon["fecha_fin"]:
        return "El cupón ha expirado"
    
    usos_actuales = cupon.get("usos_actuales", 0)
    usos_max = cupon.get("usos_maximos")
    if usos_max is not None and usos_actuales >= usos_max:
        return "El cupón ha agotado su límite de usos"
    
    return None


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/validar", summary="Validar un cupón y calcular descuento")
def validar_cupon(datos: CuponValidar):
    codigo_limpio = datos.codigo.strip().upper()
    cupon = coleccion_cupones.find_one({"codigo": codigo_limpio})
    
    if not cupon:
        return {
            "valido": False,
            "mensaje": "Cupón no encontrado",
            "descuento": 0.0
        }

    # Validar vigencia
    error = _cupon_vigente(cupon)
    if error:
        return {"valido": False, "mensaje": error, "descuento": 0.0}

    # Validar restricción de restaurante
    rid_cupon = cupon.get("restaurante_id")
    if rid_cupon and datos.restaurante_id and str(rid_cupon) != str(datos.restaurante_id):
        return {
            "valido": False,
            "mensaje": "Este cupón no es válido para este restaurante",
            "descuento": 0.0
        }

    tipo = cupon.get("tipo")
    valor = float(cupon.get("valor", 0))
    subtotal = round(datos.subtotal, 2)
    descuento = 0.0

    if tipo == "porcentaje":
        descuento = round(subtotal * (valor / 100), 2)
    elif tipo == "fijo":
        # No descontar más del total del pedido
        total_max = round(subtotal + datos.coste_envio, 2)
        descuento = round(min(valor, total_max), 2)
    else:
        return {"valido": False, "mensaje": "Tipo de cupón desconocido", "descuento": 0.0}

    return {
        "valido": True,
        "mensaje": "Cupón aplicado correctamente",
        "descuento": descuento,
        "codigo": codigo_limpio,
        "tipo": tipo
    }

@router.get("/")
def listar_cupones(solo_activos: bool = False, user=Depends(require_role(["admin", "root"]))):
    filtro = {"activo": True} if solo_activos else {}
    lista = list(coleccion_cupones.find(filtro))
    for c in lista:
        c["_id"] = str(c["_id"])
    return lista

@router.post("/")
def crear_cupon(datos: CuponCrear, user=Depends(require_role(["admin", "root"]))):
    if coleccion_cupones.find_one({"codigo": datos.codigo}):
        raise HTTPException(status_code=400, detail="El código de cupón ya existe")
    
    nuevo_cupon = datos.model_dump()
    nuevo_cupon["activo"] = True
    nuevo_cupon["usos_actuales"] = 0
    
    res = coleccion_cupones.insert_one(nuevo_cupon)
    ag.registrar_evento(user["email"], "CREAR_CUPON", f"Cupón {datos.codigo} creado")
    return {"id": str(res.inserted_id), "status": "success"}

@router.post("/{cupon_id}/usar")
def registrar_uso_cupon(cupon_id: str):
    try:
        oid = ObjectId(cupon_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID de cupón inválido")
        
    res = coleccion_cupones.update_one(
        {"_id": oid},
        {"$inc": {"usos_actuales": 1}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    return {"status": "uso registrado"}