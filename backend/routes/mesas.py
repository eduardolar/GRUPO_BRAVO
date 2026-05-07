import logging
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from database import coleccion_mesas
from models import MesaActualizar, ValidarQR
from security import get_current_user, normalizar_rol, require_role

logger = logging.getLogger("uvicorn")


class ActualizarEstadoMesa(BaseModel):
    disponible: bool


class CrearMesa(BaseModel):
    numero: int
    capacidad: int
    ubicacion: str = "interior"
    codigoQr: str
    # Sucursal a la que pertenece la mesa. Si el admin no la manda, el
    # backend la rellena con la sucursal del JWT (no super admin).
    restauranteId: Optional[str] = None


router = APIRouter(prefix="/mesas", tags=["Mesas"])


def _serializar(m: dict) -> dict:
    return {
        "id": str(m["_id"]),
        "numero": m.get("numero", 0),
        "capacidad": m.get("capacidad", 0),
        "ubicacion": m.get("ubicacion", "interior"),
        "disponible": m.get("estado", "libre") == "libre",
        "codigoQr": m.get("codigoQr", m.get("codigo_qr", f"mesa_{m.get('numero', 0)}")),
        "restauranteId": m.get("restaurante_id"),
        "restaurante_id": m.get("restaurante_id"),
    }


@router.get("", summary="Listar mesas (filtra por restaurante_id si se pasa)")
def obtener_mesas(
    restaurante_id: Optional[str] = Query(None),
    restauranteId: Optional[str] = Query(None),
    _user: dict = Depends(get_current_user),
):
    rid = restaurante_id or restauranteId
    filtro = {"restaurante_id": rid} if rid else {}
    return [_serializar(m) for m in coleccion_mesas.find(filtro)]


