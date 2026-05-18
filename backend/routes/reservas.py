# ============================================================================
# backend/routes/reservas.py
# ----------------------------------------------------------------------------
# Reservas de mesa.
#
# Modelo de estados:
#   Pendiente  → recién creada, espera confirmación del local.
#   Confirmada → aceptada por el restaurante.
#   Llegado    → el cliente ya está sentado en la mesa.
#   NoShow     → no se presentó (útil para penalizar reservas reincidentes).
#   Cancelada  → cancelada por cliente o restaurante.
#
# Reglas de autorización:
#   - El cliente solo puede reservar PARA SÍ MISMO: el backend pisa el
#     `usuarioId` con el `sub` del JWT si el actor es cliente. Así nadie
#     puede reservar suplantando a otro usuario.
#   - Camarero/admin pueden crear reservas "walk-in" para alguien sin
#     cuenta y por eso aceptan teléfono/correo del cliente real.
#   - Cambios de estado: solo empleados; el cliente solo cancela.
#
# Cada reserva ocupa la mesa durante `DURACION_RESERVA_MIN` minutos (90).
# Para evitar solape, los queries de disponibilidad buscan reservas en
# ese rango de tiempo, no en horarios exactos.
# ============================================================================
import logging
from datetime import date, datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from bson import ObjectId
from pymongo.errors import DuplicateKeyError
from database import coleccion_reservas, coleccion_mesas, coleccion_restaurantes
from models import ReservaCrear
from security import get_current_user, require_role, normalizar_rol
import audit_general as ag

logger = logging.getLogger("uvicorn")

router = APIRouter(prefix="/reservas", tags=["Reservas"])

# Cuánto tiempo ocupa una reserva la mesa. Si crece, hay menos huecos
# disponibles a lo largo del día. Ajustable por configuración futura.
DURACION_RESERVA_MIN = 90

# Estados válidos para una reserva. Se valida al cambiar de estado.
_ESTADOS_VALIDOS = {"Confirmada", "Cancelada", "Pendiente", "Llegado", "NoShow"}


# ─── Modelos de entrada para endpoints nuevos ──────────────────────────────────

class CambioEstadoBody(BaseModel):
    estado: str

class AsignarMesaBody(BaseModel):
    mesaId: str


class ReservaActualizar(BaseModel):
    """Body validado para PUT /reservas/{id}.

    Todos los campos son opcionales (parche parcial). El backend re-aplica
    las mismas validaciones que en `crear_reserva` para los que cambian:
    formato, rangos, horario del restaurante, disponibilidad de mesa.
    """
    fecha: Optional[str] = None
    hora: Optional[str] = None
    comensales: Optional[int] = Field(default=None, ge=1, le=20)
    turno: Optional[str] = None
    notas: Optional[str] = None
    estado: Optional[str] = None


class ActualizarComensalesBody(BaseModel):
    """Body para PATCH /reservas/{id} — solo edita comensales."""
    comensales: int = Field(ge=1, le=20)


# ─── Helpers ──────────────────────────────────────────────────────────────────

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

def reservas_activas_por_mesa(
        restaurante_id: str | None = None,
        fecha: str | None = None,
        hora: str | None = None,
    ) -> dict:
        ahora = datetime.now()
        fecha = fecha or ahora.strftime("%Y-%m-%d")
        hora = hora or ahora.strftime("%H:%M")

        filtro: dict = {
            "fecha": fecha,
            "estado": {"$in": ["Confirmada", "Llegado"]},
        }

        if restaurante_id:
            filtro["restaurante_id"] = restaurante_id

        activas: dict = {}

        for r in coleccion_reservas.find(filtro):
            mesa_id = r.get("mesa_id")
            hora_r = r.get("hora")

            if not mesa_id or not hora_r:
                continue

            if _hay_conflicto_horario(hora_r, hora):
                activas[str(mesa_id)] = {
                    "hora": hora_r,
                    "nombre": r.get("nombre_completo", ""),
                    "estado": r.get("estado", "Confirmada"),
                }

        return activas



