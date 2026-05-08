"""Módulo de cierre de caja por turno.

Colección: cierres_caja
Roles:
  - GET: admin + super_admin
  - Mutaciones (abrir/cerrar/reabrir): solo admin
"""
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, field_validator

import audit_general as ag
from database import coleccion_cierres_caja, coleccion_pedidos
from exceptions import ConflictError, NotFoundError, ValidacionError
from security import normalizar_rol, require_role

logger = logging.getLogger("uvicorn")

router = APIRouter(prefix="/cierres-caja", tags=["Cierres de caja"])


# ── Constantes de turno ──────────────────────────────────────────────────────
# Cada turno: (hora_inicio "HH:MM", hora_fin "HH:MM", cruza_medianoche)
# Dos turnos: comida (mañana + mediodía) y cena (tarde + noche).
_TURNOS: dict[str, tuple[tuple[str, str], bool]] = {
    "comida": (("05:00", "16:59"), False),
    "cena":   (("17:00", "04:59"), True),   # la cena cruza medianoche
}

_TURNOS_VALIDOS = set(_TURNOS.keys())

# Estados de pedido que bloquean el cierre de caja
_ESTADOS_BLOQUEANTES = {"pendiente", "preparando", "listo"}

# Orden numérico para ordenar turnos en las consultas
_ORDEN_TURNO = {"comida": 0, "cena": 1}


# ── Helper de rango horario ──────────────────────────────────────────────────

def _rango_turno(fecha: str, turno: str) -> tuple[datetime, datetime]:
    """Devuelve (inicio, fin) en UTC naive para el turno en la fecha dada.

    Para la cena (cruza medianoche): el fin cae al día siguiente.
    La fecha recibida es YYYY-MM-DD y representa el día en que *empieza* el turno.
    """
    (hora_ini, hora_fin), cruza = _TURNOS[turno]
    try:
        base = datetime.fromisoformat(fecha)
    except ValueError:
        raise ValidacionError(f"Fecha inválida: '{fecha}'. Use YYYY-MM-DD.")

    h_ini, m_ini = map(int, hora_ini.split(":"))
    h_fin, m_fin = map(int, hora_fin.split(":"))

    inicio = base.replace(hour=h_ini, minute=m_ini, second=0, microsecond=0)
    fin_base = base.replace(hour=h_fin, minute=m_fin, second=59, microsecond=0)
    fin = fin_base + timedelta(days=1) if cruza else fin_base

    return inicio, fin


def _rango_a_iso(fecha: str, turno: str) -> tuple[str, str]:
    """Versión de _rango_turno que devuelve strings ISO 8601."""
    ini, fin = _rango_turno(fecha, turno)
    return ini.isoformat(), fin.isoformat()


# ── Serialización ────────────────────────────────────────────────────────────

def _serializar(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "restaurante_id": doc.get("restaurante_id"),
        "turno": doc.get("turno"),
        "fecha": doc.get("fecha"),
        "abierto_por": doc.get("abierto_por"),
        "abierto_at": doc.get("abierto_at"),
        "cerrado_por": doc.get("cerrado_por"),
        "cerrado_at": doc.get("cerrado_at"),
        "estado": doc.get("estado"),
        "efectivo_declarado": doc.get("efectivo_declarado"),
        "efectivo_sistema": doc.get("efectivo_sistema"),
        "descuadre": doc.get("descuadre"),
        "totales": doc.get("totales"),
        "reaperturas": doc.get("reaperturas", []),
    }


# ── Helpers de acceso ────────────────────────────────────────────────────────

def _restaurante_del_actor(actor: dict) -> Optional[str]:
    """Devuelve el restaurante_id del JWT. Para super_admin puede ser None."""
    return actor.get("restaurante_id")


def _resolver_cierre(cierre_id: str) -> dict:
    """Carga un cierre por id; lanza NotFoundError si no existe."""
    if not ObjectId.is_valid(cierre_id):
        raise ValidacionError("ID de cierre inválido")
    doc = coleccion_cierres_caja.find_one({"_id": ObjectId(cierre_id)})
    if not doc:
        raise NotFoundError("Cierre de caja no encontrado")
    return doc


