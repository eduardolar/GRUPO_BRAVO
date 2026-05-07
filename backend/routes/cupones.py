import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, field_validator
from bson import ObjectId
from bson.errors import InvalidId
from database import coleccion_cupones
from security import require_role, get_current_user, normalizar_rol
import audit_general as ag
import re

logger = logging.getLogger("uvicorn")

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
    # Sucursal propietaria del cupón. None = cupón global (válido en todas).
    # Si el actor es admin, este campo se ignora y se fuerza desde el JWT.
    restaurante_id: Optional[str] = None

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
        "restaurante_id": c.get("restaurante_id"),
    }


def _verificar_propiedad_cupon(cupon: dict, actor: dict) -> None:
    """Lanza 403 si el admin intenta tocar un cupón que no es de su sucursal.

    - Cupones globales (sin restaurante_id): ningún admin puede editarlos/eliminarlos;
      solo super_admin.
    - Cupones de sucursal: admin solo puede tocar los de su misma sucursal.
    """
    rol = normalizar_rol(actor.get("rol", ""))
    if rol == "super_admin":
        return  # super_admin libre

    rid_actor = actor.get("restaurante_id")
    rid_cupon = cupon.get("restaurante_id")

    if rid_cupon is None:
        # Cupón global: solo super_admin puede modificarlo
        raise HTTPException(
            status_code=403,
            detail="Los cupones globales solo pueden ser modificados por super_admin",
        )
    if rid_cupon != rid_actor:
        raise HTTPException(
            status_code=403,
            detail="No puedes modificar cupones de otra sucursal",
        )


# ─── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("", summary="Listar cupones")
def listar_cupones(
    solo_activos: bool = Query(False),
    actor: dict = Depends(get_current_user),
):
    """Lista cupones según el rol del actor.

    - Admin: ve cupones de su sucursal + cupones globales (restaurante_id=None).
    - super_admin: ve todos.
    - Cliente/camarero/cocinero: ve todos (ya que pueden canjear cualquier cupón
      válido en el momento de pedir; el filtrado de elegibilidad se hace en el
      endpoint /usar).
    """
    rol = normalizar_rol(actor.get("rol", ""))
    filtro: dict = {}
    if solo_activos:
        filtro["activo"] = True

    if rol == "admin":
        rid = actor.get("restaurante_id")
        if rid:
            # Ve los suyos + los globales
            filtro["$or"] = [
                {"restaurante_id": rid},
                {"restaurante_id": None},
                {"restaurante_id": {"$exists": False}},
            ]

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
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Crea un cupón.

    - Admin: el restaurante_id del body se ignora; se fuerza al del JWT.
    - super_admin: usa el restaurante_id del body; si es None crea un cupón global.
    """
    rol = normalizar_rol(actor.get("rol", ""))

    if rol == "admin":
        rid = actor.get("restaurante_id")
        if not rid:
            raise HTTPException(
                status_code=403,
                detail="Falta restaurante asignado en tu sesión",
            )
        restaurante_id_final = rid
    else:
        # super_admin: usa lo del body (puede ser None para cupón global)
        restaurante_id_final = datos.restaurante_id

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
        "restaurante_id": restaurante_id_final,
    }
    resultado = coleccion_cupones.insert_one(nuevo)
    ag.registrar(
        ag.CUPON_CREADO,
        actor=actor.get("correo"),
        objetivo=datos.codigo,
        detalle=f"Sucursal: {restaurante_id_final or 'global'}",
    )
    return _serializar({**nuevo, "_id": resultado.inserted_id})


@router.put("/{cupon_id}", summary="Editar cupón (admin)")
def editar_cupon(
    cupon_id: str,
    datos: CuponEditar,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(cupon_id)
    cupon = coleccion_cupones.find_one({"_id": oid})
    if not cupon:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")

    _verificar_propiedad_cupon(cupon, actor)

    campos = {k: v for k, v in datos.model_dump().items() if v is not None}
    if not campos:
        raise HTTPException(status_code=400, detail="Ningún campo para actualizar")
    if "valor" in campos:
        campos["valor"] = round(campos["valor"], 2)
    coleccion_cupones.update_one({"_id": oid}, {"$set": campos})
    ag.registrar(ag.CUPON_EDITADO, actor=actor.get("correo"), objetivo=cupon_id)
    actualizado = coleccion_cupones.find_one({"_id": oid})
    return _serializar(actualizado)


@router.patch("/{cupon_id}/activo", summary="Activar/desactivar cupón (admin)")
def toggle_activo(
    cupon_id: str,
    activo: bool = Query(...),
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(cupon_id)
    cupon = coleccion_cupones.find_one({"_id": oid})
    if not cupon:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")

    _verificar_propiedad_cupon(cupon, actor)

    coleccion_cupones.update_one({"_id": oid}, {"$set": {"activo": activo}})
    return {"mensaje": "Cupón " + ("activado" if activo else "desactivado")}


@router.delete("/{cupon_id}", summary="Eliminar cupón (admin)")
def eliminar_cupon(
    cupon_id: str,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(cupon_id)
    cupon = coleccion_cupones.find_one({"_id": oid})
    if not cupon:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")

    _verificar_propiedad_cupon(cupon, actor)

    coleccion_cupones.delete_one({"_id": oid})
    ag.registrar(ag.CUPON_ELIMINADO, actor=actor.get("correo"), objetivo=cupon_id)
    return {"mensaje": "Cupón eliminado"}


@router.post("/{cupon_id}/usar", summary="Registrar uso del cupón")
def registrar_uso(cupon_id: str, _user: dict = Depends(get_current_user)):
    """Incrementa el contador de usos. Llámalo al aplicar el cupón en un pedido.
    Cualquier usuario autenticado puede canjear cupones de cualquier sucursal."""
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
        existente = coleccion_cupones.find_one({"_id": oid})
        if not existente:
            raise HTTPException(status_code=404, detail="Cupón no encontrado")
        if not existente.get("activo", True):
            raise HTTPException(status_code=400, detail="El cupón está inactivo")
        raise HTTPException(status_code=400, detail="El cupón ha alcanzado el límite de usos")
    return {"mensaje": "Uso registrado", "usos_actuales": c.get("usos_actuales", 0)}
