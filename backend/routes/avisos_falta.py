"""Avisos de falta de ingrediente creados por el trabajador.

El trabajador (camarero) crea un aviso cuando detecta que falta un
ingrediente; el admin lo marca como atendido una vez resuelto.
"""
from datetime import datetime, timezone
from typing import Optional

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from database import coleccion_avisos_falta
from security import get_current_user, normalizar_rol, require_role

router = APIRouter(prefix="/avisos-falta", tags=["Avisos de falta"])


# ─── Modelos ─────────────────────────────────────────────────────────────────

class AvisoFaltaCrear(BaseModel):
    ingredienteId: Optional[str] = None
    ingredienteNombre: str
    notas: Optional[str] = None


class AvisoFaltaAtender(BaseModel):
    estado: str  # "atendido"
    notas_admin: Optional[str] = None


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _oid(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail="ID inválido")


def _serializar(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "restaurante_id": doc.get("restaurante_id"),
        "ingrediente_id": doc.get("ingrediente_id"),
        "ingrediente_nombre": doc.get("ingrediente_nombre"),
        "notas": doc.get("notas"),
        "creado_por_sub": doc.get("creado_por_sub"),
        "creado_por_correo": doc.get("creado_por_correo"),
        "creado_por_rol": doc.get("creado_por_rol"),
        "creado_at": doc.get("creado_at"),
        "estado": doc.get("estado", "pendiente"),
        "notas_admin": doc.get("notas_admin"),
        "atendido_por_sub": doc.get("atendido_por_sub"),
        "atendido_at": doc.get("atendido_at"),
    }


# ─── Endpoints ───────────────────────────────────────────────────────────────

@router.post("", summary="Crear aviso de falta de ingrediente (camarero/admin/super_admin)")
def crear_aviso_falta(
    payload: AvisoFaltaCrear,
    usuario: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """Persiste un aviso de falta de ingrediente con los metadatos del actor."""
    doc = {
        "restaurante_id": usuario.get("restaurante_id"),
        "ingrediente_id": payload.ingredienteId,
        "ingrediente_nombre": payload.ingredienteNombre,
        "notas": payload.notas,
        "creado_por_sub": usuario.get("sub"),
        "creado_por_correo": usuario.get("correo"),
        "creado_por_rol": normalizar_rol(usuario.get("rol", "") or ""),
        "creado_at": datetime.now(timezone.utc).isoformat(),
        "estado": "pendiente",
    }
    resultado = coleccion_avisos_falta.insert_one(doc)
    return {"id": str(resultado.inserted_id), "mensaje": "Aviso creado"}


@router.get("", summary="Listar avisos de falta (camarero/admin/super_admin)")
def listar_avisos_falta(
    estado: Optional[str] = Query(None, pattern="^(pendiente|atendido)$"),
    restaurante_id: Optional[str] = Query(None),
    usuario: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """Lista avisos de falta de ingredientes ordenados por creado_at descendente.

    - super_admin puede filtrar por cualquier restaurante_id vía query.
    - admin y camarero solo ven avisos de su propia sucursal (JWT).
    """
    rol = normalizar_rol(usuario.get("rol", "") or "")

    if rol == "super_admin":
        rid_efectivo = restaurante_id
    else:
        rid_efectivo = usuario.get("restaurante_id")

    filtro: dict = {}
    if rid_efectivo:
        filtro["restaurante_id"] = rid_efectivo
    if estado:
        filtro["estado"] = estado

    docs = list(coleccion_avisos_falta.find(filtro).sort("creado_at", -1))
    return [_serializar(d) for d in docs]


@router.patch("/{aviso_id}", summary="Marcar aviso como atendido (admin/super_admin)")
def atender_aviso_falta(
    aviso_id: str,
    payload: AvisoFaltaAtender,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Marca un aviso como atendido con aislamiento por sucursal."""
    if payload.estado != "atendido":
        raise HTTPException(status_code=400, detail="El único estado válido es 'atendido'")

    oid = _oid(aviso_id)
    aviso = coleccion_avisos_falta.find_one({"_id": oid})
    if not aviso:
        raise HTTPException(status_code=404, detail="Aviso no encontrado")

    # Aislamiento por sucursal
    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol != "super_admin":
        rid_user = usuario.get("restaurante_id")
        rid_aviso = aviso.get("restaurante_id")
        if rid_aviso and rid_user and rid_aviso != rid_user:
            raise HTTPException(status_code=403, detail="No puedes atender avisos de otra sucursal")

    campos = {
        "estado": "atendido",
        "atendido_por_sub": usuario.get("sub"),
        "atendido_at": datetime.now(timezone.utc).isoformat(),
    }
    if payload.notas_admin is not None:
        campos["notas_admin"] = payload.notas_admin

    coleccion_avisos_falta.update_one({"_id": oid}, {"$set": campos})
    aviso_actualizado = coleccion_avisos_falta.find_one({"_id": oid})
    return _serializar(aviso_actualizado)