def _verificar_propiedad(doc: dict, actor: dict) -> None:
    """Lanza 403 si el admin intenta operar sobre un cierre de otra sucursal."""
    rol = normalizar_rol(actor.get("rol", ""))
    if rol == "super_admin":
        return
    rid_actor = actor.get("restaurante_id")
    rid_cierre = doc.get("restaurante_id")
    if rid_actor and rid_cierre and rid_actor != rid_cierre:
        from exceptions import AutorizacionError
        raise AutorizacionError("No puedes operar cierres de otra sucursal")


# ── Modelos Pydantic ─────────────────────────────────────────────────────────

class AbrirCierreBody(BaseModel):
    turno: str
    fecha: Optional[str] = None   # YYYY-MM-DD; default = hoy en UTC

    @field_validator("turno")
    @classmethod
    def validar_turno(cls, v: str) -> str:
        v = v.strip().lower()
        if v not in _TURNOS_VALIDOS:
            raise ValueError(f"Turno inválido. Válidos: {sorted(_TURNOS_VALIDOS)}")
        return v

    @field_validator("fecha")
    @classmethod
    def validar_fecha(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        v = v.strip()
        try:
            datetime.fromisoformat(v)
        except ValueError:
            raise ValueError(f"Fecha inválida: '{v}'. Use YYYY-MM-DD.")
        if len(v) != 10:
            raise ValueError("La fecha debe tener formato YYYY-MM-DD.")
        return v


class CerrarCierreBody(BaseModel):
    efectivo_declarado: float

    @field_validator("efectivo_declarado")
    @classmethod
    def validar_efectivo(cls, v: float) -> float:
        if v < 0:
            raise ValueError("El efectivo declarado no puede ser negativo")
        return round(v, 2)


class ReabrirCierreBody(BaseModel):
    motivo: str

    @field_validator("motivo")
    @classmethod
    def validar_motivo(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 10:
            raise ValueError("El motivo debe tener al menos 10 caracteres")
        return v


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/abrir", summary="Abrir un turno de caja")
def abrir_cierre(
    body: AbrirCierreBody,
    actor: dict = Depends(require_role(["admin"])),
):
    """Abre un nuevo turno de caja para la sucursal del admin autenticado.

    - 409 si ya existe un turno abierto para esa sucursal+fecha+turno.
    - 409 si ya existe un turno cerrado (debe usarse /reabrir si es necesario).
    """
    rid = _restaurante_del_actor(actor)
    if not rid:
        raise ValidacionError("Tu sesión no tiene restaurante asignado")

    fecha = body.fecha or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Validar que el rango es construible (también valida la fecha)
    _rango_turno(fecha, body.turno)

    existente = coleccion_cierres_caja.find_one({
        "restaurante_id": rid,
        "fecha": fecha,
        "turno": body.turno,
    })
    if existente:
        if existente.get("estado") == "abierto":
            raise ConflictError("Ya hay un turno abierto para esta sucursal, fecha y turno")
        raise ConflictError("Este turno ya fue cerrado. Usa /reabrir si es necesario")

    ahora = datetime.now(timezone.utc).isoformat()
    doc = {
        "restaurante_id": rid,
        "turno": body.turno,
        "fecha": fecha,
        "abierto_por": actor.get("sub"),
        "abierto_at": ahora,
        "cerrado_por": None,
        "cerrado_at": None,
        "estado": "abierto",
        "efectivo_declarado": None,
        "efectivo_sistema": None,
        "descuadre": None,
        "totales": None,
        "reaperturas": [],
    }
    resultado = coleccion_cierres_caja.insert_one(doc)
    return _serializar({**doc, "_id": resultado.inserted_id})


@router.post("/{cierre_id}/cerrar", summary="Cerrar un turno de caja")
def cerrar_cierre(
    cierre_id: str,
    body: CerrarCierreBody,
    actor: dict = Depends(require_role(["admin"])),
):
    """Cierra un turno de caja.

    Bloquea el cierre si hay pedidos en estados pendiente/preparando/listo
    dentro del rango horario del turno. Calcula los totales como snapshot.
    """
    doc = _resolver_cierre(cierre_id)
    _verificar_propiedad(doc, actor)

    if doc.get("estado") != "abierto":
        raise ConflictError("Este cierre de caja ya está cerrado")

    fecha = doc["fecha"]
    turno = doc["turno"]
    iso_ini, iso_fin = _rango_a_iso(fecha, turno)
    rid = doc.get("restaurante_id")

    # Construir filtro base de pedidos del turno
    filtro_base: dict = {
        "fecha": {"$gte": iso_ini, "$lte": iso_fin},
    }
    if rid:
        filtro_base["restaurante_id"] = rid

    # Verificar pedidos bloqueantes
    filtro_bloqueantes = {**filtro_base, "estado": {"$in": list(_ESTADOS_BLOQUEANTES)}}
    n_bloqueantes = coleccion_pedidos.count_documents(filtro_bloqueantes)
    if n_bloqueantes > 0:
        raise ConflictError(
            f"No puedes cerrar: hay {n_bloqueantes} pedido(s) pendiente(s) en este turno"
        )

    # Calcular totales sobre pedidos en estado listo o entregado
    filtro_ventas = {**filtro_base, "estado": {"$in": ["listo", "entregado"]}}
    pedidos_venta = list(coleccion_pedidos.find(filtro_ventas))

    ventas_total = 0.0
    ventas_efectivo = 0.0
    ventas_tarjeta = 0.0
    ventas_otros = 0.0

    for p in pedidos_venta:
        total_p = float(p.get("total", 0))
        metodo = (p.get("metodo_pago") or "").lower()
        ventas_total += total_p
        if metodo == "efectivo":
            ventas_efectivo += total_p
        elif metodo == "tarjeta":
            ventas_tarjeta += total_p
        else:
            ventas_otros += total_p

    totales = {
        "ventas_total": round(ventas_total, 2),
        "ventas_efectivo": round(ventas_efectivo, 2),
        "ventas_tarjeta": round(ventas_tarjeta, 2),
        "ventas_otros": round(ventas_otros, 2),
        "pedidos_count": len(pedidos_venta),
    }

    efectivo_sistema = round(ventas_efectivo, 2)
    descuadre = round(body.efectivo_declarado - efectivo_sistema, 2)
    ahora = datetime.now(timezone.utc).isoformat()

    actualizacion = {
        "estado": "cerrado",
        "cerrado_por": actor.get("sub"),
        "cerrado_at": ahora,
        "efectivo_declarado": body.efectivo_declarado,
        "efectivo_sistema": efectivo_sistema,
        "descuadre": descuadre,
        "totales": totales,
    }
    coleccion_cierres_caja.update_one(
        {"_id": ObjectId(cierre_id)},
        {"$set": actualizacion},
    )

    actualizado = coleccion_cierres_caja.find_one({"_id": ObjectId(cierre_id)})
    return _serializar(actualizado)


@router.post("/{cierre_id}/reabrir", summary="Reabrir un cierre de caja")
def reabrir_cierre(
    cierre_id: str,
    body: ReabrirCierreBody,
    actor: dict = Depends(require_role(["admin"])),
):
    """Reabre un cierre cerrado. Conserva el snapshot histórico de totales.

    Añade una entrada al array 'reaperturas' y registra en auditoría.
    """
    doc = _resolver_cierre(cierre_id)
    _verificar_propiedad(doc, actor)

    if doc.get("estado") != "cerrado":
        raise ConflictError("Solo se puede reabrir un cierre que esté cerrado")

    ahora = datetime.now(timezone.utc).isoformat()
    entrada_reapertura = {
        "reabierto_por": actor.get("sub"),
        "reabierto_at": ahora,
        "motivo": body.motivo,
    }

    coleccion_cierres_caja.update_one(
        {"_id": ObjectId(cierre_id)},
        {
            "$set": {"estado": "abierto"},
            "$push": {"reaperturas": entrada_reapertura},
        },
    )

    ag.registrar(
        ag.CIERRE_REABIERTO,
        actor=actor.get("correo"),
        objetivo=cierre_id,
        detalle=body.motivo,
    )

    actualizado = coleccion_cierres_caja.find_one({"_id": ObjectId(cierre_id)})
    return _serializar(actualizado)


@router.get("/abierto-actual", summary="Cierre abierto del turno indicado para hoy")
def obtener_abierto_actual(
    turno: str = Query(...),
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Atajo para el panel: devuelve el cierre abierto del turno de hoy.

    - Admin: siempre usa su restaurante_id del JWT.
    - super_admin: puede pasar ?restaurante_id= en la query (no implementado
      en este helper; el super_admin debe usar GET /cierres-caja con filtros).
    """
    turno = turno.strip().lower()
    if turno not in _TURNOS_VALIDOS:
        raise ValidacionError(f"Turno inválido. Válidos: {sorted(_TURNOS_VALIDOS)}")

    rol = normalizar_rol(actor.get("rol", ""))
    rid = _restaurante_del_actor(actor)

    hoy = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    filtro: dict = {
        "turno": turno,
        "fecha": hoy,
        "estado": "abierto",
    }
    if rol != "super_admin" and rid:
        filtro["restaurante_id"] = rid
    elif rid:
        filtro["restaurante_id"] = rid

    doc = coleccion_cierres_caja.find_one(filtro)
    if not doc:
        raise NotFoundError("No hay turno abierto para ese turno hoy")

    return _serializar(doc)


@router.get("", summary="Listar cierres de caja")
def listar_cierres(
    fecha: Optional[str] = Query(None, description="Filtro por día YYYY-MM-DD"),
    turno: Optional[str] = Query(None, description="desayuno|comida|cena"),
    estado: Optional[str] = Query(None, description="abierto|cerrado"),
    fecha_desde: Optional[str] = Query(None, description="Rango desde YYYY-MM-DD"),
    fecha_hasta: Optional[str] = Query(None, description="Rango hasta YYYY-MM-DD"),
    restaurante_id: Optional[str] = Query(None, description="Solo super_admin"),
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Lista cierres de caja con filtros opcionales.

    - Admin: solo ve los de su sucursal (forzado por JWT).
    - super_admin: ve todos; puede filtrar con ?restaurante_id=.
    """
    rol = normalizar_rol(actor.get("rol", ""))

    filtro: dict = {}

    # Aislamiento por sucursal
    if rol == "super_admin":
        if restaurante_id:
            filtro["restaurante_id"] = restaurante_id
    else:
        rid = actor.get("restaurante_id")
        if rid:
            filtro["restaurante_id"] = rid

    # Filtros de contenido
    if turno:
        turno = turno.strip().lower()
        if turno not in _TURNOS_VALIDOS:
            raise ValidacionError(f"Turno inválido. Válidos: {sorted(_TURNOS_VALIDOS)}")
        filtro["turno"] = turno

    if estado:
        estado = estado.strip().lower()
        if estado not in {"abierto", "cerrado"}:
            raise ValidacionError("Estado inválido. Válidos: abierto, cerrado")
        filtro["estado"] = estado

    # Filtro temporal sobre el campo "fecha" (string YYYY-MM-DD)
    if fecha:
        fecha = fecha.strip()
        try:
            datetime.fromisoformat(fecha)
        except ValueError:
            raise ValidacionError(f"Fecha inválida: '{fecha}'. Use YYYY-MM-DD.")
        filtro["fecha"] = fecha
    else:
        rango: dict = {}
        if fecha_desde:
            fecha_desde = fecha_desde.strip()
            try:
                datetime.fromisoformat(fecha_desde)
            except ValueError:
                raise ValidacionError(f"fecha_desde inválida: '{fecha_desde}'.")
            rango["$gte"] = fecha_desde
        if fecha_hasta:
            fecha_hasta = fecha_hasta.strip()
            try:
                datetime.fromisoformat(fecha_hasta)
            except ValueError:
                raise ValidacionError(f"fecha_hasta inválida: '{fecha_hasta}'.")
            rango["$lte"] = fecha_hasta
        if rango:
            filtro["fecha"] = rango

    docs = list(coleccion_cierres_caja.find(filtro))

    # Ordenar por fecha desc, luego por turno asc (desayuno=0, comida=1, cena=2)
    docs.sort(key=lambda d: (d.get("fecha", ""), _ORDEN_TURNO.get(d.get("turno", ""), 99)), reverse=False)
    docs.sort(key=lambda d: d.get("fecha", ""), reverse=True)

    return [_serializar(d) for d in docs]


@router.get("/{cierre_id}", summary="Obtener un cierre de caja por ID")
def obtener_cierre(
    cierre_id: str,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Devuelve un cierre concreto con aislamiento por sucursal."""
    doc = _resolver_cierre(cierre_id)
    rol = normalizar_rol(actor.get("rol", ""))
    if rol != "super_admin":
        rid = actor.get("restaurante_id")
        if rid and doc.get("restaurante_id") and doc["restaurante_id"] != rid:
            raise NotFoundError("Cierre de caja no encontrado")
    return _serializar(doc)