def _serializar_reserva(r: dict) -> dict:
    """Devuelve una reserva normalizada. Rellena numeroMesa si falta."""
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
        "restauranteId": r.get("restaurante_id"),
    }
    if item["numeroMesa"] is None and r.get("mesa_id"):
        try:
            mesa = coleccion_mesas.find_one({"_id": ObjectId(r["mesa_id"])})
            item["numeroMesa"] = mesa.get("numero", 0) if mesa else None
        except Exception:
            logger.warning(
                "No se pudo obtener número de mesa para mesa_id=%s", r.get("mesa_id")
            )
            item["numeroMesa"] = None
    return item


def _rid_actor(actor: dict) -> Optional[str]:
    """Devuelve el restaurante_id del JWT del actor, o None si es super_admin."""
    return actor.get("restaurante_id")


# ─── Endpoints públicos (sin auth) ────────────────────────────────────────────

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


# ─── Endpoints de panel admin (rutas literales ANTES de /{reserva_id}) ────────

@router.get("/futuras")
def obtener_reservas_futuras(
    restauranteId: str | None = Query(None),
    restaurante_id: str | None = Query(None),
    actor: dict = Depends(get_current_user),
):
    """Devuelve todas las reservas desde hoy en adelante.

    Para roles de administración aplica aislamiento por sucursal igual que el
    resto de endpoints. El cliente no puede usar este endpoint (requiere auth
    y su rol no es admin/camarero/super_admin; aun así si lo llamara solo vería
    su sucursal porque hemos exigido get_current_user).
    """
    rol = normalizar_rol(actor.get("rol", ""))
    hoy = date.today().strftime("%Y-%m-%d")
    filtro: dict = {"fecha": {"$gte": hoy}}

    rid = restauranteId or restaurante_id
    if rol == "super_admin":
        if rid:
            filtro["restaurante_id"] = rid
    else:
        # Fuerza la sucursal del JWT
        jwt_rid = actor.get("restaurante_id")
        if jwt_rid:
            filtro["restaurante_id"] = jwt_rid
        elif rid:
            filtro["restaurante_id"] = rid

    reservas = coleccion_reservas.find(filtro)
    return [_serializar_reserva(r) for r in reservas]


@router.get("/admin", summary="Panel admin — listar reservas por fecha/estado")
def listar_reservas_admin(
    fecha: Optional[str] = Query(None, description="Filtro YYYY-MM-DD"),
    estado: Optional[str] = Query(None, description="Confirmada|Cancelada|Pendiente|Llegado|NoShow"),
    restaurante_id: Optional[str] = Query(None, description="Solo super_admin: filtrar por sucursal"),
    actor: dict = Depends(require_role(["admin", "camarero", "super_admin"])),
):
    """Lista reservas para el panel de administración.

    - Admin/camarero: solo ve reservas de su sucursal (forzado por JWT).
    - super_admin sin restaurante_id: ve todas las sucursales.
    - super_admin con ?restaurante_id=: ve solo esa sucursal.
    Ordena por fecha+hora ascendente.
    """
    rol = normalizar_rol(actor.get("rol", ""))
    filtro: dict = {}

    if rol == "super_admin":
        # super_admin: respeta el query param si viene; si no, ve todo
        if restaurante_id:
            filtro["restaurante_id"] = restaurante_id
    else:
        # Admin/camarero: siempre forzado al restaurante_id del JWT
        rid = actor.get("restaurante_id")
        if rid:
            filtro["restaurante_id"] = rid

    if fecha:
        filtro["fecha"] = fecha
    if estado:
        if estado not in _ESTADOS_VALIDOS:
            raise HTTPException(status_code=400, detail=f"Estado inválido: {estado}")
        filtro["estado"] = estado

    reservas = list(
        coleccion_reservas.find(filtro).sort([("fecha", 1), ("hora", 1)])
    )
    return [_serializar_reserva(r) for r in reservas]


# ─── GET de reservas de usuario ───────────────────────────────────────────────

