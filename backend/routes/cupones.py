# ============================================================================
# backend/routes/cupones.py
# ----------------------------------------------------------------------------
# Cupones de descuento.
#
# Un cupón tiene:
#   - codigo: string que el cliente escribe en el checkout.
#   - tipo:   "porcentaje" (10%) o "monto" (5€ fijos).
#   - valor:  número (10 o 5 según el tipo).
#   - usos_max / usos_actuales: límite de canjes total.
#   - validez: fechas inicio/fin.
#   - producto_id / categoria: aplica solo a algunos productos (opcional).
#
# Endpoints:
#   GET    /cupones                       → listado (admin)
#   POST   /cupones                       → crear (admin)
#   PUT    /cupones/{id}                  → editar (admin)
#   DELETE /cupones/{id}                  → eliminar (admin)
#   POST   /cupones/validar               → cliente valida código en checkout
#   POST   /cupones/{id}/enviar-masivo    → envía cupón por email a N clientes
#
# El BackgroundTasks de FastAPI se usa para mandar correos sin bloquear la
# respuesta HTTP (el endpoint responde inmediato, el correo sale después).
# ============================================================================
import logging
import re
from datetime import date
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request
from fastapi_mail import FastMail, MessageSchema, MessageType
from pydantic import BaseModel, field_validator
from bson import ObjectId
from bson.errors import InvalidId
from pymongo import ReturnDocument

from database import coleccion_cupones, coleccion_usuarios
from limiter import limiter
from security import get_current_user, normalizar_rol, require_role
from utils.auth_helpers import conf
import audit_general as ag

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
        if not re.match(r"^[A-Z0-9_-]{2,20}$", v):
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


class CuponValidar(BaseModel):
    codigo: str
    subtotal: float
    coste_envio: float = 0.0
    restaurante_id: Optional[str] = None


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


def _cupon_vigente(cupon: dict) -> Optional[str]:
    """Verifica si el cupón está activo, en fecha y con usos disponibles.

    Devuelve el mensaje de error si no es válido, o None si es válido.
    """
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

class EnvioMasivoRequest(BaseModel):
    cuponId: str
    filtro: str  # "todos" o "restaurante"
    restauranteId: Optional[str] = None

# ─── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/validar", summary="Validar un cupón y calcular descuento")
def validar_cupon(datos: CuponValidar):
    """Valida un cupón por código y devuelve el descuento aplicable.

    Endpoint público (lo usa el cliente al pagar). No requiere autenticación
    porque el descuento real se aplica en el pedido, donde sí se exige JWT.
    """
    codigo_limpio = datos.codigo.strip().upper()
    cupon = coleccion_cupones.find_one({"codigo": codigo_limpio})

    if not cupon:
        return {
            "valido": False,
            "mensaje": "Cupón no encontrado",
            "descuento": 0.0,
        }

    error = _cupon_vigente(cupon)
    if error:
        return {"valido": False, "mensaje": error, "descuento": 0.0}

    # Restricción de sucursal: si el cupón es de una sucursal concreta, debe
    # coincidir con la del pedido.
    rid_cupon = cupon.get("restaurante_id")
    if rid_cupon and datos.restaurante_id and str(rid_cupon) != str(datos.restaurante_id):
        return {
            "valido": False,
            "mensaje": "Este cupón no es válido para este restaurante",
            "descuento": 0.0,
        }

    tipo = cupon.get("tipo")
    valor = float(cupon.get("valor", 0))
    subtotal = round(datos.subtotal, 2)

    if tipo == "porcentaje":
        descuento = round(subtotal * (valor / 100), 2)
    elif tipo == "fijo":
        # Capamos al total del pedido (subtotal + envío)
        total_max = round(subtotal + datos.coste_envio, 2)
        descuento = round(min(valor, total_max), 2)
    else:
        return {"valido": False, "mensaje": "Tipo de cupón desconocido", "descuento": 0.0}

    return {
        "valido": True,
        "mensaje": "Cupón aplicado correctamente",
        "descuento": descuento,
        "codigo": codigo_limpio,
        "tipo": tipo,
        "id": str(cupon["_id"]),
    }


