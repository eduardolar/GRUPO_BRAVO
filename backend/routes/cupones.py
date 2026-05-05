from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from pydantic import BaseModel, field_validator
from bson import ObjectId
from bson.errors import InvalidId
from database import coleccion_cupones
from security import require_role, get_current_user
import re

router = APIRouter(prefix="/cupones", tags=["Cupones"])


# ─── Modelos Pydantic ──────────────────────────────────────────────────────────

class CuponCrear(BaseModel):
    codigo: str
    tipo: str          # "porcentaje" | "fijo"
    valor: float
    descripcion: Optional[str] = ""
    usos_maximos: Optional[int] = None
    fecha_inicio: Optional[str] = None   # ISO date string "YYYY-MM-DD"
    fecha_fin: Optional[str] = None

    @field_validator("codigo")
    @classmethod
    def validar_codigo(cls, v: str) -> str:
        v = v.strip().upper()
        if not v:
            raise ValueError("El código no puede estar vacío")
        if not re.match(r'^[A-Z0-9_-]{2,20}$', v):
            raise ValueError("El código solo puede contener letras, números, guiones y guiones bajos (2-20 caracteres)")
        return v

    @field_validator("tipo")
    @classmethod
    def validar_tipo(cls, v: str) -> str:
        if v not in ("porcentaje", "fijo"):
            raise ValueError("El tipo debe ser 'porcentaje' o 'fijo'")
        return v

    @field_validator("valor")
    @classmethod
    def validar_valor(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("El valor debe ser mayor que 0")
        return round(v, 2)


class CuponEditar(BaseModel):
    descripcion: Optional[str] = None
    activo: Optional[bool] = None
    usos_maximos: Optional[int] = None
    fecha_inicio: Optional[str] = None
    fecha_fin: Optional[str] = None
    valor: Optional[float] = None
    tipo: Optional[str] = None


# ─── Helpers ───────────────────────────────────────────────────────────────────

def _oid(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail="ID inválido")


def _serializar(c: dict) -> dict:
    return {
        "id": str(c["_id"]),
        "codigo": c.get("codigo", ""),
        "tipo": c.get("tipo", "porcentaje"),
        "valor": c.get("valor", 0),
        "descripcion": c.get("descripcion", ""),
        "activo": c.get("activo", True),
        "usos_maximos": c.get("usos_maximos"),
        "usos_actuales": c.get("usos_actuales", 0),
        "fecha_inicio": c.get("fecha_inicio"),
        "fecha_fin": c.get("fecha_fin"),
    }


# ─── Endpoints ─────────────────────────────────────────────────────────────────
# Lectura permitida a cualquier usuario autenticado; mutación restringida a admins.

@router.get("", summary="Listar cupones")
def listar_cupones(
    solo_activos: bool = Query(False),
    _user: dict = Depends(get_current_user),
):
    filtro = {"activo": True} if solo_activos else {}
    cupones = list(coleccion_cupones.find(filtro).sort("_id", -1))
    return [_serializar(c) for c in cupones]


@router.get("/{cupon_id}", summary="Obtener un cupón por ID")
def obtener_cupon(cupon_id: str, _user: dict = Depends(get_current_user)):
    c = coleccion_cupones.find_one({"_id": _oid(cupon_id)})
    if not c:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    return _serializar(c)


@router.post("", summary="Crear cupón (admin)")
def crear_cupon(
    datos: CuponCrear,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    if coleccion_cupones.find_one({"codigo": datos.codigo}):
        raise HTTPException(status_code=409, detail=f"Ya existe un cupón con el código '{datos.codigo}'")
    nuevo = {
        "codigo": datos.codigo,
        "tipo": datos.tipo,
        "valor": datos.valor,
        "descripcion": datos.descripcion or "",
        "activo": True,
        "usos_maximos": datos.usos_maximos,
        "usos_actuales": 0,
        "fecha_inicio": datos.fecha_inicio,
        "fecha_fin": datos.fecha_fin,
    }
    resultado = coleccion_cupones.insert_one(nuevo)
    return _serializar({**nuevo, "_id": resultado.inserted_id})


@router.put("/{cupon_id}", summary="Editar cupón (admin)")
def editar_cupon(
    cupon_id: str,
    datos: CuponEditar,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(cupon_id)
    if not coleccion_cupones.find_one({"_id": oid}):
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    campos = {k: v for k, v in datos.model_dump().items() if v is not None}
    if not campos:
        raise HTTPException(status_code=400, detail="Ningún campo para actualizar")
    if "valor" in campos:
        campos["valor"] = round(campos["valor"], 2)
    coleccion_cupones.update_one({"_id": oid}, {"$set": campos})
    actualizado = coleccion_cupones.find_one({"_id": oid})
    return _serializar(actualizado)


@router.patch("/{cupon_id}/activo", summary="Activar/desactivar cupón (admin)")
def toggle_activo(
    cupon_id: str,
    activo: bool = Query(...),
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(cupon_id)
    resultado = coleccion_cupones.update_one({"_id": oid}, {"$set": {"activo": activo}})
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    return {"mensaje": "Cupón " + ("activado" if activo else "desactivado")}


@router.delete("/{cupon_id}", summary="Eliminar cupón (admin)")
def eliminar_cupon(
    cupon_id: str,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    resultado = coleccion_cupones.delete_one({"_id": _oid(cupon_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    return {"mensaje": "Cupón eliminado"}


@router.post("/{cupon_id}/usar", summary="Registrar uso del cupón")
def registrar_uso(cupon_id: str, _user: dict = Depends(get_current_user)):
    """Incrementa el contador de usos. Llámalo al aplicar el cupón en un pedido."""
    oid = _oid(cupon_id)
    # Operación atómica: sólo incrementa si está activo y aún no agotado.
    c = coleccion_cupones.find_one_and_update(
        {
            "_id": oid,
            "activo": True,
            "$expr": {
                "$or": [
                    {"$eq": [{"$ifNull": ["$usos_maximos", None]}, None]},
                    {"$lt": [{"$ifNull": ["$usos_actuales", 0]}, "$usos_maximos"]},
                ]
            },
        },
        {"$inc": {"usos_actuales": 1}},
        return_document=True,
    )
    if not c:
        # Diferenciar si no existe vs. si está agotado/inactivo
        existente = coleccion_cupones.find_one({"_id": oid})
        if not existente:
            raise HTTPException(status_code=404, detail="Cupón no encontrado")
        if not existente.get("activo", True):
            raise HTTPException(status_code=400, detail="El cupón está inactivo")
        raise HTTPException(status_code=400, detail="El cupón ha alcanzado el límite de usos")
    return {"mensaje": "Uso registrado", "usos_actuales": c.get("usos_actuales", 0)}