@router.post("", summary="Crear mesa (admin)")
def crear_mesa(
    datos: CrearMesa,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    # Sucursal: usar la del payload, y si no, la del JWT del admin (no super).
    rid = datos.restauranteId
    if not rid:
        rol = normalizar_rol(usuario.get("rol", "") or "")
        if rol != "super_admin":
            rid = usuario.get("restaurante_id") or usuario.get("restauranteId")

    # Unicidad por sucursal (no global): "Mesa 1" puede existir en cada
    # sucursal sin colisionar.
    filtro_numero: dict = {"numero": datos.numero}
    filtro_qr: dict = {
        "$or": [{"codigoQr": datos.codigoQr}, {"codigo_qr": datos.codigoQr}]
    }
    if rid:
        filtro_numero["restaurante_id"] = rid
        filtro_qr["restaurante_id"] = rid

    if coleccion_mesas.find_one(filtro_numero):
        raise HTTPException(
            status_code=409,
            detail="Ya existe una mesa con ese número en esta sucursal",
        )
    if coleccion_mesas.find_one(filtro_qr):
        raise HTTPException(
            status_code=409, detail="El código QR ya está en uso en esta sucursal"
        )

    nueva: dict = {
        "numero": datos.numero,
        "capacidad": datos.capacidad,
        "ubicacion": datos.ubicacion,
        "codigoQr": datos.codigoQr,
        "estado": "libre",
    }
    if rid:
        nueva["restaurante_id"] = rid

    result = coleccion_mesas.insert_one(nueva)
    return _serializar({**nueva, "_id": result.inserted_id})


@router.patch("/{mesa_id}", summary="Cambiar estado libre/ocupada (admin)")
def actualizar_estado_mesa(
    mesa_id: str,
    datos: ActualizarEstadoMesa,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    try:
        object_id = ObjectId(mesa_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    mesa = coleccion_mesas.find_one({"_id": object_id})
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")

    # Aislamiento: un admin no puede tocar mesas de otra sucursal.
    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol != "super_admin":
        rid_user = usuario.get("restaurante_id") or usuario.get("restauranteId")
        rid_mesa = mesa.get("restaurante_id")
        if rid_mesa and rid_user and rid_mesa != rid_user:
            raise HTTPException(status_code=403, detail="Mesa de otra sucursal")

    nuevo_estado = "libre" if datos.disponible else "ocupada"
    coleccion_mesas.update_one({"_id": object_id}, {"$set": {"estado": nuevo_estado}})
    return {"ok": True, "estado": nuevo_estado}


def _exigir_misma_sucursal_mesa(mesa: dict, usuario: dict) -> None:
    """Un admin de sucursal X no puede editar mesas de la sucursal Y.
    Los super_admin sí pueden — el chequeo se salta para ellos.
    Si el JWT no lleva restaurante_id (cuenta legacy), no se aplica restricción
    pero se deja traza de aviso para auditarla.
    """
    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol == "super_admin":
        return
    rid_user = usuario.get("restaurante_id") or usuario.get("restauranteId")
    rid_mesa = mesa.get("restaurante_id")
    if not rid_user:
        # JWT legacy sin sucursal: permitimos con aviso
        logger.warning(
            "mesas PUT: usuario sin restaurante_id en JWT (rol=%s sub=%s). "
            "No se aplica restricción por sucursal.",
            rol,
            usuario.get("sub"),
        )
        return
    if rid_mesa and rid_mesa != rid_user:
        raise HTTPException(status_code=403, detail="Mesa de otra sucursal")


@router.put("/{mesa_id}", summary="Editar datos de una mesa (admin)")
def editar_mesa(
    mesa_id: str,
    datos: MesaActualizar,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Actualiza numero, capacidad, ubicacion y/o codigoQr de una mesa existente.
    Solo los campos presentes en el body (no null) se modifican en BD.
    """
    try:
        oid = ObjectId(mesa_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    mesa = coleccion_mesas.find_one({"_id": oid})
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")

    # Aislamiento por sucursal — super_admin está exento
    _exigir_misma_sucursal_mesa(mesa, usuario)

    # Resolver el valor efectivo de codigoQr (camelCase tiene precedencia)
    qr_nuevo = datos.codigoQr or datos.codigo_qr

    # Construir solo los campos que llegaron con valor no-null
    campos: dict = {}
    if datos.numero is not None:
        campos["numero"] = datos.numero
    if datos.capacidad is not None:
        campos["capacidad"] = datos.capacidad
    if datos.ubicacion is not None:
        campos["ubicacion"] = datos.ubicacion
    if qr_nuevo is not None:
        campos["codigoQr"] = qr_nuevo

    if not campos:
        raise HTTPException(status_code=400, detail="Sin campos para actualizar")

    rid_mesa = mesa.get("restaurante_id")

    # Validar unicidad de numero en la misma sucursal (excluir la propia mesa)
    if "numero" in campos:
        filtro_num: dict = {"numero": campos["numero"], "_id": {"$ne": oid}}
        if rid_mesa:
            filtro_num["restaurante_id"] = rid_mesa
        if coleccion_mesas.find_one(filtro_num):
            raise HTTPException(
                status_code=409,
                detail="Ya existe una mesa con ese número en esta sucursal",
            )

    # Validar unicidad global de codigoQr (cross-sucursal; excluir la propia)
    if "codigoQr" in campos:
        filtro_qr: dict = {
            "$or": [{"codigoQr": campos["codigoQr"]}, {"codigo_qr": campos["codigoQr"]}],
            "_id": {"$ne": oid},
        }
        if coleccion_mesas.find_one(filtro_qr):
            raise HTTPException(
                status_code=409,
                detail="El código QR ya está en uso",
            )

    coleccion_mesas.update_one({"_id": oid}, {"$set": campos})
    mesa_actualizada = coleccion_mesas.find_one({"_id": oid})
    return _serializar(mesa_actualizada)


@router.delete("/{mesa_id}", summary="Eliminar mesa (admin)")
def eliminar_mesa(
    mesa_id: str,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    try:
        object_id = ObjectId(mesa_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    mesa = coleccion_mesas.find_one({"_id": object_id})
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")

    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol != "super_admin":
        rid_user = usuario.get("restaurante_id") or usuario.get("restauranteId")
        rid_mesa = mesa.get("restaurante_id")
        if rid_mesa and rid_user and rid_mesa != rid_user:
            raise HTTPException(status_code=403, detail="Mesa de otra sucursal")

    coleccion_mesas.delete_one({"_id": object_id})
    return {"ok": True, "mensaje": "Mesa eliminada"}


@router.post("/validar-qr", summary="Resolver mesaId desde un QR escaneado")
def validar_qr_mesa(datos: ValidarQR):
    mesa = coleccion_mesas.find_one(
        {"codigoQr": datos.codigoQr}
    ) or coleccion_mesas.find_one({"codigo_qr": datos.codigoQr})
    if not mesa:
        try:
            numero = int(
                datos.codigoQr.replace("mesa_", "").replace("Mesa_", "")
            )
            mesa = coleccion_mesas.find_one({"numero": numero})
        except ValueError:
            pass
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")
    return {
        "mesaId": str(mesa["_id"]),
        "numeroMesa": mesa.get("numero", 0),
        "estado": "disponible" if mesa.get("estado", "libre") == "libre" else "ocupada",
        "restauranteId": mesa.get("restaurante_id"),
    }