@router.get("", summary="Listar cupones")
def listar_cupones(
    solo_activos: bool = Query(False),
    actor: dict = Depends(get_current_user),
):
    """Lista cupones según el rol del actor.

    - Admin: ve cupones de su sucursal + cupones globales (restaurante_id=None).
    - super_admin: ve todos.
    - Cliente/camarero/cocinero: ve todos (pueden canjear cualquier cupón
      válido al pedir; el filtrado de elegibilidad se hace en /usar y /validar).
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


async def _enviar_email_cupon(
    email_destino: str,
    nombre: str,
    codigo: str,
    descripcion: str,
) -> None:
    """Envía un email con un cupón a un cliente. Se invoca como BackgroundTask
    desde el endpoint de envío masivo para no bloquear la respuesta HTTP.
    Errores SMTP se loggean pero no rompen el flujo: si falla un destinatario,
    los demás siguen recibiendo el correo.
    """
    html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
        <h2 style="color: #800020;">¡Hola {nombre}!</h2>
        <p>Tienes un nuevo beneficio exclusivo de <strong>Bravo</strong>.</p>
        <div style="background: #111; color: #fff; padding: 20px; border-radius: 10px; text-align: center;">
            <h1 style="font-size: 35px; letter-spacing: 4px; color: #d4af37;">{codigo}</h1>
            <p style="color: #ccc; font-size: 16px;">{descripcion}</p>
        </div>
        <p style="color: #666; font-size: 12px; margin-top: 20px;">Válido por tiempo limitado. ¡Te esperamos!</p>
    </div>
    """
    mensaje = MessageSchema(
        subject=f"¡{nombre}, tenemos un regalo para ti!",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html,
    )
    try:
        await FastMail(conf).send_message(mensaje)
    except Exception as e:
        logger.error(f"Error enviando cupón a {email_destino}: {e}")


@router.post("/enviar-masivo", summary="Envío masivo de cupón por email (admin)")
@limiter.limit("3/minute")
def enviar_cupon_masivo(
    request: Request,
    datos: EnvioMasivoRequest,
    background_tasks: BackgroundTasks,
    actor: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Envía un cupón por email a todos los clientes que cumplen el filtro.

    - `filtro="todos"`: todos los clientes activos.
    - `filtro="restaurante"`: clientes activos asociados a `restauranteId`.

    El envío SMTP corre en background para no bloquear la respuesta. Si falla
    un correo concreto, los demás siguen llegando (el error se loggea).
    """
    cupon = coleccion_cupones.find_one({"_id": _oid(datos.cuponId)})
    if not cupon:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")

    # Un admin no puede mandar masivos de cupones que no son de su sucursal
    # (incluidos los globales, que son territorio del super_admin).
    _verificar_propiedad_cupon(cupon, actor)

    query: dict = {"rol": "cliente", "activo": True}
    if datos.filtro == "restaurante":
        if not datos.restauranteId:
            raise HTTPException(
                status_code=400,
                detail="Falta restauranteId para el filtro 'restaurante'",
            )
        query["restaurante_id"] = datos.restauranteId
    elif datos.filtro != "todos":
        raise HTTPException(
            status_code=400,
            detail="filtro debe ser 'todos' o 'restaurante'",
        )

    clientes = list(coleccion_usuarios.find(query, {"correo": 1, "nombre": 1}))
    if not clientes:
        raise HTTPException(
            status_code=404,
            detail="No se encontraron clientes para este filtro",
        )

    codigo = cupon.get("codigo", "")
    descripcion = cupon.get("descripcion", "")
    encolados = 0
    for cliente in clientes:
        correo = cliente.get("correo")
        if not correo:
            continue
        background_tasks.add_task(
            _enviar_email_cupon,
            correo,
            cliente.get("nombre", "Cliente"),
            codigo,
            descripcion,
        )
        encolados += 1

    ag.registrar(
        ag.CUPON_ENVIADO_MASIVO,
        actor=actor.get("correo"),
        objetivo=codigo,
        detalle=f"filtro={datos.filtro}, destinatarios={encolados}",
    )
    return {
        "mensaje": f"Procesando el envío de {encolados} correos.",
        "destinatarios": encolados,
    }


@router.post("/{cupon_id}/usar", summary="Registrar uso del cupón")
def registrar_uso(cupon_id: str, _user: dict = Depends(get_current_user)):
    """Incrementa el contador de usos. Llámalo al aplicar el cupón en un pedido.

    Operación atómica: solo incrementa si el cupón está activo y aún no ha
    alcanzado su `usos_maximos`. Cualquier usuario autenticado puede canjear
    cupones de cualquier sucursal.
    """
    oid = _oid(cupon_id)
    actualizado = coleccion_cupones.find_one_and_update(
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
        return_document=ReturnDocument.AFTER,
    )
    if not actualizado:
        existente = coleccion_cupones.find_one({"_id": oid})
        if not existente:
            raise HTTPException(status_code=404, detail="Cupón no encontrado")
        if not existente.get("activo", True):
            raise HTTPException(status_code=400, detail="El cupón está inactivo")
        raise HTTPException(status_code=400, detail="El cupón ha alcanzado el límite de usos")
    return {
        "mensaje": "Uso registrado",
        "usos_actuales": actualizado.get("usos_actuales", 0),
    }