@router.get("")
def obtener_reservas(
    usuarioId: str = Query(...),
    actor: dict = Depends(get_current_user),
):
    """Lista reservas de un usuario.

    - Si el actor es cliente: se ignora el `usuarioId` del query y se fuerza
      al `sub` del JWT (no puede ver reservas de otros usuarios).
    - Roles de staff (admin, camarero, cocinero, super_admin): puede pasar
      cualquier `usuarioId`. Los no super_admin están restringidos a su sucursal.
    """
    rol = normalizar_rol(actor.get("rol", ""))

    if rol == "cliente":
        # Forzar al propio usuario
        filtro = {"usuario_id": actor.get("sub", usuarioId)}
    else:
        filtro: dict = {"usuario_id": usuarioId}
        # Aislamiento por sucursal para staff no super_admin
        if rol != "super_admin":
            rid = actor.get("restaurante_id")
            if rid:
                filtro["restaurante_id"] = rid

    reservas = coleccion_reservas.find(filtro)
    return [_serializar_reserva(r) for r in reservas]


# ─── POST crear reserva ────────────────────────────────────────────────────────

@router.post("")
def crear_reserva(
    reserva: ReservaCrear,
    actor: dict = Depends(get_current_user),
):
    """Crea una reserva.

    - Cliente: puede crear su propia reserva. El usuarioId se fuerza al sub del JWT.
    - Camarero/admin: puede crear "en nombre de" pasando un usuarioId distinto.
      Si el actor es admin, el restauranteId se fuerza al de su JWT.
    """
    rol = normalizar_rol(actor.get("rol", ""))

    # Forzar usuario para clientes
    usuario_id_final = reserva.usuarioId
    if rol == "cliente":
        usuario_id_final = actor.get("sub", reserva.usuarioId)

    # Forzar restaurante para admin/camarero
    restaurante_id_final = reserva.restauranteId
    if rol in {"admin", "camarero"}:
        rid_jwt = actor.get("restaurante_id")
        if rid_jwt:
            restaurante_id_final = rid_jwt

    # Datos del cliente real cuando el actor es staff (camarero/admin)
    # Si el actor es cliente, estos campos se ignoran: el cliente solo se reserva a sí mismo.
    telefono_cliente_final: Optional[str] = None
    correo_cliente_final: Optional[str] = None
    creado_por_actor: Optional[dict] = None
    if rol in {"camarero", "admin", "super_admin"}:
        telefono_cliente_final = reserva.telefonoCliente
        correo_cliente_final = reserva.correoCliente
        creado_por_actor = {
            "sub": actor.get("sub"),
            "correo": actor.get("correo"),
            "rol": rol,
        }

    # Validar horario del restaurante usando horarios_dia
    if restaurante_id_final:
        try:
            rest = coleccion_restaurantes.find_one({"_id": ObjectId(restaurante_id_final)})
        except Exception:
            rest = None
        if rest:
            horarios_dia = rest.get("horarios_dia")
            if horarios_dia:
                _DIAS_ES = [
                    "lunes", "martes", "miercoles", "jueves",
                    "viernes", "sabado", "domingo",
                ]
                try:
                    fecha_dt = date.fromisoformat(reserva.fecha)
                    dia_key = _DIAS_ES[fecha_dt.weekday()]
                except (ValueError, IndexError):
                    dia_key = None
                if dia_key:
                    entrada_dia = horarios_dia.get(dia_key, {})
                    abierto_raw = entrada_dia.get("abierto", True)
                    if isinstance(abierto_raw, str):
                        abierto = abierto_raw.lower() not in ("false", "0", "no")
                    else:
                        abierto = bool(abierto_raw)
                    if not abierto:
                        raise HTTPException(
                            status_code=400,
                            detail=f"El restaurante está cerrado el {dia_key}",
                        )
                    apertura = entrada_dia.get("apertura")
                    cierre = entrada_dia.get("cierre")
                    if apertura and cierre:
                        if not _hora_en_rango(reserva.hora, apertura, cierre):
                            raise HTTPException(
                                status_code=400,
                                detail=(
                                    f"El restaurante no acepta reservas a las {reserva.hora}. "
                                    f"Horario del {dia_key}: {apertura} – {cierre}"
                                ),
                            )

    ocupadas = _mesas_ocupadas_por_hora(reserva.fecha, reserva.hora, restaurante_id_final)

    if reserva.mesaId:
        mesa = coleccion_mesas.find_one({"_id": ObjectId(reserva.mesaId)})
        if not mesa:
            raise HTTPException(status_code=404, detail="Mesa no encontrada")
        if restaurante_id_final:
            rid_mesa = mesa.get("restaurante_id")
            if rid_mesa and rid_mesa != restaurante_id_final:
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
        filtro_candidatas: dict = {"capacidad": {"$gte": reserva.comensales}}
        if restaurante_id_final:
            filtro_candidatas["restaurante_id"] = restaurante_id_final
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

    # Para walk-ins (camarero/admin reservando para cliente sin cuenta) no
    # tenemos usuarioId real. El schema validator de Mongo exige el campo
    # presente y de tipo string, así que guardamos string vacío. La info
    # del cliente real va en `nombre_completo` + `telefono_cliente` + `correo_cliente`,
    # y la del actor en `creado_por_actor`.
    reserva_dict = {
        "usuario_id": usuario_id_final or "",
        "nombre_completo": reserva.nombreCompleto,
        "fecha": reserva.fecha,
        "hora": reserva.hora,
        "comensales": reserva.comensales,
        "turno": reserva.turno,
        "notas": reserva.notas,
        "mesa_id": mesa_id,
        "numero_mesa": numero_mesa,
        "estado": "Confirmada",
        "restaurante_id": restaurante_id_final,
    }
    if reserva.notas is None:
        reserva_dict.pop("notas")
    # Persistir datos del cliente real (solo cuando los provee staff)
    if telefono_cliente_final is not None:
        reserva_dict["telefono_cliente"] = telefono_cliente_final
    if correo_cliente_final is not None:
        reserva_dict["correo_cliente"] = correo_cliente_final
    if creado_por_actor is not None:
        reserva_dict["creado_por_actor"] = creado_por_actor

    try:
        resultado = coleccion_reservas.insert_one(reserva_dict)
    except DuplicateKeyError:
        # El índice único `ux_reserva_slot_confirmada` ya tenía ese slot:
        # otra reserva ganó la carrera entre el check y el insert.
        raise HTTPException(
            status_code=409,
            detail="Esa mesa ya está reservada para esa fecha y hora",
        )
    return {
        "id": str(resultado.inserted_id),
        "usuarioId": usuario_id_final or "",
        "nombreCompleto": reserva.nombreCompleto,
        "fecha": reserva.fecha,
        "hora": reserva.hora,
        "comensales": reserva.comensales,
        "turno": reserva.turno,
        "estado": "Confirmada",
        "mesaId": mesa_id,
        "numeroMesa": numero_mesa,
        "notas": reserva.notas,
        "telefonoCliente": telefono_cliente_final,
        "correoCliente": correo_cliente_final,
    }


