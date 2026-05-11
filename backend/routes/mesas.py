import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel

from database import coleccion_mesas
from models import MesaActualizar, ValidarQR
from security import get_current_user, normalizar_rol, require_role
from limiter import limiter
import audit_general as ag

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
    estado = m.get("estado", "libre")
    return {
        "id": str(m["_id"]),
        "numero": m.get("numero", 0),
        "capacidad": m.get("capacidad", 0),
        "ubicacion": m.get("ubicacion", "interior"),
        # `disponible` queda como bool retrocompatible: solo true si está
        # libre (no en uso ni pendiente de limpiar). El estado completo va
        # en el nuevo campo `estado`.
        "disponible": estado == "libre",
        "estado": estado,
        "codigoQr": m.get("codigoQr", m.get("codigo_qr", f"mesa_{m.get('numero', 0)}")),
        "restauranteId": m.get("restaurante_id"),
        "restaurante_id": m.get("restaurante_id"),
    }


@router.get("", summary="Listar mesas (filtra por restaurante_id si se pasa)")
def obtener_mesas(
    restaurante_id: Optional[str] = Query(None),
    restauranteId: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """Devuelve la lista de mesas.

    Aislamiento multi-tenant:
    - super_admin puede usar el query-param restaurante_id para cruzar sucursales.
    - El resto del personal (admin, camarero, cocinero, etc.) siempre ve solo las
      mesas de SU sucursal del JWT; el query-param se ignora para evitar IDOR.
    - Si el usuario de personal no tiene restaurante_id en el JWT → 400.
    - Los clientes no deberían usar este endpoint (usan validar-qr), pero si
      llegaran se aplica la misma lógica restrictiva.
    """
    rol = normalizar_rol(current_user.get("rol", "") or "")

    if rol == "super_admin":
        # super_admin puede cruzar sucursales usando el query param
        rid = restaurante_id or restauranteId
    else:
        # Personal: ignoramos el query y forzamos el JWT
        rid = current_user.get("restaurante_id")
        if not rid:
            raise HTTPException(
                status_code=400,
                detail="Tu cuenta no está asignada a una sucursal",
            )

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


@router.patch("/{mesa_id}", summary="Cambiar estado libre/ocupada (admin/camarero)")
@limiter.limit("60/minute")
def actualizar_estado_mesa(
    request: Request,
    mesa_id: str,
    datos: ActualizarEstadoMesa,
    usuario: dict = Depends(require_role(["admin", "super_admin", "camarero", "trabajador"])),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    """Cambia el estado libre/ocupada de una mesa.

    Acepta el header opcional `Idempotency-Key`. Si la misma clave llega
    dentro de un margen de 30 segundos, devuelve el estado actual sin
    aplicar el cambio (protección contra doble tap).
    """
    try:
        object_id = ObjectId(mesa_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    mesa = coleccion_mesas.find_one({"_id": object_id})
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")

    # ── Idempotency-Key: protección contra doble tap ──────────────────────────
    if idempotency_key and idempotency_key.strip():
        ik = idempotency_key.strip()
        ultima_ik = mesa.get("ultima_idempotency_key")
        ultima_at_raw = mesa.get("ultima_idempotency_at")
        if ultima_ik == ik and ultima_at_raw:
            try:
                ultima_at = datetime.fromisoformat(ultima_at_raw)
                if ultima_at.tzinfo is None:
                    ultima_at = ultima_at.replace(tzinfo=timezone.utc)
                diferencia = datetime.now(timezone.utc) - ultima_at
                if diferencia <= timedelta(seconds=30):
                    # Misma clave en < 30 s → devolver estado actual sin modificar
                    return {"ok": True, "estado": mesa.get("estado", "libre"), "idempotent": True}
            except (ValueError, TypeError):
                pass  # fecha corrupta: dejamos pasar el cambio normal

    # Aislamiento por sucursal: super_admin tiene acceso global; admin y
    # camarero/trabajador solo pueden tocar mesas de su propia sucursal.
    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol != "super_admin":
        rid_user = usuario.get("restaurante_id") or usuario.get("restauranteId")
        rid_mesa = mesa.get("restaurante_id")
        if rid_mesa and rid_user and rid_mesa != rid_user:
            raise HTTPException(
                status_code=403,
                detail="No puedes modificar mesas de otra sucursal",
            )

    nuevo_estado = "libre" if datos.disponible else "ocupada"
    set_fields: dict = {"estado": nuevo_estado}

    # Persistir la idempotency key para detectar duplicados futuros
    if idempotency_key and idempotency_key.strip():
        set_fields["ultima_idempotency_key"] = idempotency_key.strip()
        set_fields["ultima_idempotency_at"] = datetime.now(timezone.utc).isoformat()

    coleccion_mesas.update_one({"_id": object_id}, {"$set": set_fields})

    ag.registrar(
        ag.MESA_ESTADO_CAMBIADO,
        actor=usuario.get("correo"),
        objetivo=str(object_id),
        detalle=f"estado={nuevo_estado}",
        extra={"restaurante_id": mesa.get("restaurante_id")},
    )
    return {"ok": True, "estado": nuevo_estado}


@router.post(
    "/{mesa_id}/marcar-por-limpiar",
    summary="Marcar una mesa como pendiente de limpieza tras cobrar",
)
def marcar_mesa_por_limpiar(
    mesa_id: str,
    usuario: dict = Depends(
        require_role(["admin", "super_admin", "camarero", "trabajador"]),
    ),
):
    """Estado intermedio entre 'ocupada' y 'libre' — el cliente se ha ido,
    el camarero cobró, pero la mesa aún hay que limpiarla. Mientras, la
    mesa NO se puede ocupar."""
    try:
        object_id = ObjectId(mesa_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    mesa = coleccion_mesas.find_one({"_id": object_id})
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")
    _exigir_misma_sucursal_mesa(mesa, usuario)

    coleccion_mesas.update_one(
        {"_id": object_id}, {"$set": {"estado": "por_limpiar"}},
    )
    ag.registrar(
        ag.MESA_ESTADO_CAMBIADO,
        actor=usuario.get("correo"),
        objetivo=str(object_id),
        detalle="estado=por_limpiar",
        extra={"restaurante_id": mesa.get("restaurante_id")},
    )
    return {"ok": True, "estado": "por_limpiar"}


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