# ─── Endpoints de estado y asignación de mesa (rutas literales antes de /{id}) ─

@router.patch("/{reserva_id}/estado", summary="Cambiar estado de una reserva (admin)")
def cambiar_estado_reserva(
    reserva_id: str,
    body: CambioEstadoBody,
    request: Request,
    actor: dict = Depends(require_role(["admin", "camarero", "super_admin"])),
):
    """Cambia el estado de una reserva. Solo personal de la misma sucursal."""
    if body.estado not in _ESTADOS_VALIDOS:
        raise HTTPException(
            status_code=400,
            detail=f"Estado inválido. Valores permitidos: {', '.join(sorted(_ESTADOS_VALIDOS))}",
        )

    try:
        oid = ObjectId(reserva_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de reserva inválido")

    reserva = coleccion_reservas.find_one({"_id": oid})
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    rol = normalizar_rol(actor.get("rol", ""))
    if rol != "super_admin":
        rid = actor.get("restaurante_id")
        if rid and reserva.get("restaurante_id") and reserva["restaurante_id"] != rid:
            raise HTTPException(status_code=403, detail="No puedes gestionar reservas de otra sucursal")

    coleccion_reservas.update_one({"_id": oid}, {"$set": {"estado": body.estado}})
    ag.registrar(
        ag.RESERVA_ESTADO_CAMBIADO,
        actor=actor.get("correo"),
        objetivo=reserva_id,
        detalle=f"Estado → {body.estado}",
    )
    return {"mensaje": "Estado actualizado", "estado": body.estado}


@router.patch("/{reserva_id}/asignar-mesa", summary="Asignar mesa a una reserva (admin)")
def asignar_mesa_reserva(
    reserva_id: str,
    body: AsignarMesaBody,
    request: Request,
    actor: dict = Depends(require_role(["admin", "camarero", "super_admin"])),
):
    """Asigna una mesa a una reserva existente.

    Verifica que la mesa existe y pertenece a la misma sucursal que la reserva.
    Rellena `numero_mesa` automáticamente desde el documento de mesa.
    """
    try:
        oid_reserva = ObjectId(reserva_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de reserva inválido")

    try:
        oid_mesa = ObjectId(body.mesaId)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de mesa inválido")

    reserva = coleccion_reservas.find_one({"_id": oid_reserva})
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    mesa = coleccion_mesas.find_one({"_id": oid_mesa})
    if not mesa:
        raise HTTPException(status_code=404, detail="Mesa no encontrada")

    rol = normalizar_rol(actor.get("rol", ""))

    # Verificar aislamiento por sucursal del actor
    if rol != "super_admin":
        rid_actor = actor.get("restaurante_id")
        if rid_actor and reserva.get("restaurante_id") and reserva["restaurante_id"] != rid_actor:
            raise HTTPException(status_code=403, detail="No puedes gestionar reservas de otra sucursal")

    # Verificar que la mesa es de la misma sucursal que la reserva
    rid_reserva = reserva.get("restaurante_id")
    rid_mesa = mesa.get("restaurante_id")
    if rid_reserva and rid_mesa and rid_mesa != rid_reserva:
        raise HTTPException(status_code=400, detail="La mesa pertenece a otra sucursal")

    numero_mesa = mesa.get("numero", 0)
    coleccion_reservas.update_one(
        {"_id": oid_reserva},
        {"$set": {"mesa_id": body.mesaId, "numero_mesa": numero_mesa}},
    )
    ag.registrar(
        ag.RESERVA_MESA_ASIGNADA,
        actor=actor.get("correo"),
        objetivo=reserva_id,
        detalle=f"Mesa {body.mesaId} (nº {numero_mesa})",
    )
    return {"mensaje": "Mesa asignada", "mesaId": body.mesaId, "numeroMesa": numero_mesa}


# ─── PATCH y PUT genéricos ────────────────────────────────────────────────────

@router.patch("/{reserva_id}")
def actualizar_comensales(
    reserva_id: str,
    datos: ActualizarComensalesBody,
    actor: dict = Depends(get_current_user),
):
    """Cambia solo el número de comensales. Si la mesa actual no cabe en
    el nuevo número, se reasigna automáticamente. Clientes solo sobre las
    suyas; staff solo dentro de su sucursal.
    """
    try:
        oid = ObjectId(reserva_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de reserva inválido")

    reserva = coleccion_reservas.find_one({"_id": oid})
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    rol = normalizar_rol(actor.get("rol", ""))
    if rol == "cliente" and reserva.get("usuario_id") != actor.get("sub"):
        raise HTTPException(status_code=403, detail="No puedes modificar reservas ajenas")
    if rol not in ("cliente", "super_admin"):
        rid = actor.get("restaurante_id")
        if rid and reserva.get("restaurante_id") and reserva["restaurante_id"] != rid:
            raise HTTPException(
                status_code=403,
                detail="No puedes gestionar reservas de otra sucursal",
            )

    # Bloqueo de estado terminal
    estado_actual = reserva.get("estado", "Confirmada")
    if estado_actual in _ESTADOS_TERMINALES_RESERVA:
        raise HTTPException(
            status_code=409,
            detail=f"No se puede modificar una reserva en estado '{estado_actual}'.",
        )

    rid_reserva = reserva.get("restaurante_id")
    fecha = reserva.get("fecha", "")
    hora = reserva.get("hora", "")

    # Reasignar mesa si la actual no cabe o está ocupada por otra reserva.
    mesa_actual_id = reserva.get("mesa_id")
    mesa_actual = None
    if mesa_actual_id:
        try:
            mesa_actual = coleccion_mesas.find_one({"_id": ObjectId(mesa_actual_id)})
        except Exception:
            mesa_actual = None

    ocupadas = _mesas_ocupadas_por_hora(fecha, hora, rid_reserva)
    ocupadas.discard(str(mesa_actual_id or ""))

    cabe = (
        mesa_actual is not None
        and mesa_actual.get("capacidad", 0) >= datos.comensales
        and str(mesa_actual["_id"]) not in ocupadas
    )

    set_fields: dict = {"comensales": datos.comensales}
    if not cabe:
        filtro: dict = {"capacidad": {"$gte": datos.comensales}}
        if rid_reserva:
            filtro["restaurante_id"] = rid_reserva
        nueva_mesa = None
        for m in coleccion_mesas.find(filtro).sort("capacidad", 1):
            if str(m["_id"]) not in ocupadas:
                nueva_mesa = m
                break
        if not nueva_mesa:
            raise HTTPException(
                status_code=409,
                detail=f"No hay mesas para {datos.comensales} comensales en ese horario",
            )
        set_fields["mesa_id"] = str(nueva_mesa["_id"])
        set_fields["numero_mesa"] = nueva_mesa.get("numero", 0)

    coleccion_reservas.update_one({"_id": oid}, {"$set": set_fields})
    return {"mensaje": "Reserva actualizada"}


_ESTADOS_TERMINALES_RESERVA = {"Cancelada", "NoShow", "Llegado"}
_TURNOS_VALIDOS = {"comida", "cena"}


@router.put("/{reserva_id}")
def actualizar_reserva_completa(
    reserva_id: str,
    datos: ReservaActualizar,
    actor: dict = Depends(get_current_user),
):
    """Actualiza una reserva con validación completa.

    Reglas:
    - Clientes solo pueden tocar sus propias reservas.
    - Staff (no super_admin) solo dentro de su sucursal.
    - No se puede editar una reserva en estado terminal (Cancelada, NoShow,
      Llegado) salvo que el cambio sea volver a 'Confirmada' (super_admin).
    - No se puede editar una reserva cuyo slot ya pasó.
    - Si cambian fecha, hora o comensales: re-validar horario del restaurante
      y disponibilidad de mesa. Si la mesa actual no cabe en los nuevos
      comensales o ya está ocupada, se reasigna automáticamente.
    """
    try:
        oid = ObjectId(reserva_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de reserva inválido")

    reserva = coleccion_reservas.find_one({"_id": oid})
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    rol = normalizar_rol(actor.get("rol", ""))
    if rol == "cliente" and reserva.get("usuario_id") != actor.get("sub"):
        raise HTTPException(status_code=403, detail="No puedes modificar reservas ajenas")

    # Aislamiento por sucursal para staff no super_admin
    if rol not in ("cliente", "super_admin"):
        rid = actor.get("restaurante_id")
        if rid and reserva.get("restaurante_id") and reserva["restaurante_id"] != rid:
            raise HTTPException(status_code=403, detail="No puedes gestionar reservas de otra sucursal")

    # Bloqueo de estado terminal — salvo que el actor lo esté re-activando
    estado_actual = reserva.get("estado", "Confirmada")
    nuevo_estado = datos.estado
    quiere_reactivar = (
        estado_actual in _ESTADOS_TERMINALES_RESERVA
        and nuevo_estado == "Confirmada"
        and rol in {"admin", "super_admin"}
    )
    if estado_actual in _ESTADOS_TERMINALES_RESERVA and not quiere_reactivar:
        raise HTTPException(
            status_code=409,
            detail=f"No se puede editar una reserva en estado '{estado_actual}'.",
        )

    # Determinar valores finales (los del body o los actuales)
    fecha_final = datos.fecha if datos.fecha is not None else reserva.get("fecha", "")
    hora_final = datos.hora if datos.hora is not None else reserva.get("hora", "")
    comensales_final = (
        datos.comensales if datos.comensales is not None else reserva.get("comensales", 0)
    )
    turno_final = datos.turno if datos.turno is not None else reserva.get("turno", "")

    # Validar formato de fecha
    try:
        fecha_dt = date.fromisoformat(fecha_final)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Fecha inválida (formato YYYY-MM-DD)")

    # Validar formato de hora
    try:
        h, m = hora_final.split(":")
        if not (0 <= int(h) <= 23 and 0 <= int(m) <= 59):
            raise ValueError
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=400, detail="Hora inválida (formato HH:MM)")

    # Validar turno
    if turno_final and turno_final not in _TURNOS_VALIDOS:
        raise HTTPException(
            status_code=400,
            detail=f"Turno inválido. Válidos: {', '.join(sorted(_TURNOS_VALIDOS))}",
        )

    # Validar estado
    if nuevo_estado is not None and nuevo_estado not in _ESTADOS_VALIDOS:
        raise HTTPException(
            status_code=400,
            detail=f"Estado inválido. Válidos: {', '.join(sorted(_ESTADOS_VALIDOS))}",
        )

    # No editar reservas con slot ya pasado (salvo que solo se cambie el estado).
    cambio_de_slot = (
        datos.fecha is not None or datos.hora is not None or datos.comensales is not None
    )
    if cambio_de_slot:
        try:
            slot_dt = datetime.combine(
                fecha_dt,
                datetime.strptime(hora_final, "%H:%M").time(),
            )
            if slot_dt < datetime.now():
                raise HTTPException(
                    status_code=400,
                    detail="No se puede mover una reserva a una fecha/hora pasada",
                )
        except ValueError:
            pass  # ya validado arriba

    rid_reserva = reserva.get("restaurante_id")

    # Si cambió fecha/hora/comensales: re-validar horario del restaurante y
    # disponibilidad de mesa.
    mesa_id_final = reserva.get("mesa_id")
    numero_mesa_final = reserva.get("numero_mesa", 0)

    if cambio_de_slot and rid_reserva:
        # Validar horario del restaurante para el nuevo día
        try:
            rest = coleccion_restaurantes.find_one({"_id": ObjectId(rid_reserva)})
        except Exception:
            rest = None
        if rest:
            horarios_dia = rest.get("horarios_dia")
            if horarios_dia:
                _DIAS_ES = [
                    "lunes", "martes", "miercoles", "jueves",
                    "viernes", "sabado", "domingo",
                ]
                dia_key = _DIAS_ES[fecha_dt.weekday()]
                entrada_dia = horarios_dia.get(dia_key, {})
                abierto_raw = entrada_dia.get("abierto", True)
                abierto = (
                    abierto_raw.lower() not in ("false", "0", "no")
                    if isinstance(abierto_raw, str)
                    else bool(abierto_raw)
                )
                if not abierto:
                    raise HTTPException(
                        status_code=400,
                        detail=f"El restaurante está cerrado el {dia_key}",
                    )
                apertura = entrada_dia.get("apertura")
                cierre = entrada_dia.get("cierre")
                if apertura and cierre and not _hora_en_rango(hora_final, apertura, cierre):
                    raise HTTPException(
                        status_code=400,
                        detail=(
                            f"El restaurante no acepta reservas a las {hora_final}. "
                            f"Horario del {dia_key}: {apertura} – {cierre}"
                        ),
                    )

        # Re-validar disponibilidad de mesa: si la actual no cabe o está ocupada
        # por otra reserva en el nuevo slot, se reasigna automáticamente.
        ocupadas = _mesas_ocupadas_por_hora(fecha_final, hora_final, rid_reserva)
        # La propia reserva no debe contar como conflicto consigo misma
        ocupadas.discard(str(mesa_id_final or ""))

        mesa_actual = None
        if mesa_id_final:
            try:
                mesa_actual = coleccion_mesas.find_one({"_id": ObjectId(mesa_id_final)})
            except Exception:
                mesa_actual = None

        cabe = (
            mesa_actual is not None
            and mesa_actual.get("capacidad", 0) >= comensales_final
            and str(mesa_actual["_id"]) not in ocupadas
        )
        if not cabe:
            # Buscar una mesa nueva
            filtro_candidatas: dict = {"capacidad": {"$gte": comensales_final}}
            if rid_reserva:
                filtro_candidatas["restaurante_id"] = rid_reserva
            candidatas = coleccion_mesas.find(filtro_candidatas).sort("capacidad", 1)
            nueva_mesa = None
            for m in candidatas:
                if str(m["_id"]) not in ocupadas:
                    nueva_mesa = m
                    break
            if not nueva_mesa:
                raise HTTPException(
                    status_code=409,
                    detail=(
                        f"No hay mesas disponibles para {comensales_final} comensales "
                        f"el {fecha_final} a las {hora_final}"
                    ),
                )
            mesa_id_final = str(nueva_mesa["_id"])
            numero_mesa_final = nueva_mesa.get("numero", 0)

    # Construir el $set solo con los campos que vinieron en el body
    campos: dict = {}
    if datos.fecha is not None:
        campos["fecha"] = fecha_final
    if datos.hora is not None:
        campos["hora"] = hora_final
    if datos.comensales is not None:
        campos["comensales"] = comensales_final
    if datos.turno is not None:
        campos["turno"] = turno_final
    if datos.notas is not None:
        campos["notas"] = datos.notas
    if datos.estado is not None:
        campos["estado"] = datos.estado
    # Si reasignamos mesa, persistirla
    if cambio_de_slot:
        campos["mesa_id"] = mesa_id_final
        campos["numero_mesa"] = numero_mesa_final

    if not campos:
        raise HTTPException(status_code=400, detail="No hay campos válidos")

    coleccion_reservas.update_one({"_id": oid}, {"$set": campos})
    return {"mensaje": "Reserva actualizada"}


@router.delete("/{reserva_id}")
def eliminar_reserva(
    reserva_id: str,
    actor: dict = Depends(get_current_user),
):
    """Elimina una reserva. Clientes solo pueden eliminar las propias."""
    try:
        oid = ObjectId(reserva_id)
    except Exception:
        raise HTTPException(status_code=400, detail="ID de reserva inválido")

    reserva = coleccion_reservas.find_one({"_id": oid})
    if not reserva:
        raise HTTPException(status_code=404, detail="Reserva no encontrada")

    rol = normalizar_rol(actor.get("rol", ""))
    if rol == "cliente" and reserva.get("usuario_id") != actor.get("sub"):
        raise HTTPException(status_code=403, detail="No puedes eliminar reservas ajenas")

    # Aislamiento por sucursal para staff no super_admin
    if rol not in ("cliente", "super_admin"):
        rid = actor.get("restaurante_id")
        if rid and reserva.get("restaurante_id") and reserva["restaurante_id"] != rid:
            raise HTTPException(status_code=403, detail="No puedes gestionar reservas de otra sucursal")

    coleccion_reservas.delete_one({"_id": oid})
    return {"mensaje": "Reserva eliminada"}


def _hora_en_rango(hora: str, apertura: str, cierre: str) -> bool:
    mins = _hora_a_minutos(hora)
    a = _hora_a_minutos(apertura)
    c = _hora_a_minutos(cierre)
    if c > a:
        return a <= mins < c
    else:  # cruza medianoche
        return mins >= a or mins < c
