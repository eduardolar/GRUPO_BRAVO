from fastapi import APIRouter, Depends, Header, HTTPException, Query
from fastapi.responses import StreamingResponse
from exceptions import AppError, NotFoundError, ConflictError, ValidacionError
from datetime import datetime, timezone, timedelta
from bson import ObjectId
from bson.errors import InvalidId
from fastapi_mail import FastMail, MessageSchema, MessageType
from pydantic import BaseModel, ConfigDict
from typing import Optional
import csv
import io
import logging
import uuid
from pymongo.errors import DuplicateKeyError, OperationFailure

from database import coleccion_pedidos, coleccion_productos, coleccion_ingredientes, coleccion_usuarios, cliente
from models import PedidoCrear
from routes.auth import conf
from security import require_role, get_current_user, normalizar_rol

router = APIRouter(prefix="/pedidos", tags=["Pedidos"])
logger = logging.getLogger("uvicorn")


# ── Server time (sincroniza cronómetros del cliente) ─────────────────────────

@router.get("/server-time")
def obtener_server_time():
    """Devuelve la hora actual del servidor en UTC ISO 8601.

    El cliente la usa para calcular un offset y mantener sus cronómetros
    alineados con el servidor, independientemente de la hora del dispositivo.
    """
    return {"server_time": datetime.now(timezone.utc).isoformat()}


# ── Helpers de stock ──────────────────────────────────────────────────────────

def _descontar_stock(items: list, session=None, restaurante_id: str | None = None):
    """Resta del inventario los ingredientes consumidos por los items.

    El descuento se hace contra los ingredientes de la **misma sucursal**
    que el producto: si Madrid hace un pedido con "Pollo", se descuenta
    el "Pollo" de Madrid, nunca el de Zaragoza. La sucursal se toma de:
      1. el `restaurante_id` que pasa el caller (el del pedido), si llega
      2. el `restaurante_id` del propio producto (fallback)
    Si ninguno está disponible (caso legacy), se cae al matching por nombre
    sin sucursal — pero loguea un aviso.
    """
    for item in items:
        producto_id = item.get("producto_id", "")
        cantidad_pedida = item.get("cantidad", 1)
        ingredientes_excluidos = item.get("sin", [])

        if not producto_id:
            continue

        try:
            producto_db = coleccion_productos.find_one(
                {"_id": ObjectId(producto_id)}, session=session
            )
        except Exception:
            producto_db = None

        if not producto_db:
            continue

        # Sucursal contra la que descontar: prioriza la del pedido.
        rid = restaurante_id or producto_db.get("restaurante_id")

        for ing in producto_db.get("ingredientes", []):
            if isinstance(ing, str):
                nombre_ing = ing
                # Bug 2 fix: strings sueltos no tienen cantidadReceta
                cantidad_receta = 1
                ing_oid = None
            elif isinstance(ing, dict):
                nombre_ing = ing.get("nombre", "")
                # Bug 2 fix: aceptar tanto snake_case como camelCase
                cr = ing.get("cantidad_receta")
                if cr is None:
                    cr = ing.get("cantidadReceta")
                cantidad_receta = cr or 1

                # Bug 1 fix: preferir match por id cuando está disponible
                ing_id_raw = (
                    ing.get("ingrediente_id")
                    or ing.get("ingredienteId")
                    or ing.get("id")
                    or ing.get("_id")
                )
                ing_oid = None
                if ing_id_raw:
                    try:
                        ing_oid = ObjectId(str(ing_id_raw))
                    except (InvalidId, TypeError):
                        ing_oid = None
            else:
                continue

            if nombre_ing in ingredientes_excluidos:
                continue

            descuento = cantidad_pedida * cantidad_receta

            if ing_oid is not None:
                # Camino preferido: filtro exacto por _id; el nombre se usa
                # solo en el diagnóstico de error, no en el filtro.
                filtro: dict = {
                    "_id": ing_oid,
                    "cantidad_actual": {"$gte": descuento},
                }
                if rid:
                    # Aislamiento por sucursal: el ingrediente DEBE pertenecer
                    # al mismo restaurante que el producto/pedido.
                    filtro["restaurante_id"] = rid
            else:
                # Camino legacy: matching por nombre (puede haber colisiones si
                # existen duplicados — ver Bug 1; se mantiene por retrocompat).
                filtro = {
                    "nombre": {"$regex": f"^{nombre_ing}$", "$options": "i"},
                    "cantidad_actual": {"$gte": descuento},
                }
                if rid:
                    filtro["restaurante_id"] = rid
                else:
                    logger.warning(
                        "Descuento de stock sin restaurante_id (producto=%s ingrediente=%r). "
                        "Cayendo a matching solo por nombre (legacy).",
                        producto_id, nombre_ing,
                    )

            result = coleccion_ingredientes.update_one(
                filtro,
                {"$inc": {"cantidad_actual": -descuento}},
                session=session,
            )
            if result.matched_count == 0:
                # Diagnóstico fino: distinguimos "no existe en la sucursal"
                # de "existe pero no hay stock suficiente".
                if ing_oid is not None:
                    existe = coleccion_ingredientes.find_one(
                        {
                            "_id": ing_oid,
                            **({"restaurante_id": rid} if rid else {}),
                        },
                        session=session,
                    )
                else:
                    existe = coleccion_ingredientes.find_one(
                        {
                            "nombre": {"$regex": f"^{nombre_ing}$", "$options": "i"},
                            **({"restaurante_id": rid} if rid else {}),
                        },
                        session=session,
                    )
                if existe is None:
                    raise ConflictError(
                        f"El ingrediente '{nombre_ing}' no existe en esta sucursal"
                    )
                raise ConflictError(
                    f"Stock insuficiente para el ingrediente '{nombre_ing}'"
                )


VALORES_ENTREGA_VALIDOS = {"local", "domicilio", "recoger"}


def _normalizar_tipo_entrega(valor: str) -> str:
    texto = valor.strip().lower()
    if texto in VALORES_ENTREGA_VALIDOS:
        return texto
    if "domicilio" in texto:
        return "domicilio"
    if "recoger" in texto:
        return "recoger"
    return "local"


# ── Factura por correo ────────────────────────────────────────────────────────

_ETIQUETA_ENTREGA = {"local": "En mesa", "domicilio": "A domicilio", "recoger": "Recoger en local"}
_ETIQUETA_PAGO = {
    "efectivo": "Efectivo",
    "tarjeta": "Tarjeta",
    "paypal": "PayPal",
    "google_pay": "Google Pay",
}


def _filas_items(items: list) -> str:
    filas = ""
    for it in items:
        nombre = it.get("nombre") or it.get("producto_nombre") or "Producto"
        cantidad = it.get("cantidad", 1)
        precio = it.get("precio", 0)
        subtotal = cantidad * precio
        sin = it.get("sin", [])
        sin_txt = f"<br><small style='color:#999'>Sin: {', '.join(sin)}</small>" if sin else ""
        filas += f"""
        <tr>
          <td style="padding:10px 8px;border-bottom:1px solid #f0ebe3;">{nombre}{sin_txt}</td>
          <td style="padding:10px 8px;border-bottom:1px solid #f0ebe3;text-align:center;">{cantidad}</td>
          <td style="padding:10px 8px;border-bottom:1px solid #f0ebe3;text-align:right;">{subtotal:.2f} €</td>
        </tr>"""
    return filas


async def _enviar_factura(email_destino: str, nombre_usuario: str, pedido_id: str, pedido: dict):
    tipo_entrega = _ETIQUETA_ENTREGA.get(pedido.get("tipo_entrega", ""), pedido.get("tipo_entrega", ""))
    metodo_pago = _ETIQUETA_PAGO.get(pedido.get("metodo_pago", ""), pedido.get("metodo_pago", "").capitalize())
    fecha_fmt = datetime.fromisoformat(pedido["fecha"]).strftime("%d/%m/%Y %H:%M")

    detalle_entrega = ""
    if pedido.get("numero_mesa"):
        detalle_entrega = f"<p style='margin:4px 0;color:#555'>Mesa nº {pedido['numero_mesa']}</p>"
    elif pedido.get("direccion_entrega"):
        detalle_entrega = f"<p style='margin:4px 0;color:#555'>Dirección: {pedido['direccion_entrega']}</p>"

    notas_html = ""
    if pedido.get("notas"):
        notas_html = f"""
        <p style="margin:16px 0 4px;color:#800020;font-weight:bold;">Notas</p>
        <p style="margin:0;color:#555;font-style:italic;">{pedido['notas']}</p>"""

    html = f"""
    <div style="font-family:Arial,sans-serif;background:#FBF9F6;padding:40px 20px;">
      <div style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #E0DBD3;border-radius:10px;overflow:hidden;">

        <!-- Cabecera -->
        <div style="background:#800020;padding:28px 32px;text-align:center;">
          <h1 style="margin:0;color:#fff;font-size:22px;letter-spacing:2px;">RESTAURANTE BRAVO</h1>
          <p style="margin:6px 0 0;color:#f5c6c6;font-size:13px;">Confirmación de pedido</p>
        </div>

        <!-- Cuerpo -->
        <div style="padding:28px 32px;">
          <p style="color:#2D2D2D;font-size:15px;">Hola, <strong>{nombre_usuario}</strong>.</p>
          <p style="color:#555;font-size:14px;line-height:1.6;">
            Hemos recibido tu pedido correctamente. A continuación tienes el resumen:
          </p>

          <!-- Info pedido -->
          <div style="background:#FBF9F6;border:1px solid #E0DBD3;border-radius:6px;padding:14px 18px;margin:20px 0;font-size:13px;color:#555;">
            <p style="margin:4px 0;"><strong>Pedido:</strong> #{pedido_id[-8:].upper()}</p>
            <p style="margin:4px 0;"><strong>Fecha:</strong> {fecha_fmt}</p>
            <p style="margin:4px 0;"><strong>Tipo de entrega:</strong> {tipo_entrega}</p>
            {detalle_entrega}
            <p style="margin:4px 0;"><strong>Método de pago:</strong> {metodo_pago}</p>
          </div>

          <!-- Tabla de productos -->
          <table style="width:100%;border-collapse:collapse;font-size:14px;">
            <thead>
              <tr style="background:#f7f3ee;">
                <th style="padding:10px 8px;text-align:left;color:#800020;">Producto</th>
                <th style="padding:10px 8px;text-align:center;color:#800020;">Cant.</th>
                <th style="padding:10px 8px;text-align:right;color:#800020;">Precio</th>
              </tr>
            </thead>
            <tbody>
              {_filas_items(pedido.get("items", []))}
            </tbody>
          </table>

          <!-- Total -->
          <div style="text-align:right;margin-top:16px;padding-top:12px;border-top:2px solid #800020;">
            <span style="font-size:18px;font-weight:bold;color:#800020;">Total: {pedido['total']:.2f} €</span>
          </div>

          {notas_html}
        </div>

        <!-- Pie -->
        <div style="background:#f7f3ee;padding:18px 32px;text-align:center;border-top:1px solid #E0DBD3;">
          <p style="margin:0;color:#999;font-size:12px;">
            Gracias por confiar en <strong>Restaurante Bravo</strong>. ¡Que lo disfrutes!
          </p>
        </div>

      </div>
    </div>
    """

    mensaje = MessageSchema(
        subject=f"Tu pedido en Restaurante Bravo — #{pedido_id[-8:].upper()}",
        recipients=[email_destino],
        body=html,
        subtype=MessageType.html,
    )

    try:
        await FastMail(conf).send_message(mensaje)
    except Exception as e:
        logger.error(f"Error enviando factura a {email_destino}: {e}")


# ── Modelos ───────────────────────────────────────────────────────────────────

class ActualizarEstadoPago(BaseModel):
    model_config = ConfigDict(extra="forbid")

    referenciaPago: str
    estadoPago: str = "pagado"


class ActualizarItemsPedido(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: Optional[list[dict]] = None
    total: Optional[float] = None
    estadoPago: Optional[str] = None
    estado: Optional[str] = None
    metodoPago: Optional[str] = None


class ActualizarEstado(BaseModel):
    model_config = ConfigDict(extra="forbid")

    estado: str


class ActualizarItemHecho(BaseModel):
    model_config = ConfigDict(extra="forbid")

    hecho: bool


# ── Estados y máquina de transiciones ────────────────────────────────────────
# Estados que el sistema reconoce como válidos para un pedido.
_ESTADOS_VALIDOS = {"pendiente", "preparando", "listo", "entregado", "cancelado"}

# Transiciones permitidas: de cada estado, qué estados destino son válidos.
# Estados terminales (entregado, cancelado): ninguna transición saliente.
_TRANSICIONES_VALIDAS: dict[str, set[str]] = {
    "pendiente":   {"preparando", "cancelado"},
    "preparando":  {"listo", "cancelado"},
    "listo":       {"entregado"},
    "entregado":   set(),   # terminal
    "cancelado":   set(),   # terminal
}


# ── Helpers de aislamiento por sucursal ──────────────────────────────────────

def _verificar_acceso_pedido(pedido: dict, current_user: dict) -> None:
    """Verifica que el usuario autenticado tiene permiso para acceder al pedido.

    Reglas:
    - super_admin: acceso total.
    - cliente: solo puede acceder a sus propios pedidos (por usuario_id).
    - camarero / cocinero / admin: solo pueden acceder a pedidos de su sucursal.

    Lanza HTTPException 403 si el acceso no está autorizado.
    """
    rol = normalizar_rol(current_user.get("rol", ""))

    if rol == "super_admin":
        return  # acceso total

    if rol == "cliente":
        if pedido.get("usuario_id") != current_user.get("sub"):
            raise HTTPException(
                status_code=403,
                detail="No puedes acceder a pedidos de otros usuarios",
            )
        return

    # Roles de personal (camarero, cocinero, admin y cualquier otro)
    jwt_restaurante = current_user.get("restaurante_id")
    pedido_restaurante = pedido.get("restaurante_id")
    # Solo rechazamos si ambos tienen restaurante_id y son distintos.
    # Si el pedido es legacy (sin restaurante_id) lo dejamos pasar.
    if jwt_restaurante and pedido_restaurante and jwt_restaurante != pedido_restaurante:
        raise HTTPException(
            status_code=403,
            detail="No puedes acceder a pedidos de otra sucursal",
        )


def _obtener_pedido_o_404(pedido_id: str) -> dict:
    """Recupera el documento del pedido o lanza NotFoundError."""
    pedido = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    if not pedido:
        raise NotFoundError("Pedido no encontrado")
    return pedido


# ── Endpoints ─────────────────────────────────────────────────────────────────

def _pedido_a_respuesta(pedido_doc: dict, n_items: int) -> dict:
    """Convierte un documento de pedido de MongoDB al shape de respuesta del endpoint."""
    return {
        "id": str(pedido_doc["_id"]),
        "fecha": pedido_doc.get("fecha", ""),
        "total": pedido_doc.get("total", 0),
        "estado": pedido_doc.get("estado", "pendiente"),
        "estadoPago": pedido_doc.get("estado_pago", "pendiente"),
        "items": n_items,
        "mesaId": pedido_doc.get("mesa_id"),
        "numeroMesa": pedido_doc.get("numero_mesa"),
    }


@router.post("")
async def crear_pedido(
    pedido: PedidoCrear,
    current_user: dict = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    items_dict = [item.model_dump() for item in pedido.items]

    # Asignar un item_id estable a cada item (UUID v4) si no lo trae ya.
    # Esto permite identificar items por id y evitar bugs de índice posicional
    # cuando dos camareros editan un pedido concurrentemente (importante 4).
    for item in items_dict:
        if not item.get("item_id"):
            item["item_id"] = str(uuid.uuid4())

    # Compute total from authoritative DB prices — never trust client-supplied totals
    total_calculado = 0.0
    for item in items_dict:
        pid = item.get("producto_id", "")
        try:
            producto_db = coleccion_productos.find_one({"_id": ObjectId(pid)}) if pid else None
        except Exception:
            producto_db = None
        if not producto_db:
            raise NotFoundError(f"Producto no encontrado: {pid}")
        precio_real = float(producto_db.get("precio", 0))
        item["precio"] = precio_real
        total_calculado += precio_real * item["cantidad"]

    # Para clientes, ignorar userId del payload y usar el sub del JWT.
    # Admin y personal de sala/cocina pueden crear pedidos en nombre de cualquier usuario.
    rol_actor = normalizar_rol(current_user.get("rol", ""))
    if rol_actor == "cliente":
        usuario_id_pedido = current_user["sub"]
    else:
        usuario_id_pedido = pedido.userId

    # ── Idempotencia server-side ──────────────────────────────────────────────
    # Si el cliente manda Idempotency-Key, buscamos un pedido previo con la
    # misma (usuario_id, idempotency_key). Si existe, devolvemos ese pedido
    # sin crear uno nuevo (respuesta 200 idempotente).
    if idempotency_key:
        ik = idempotency_key.strip()
        if ik:
            existing = coleccion_pedidos.find_one(
                {"usuario_id": usuario_id_pedido, "idempotency_key": ik}
            )
            if existing:
                items_raw = existing.get("items", [])
                n = len(items_raw) if isinstance(items_raw, list) else 0
                return _pedido_a_respuesta(existing, n)

    pedido_dict = {
        "usuario_id": usuario_id_pedido,
        "items": items_dict,
        "tipo_entrega": _normalizar_tipo_entrega(pedido.tipoEntrega),
        "metodo_pago": pedido.metodoPago,
        "total": total_calculado,
        "notas": pedido.notas,
        "fecha": datetime.now(timezone.utc).isoformat(),
        "estado": "pendiente",
        "referencia_pago": pedido.referenciaPago,
        "estado_pago": pedido.estadoPago or "pendiente",
    }

    if idempotency_key and idempotency_key.strip():
        pedido_dict["idempotency_key"] = idempotency_key.strip()

    if pedido.direccionEntrega:
        pedido_dict["direccion_entrega"] = pedido.direccionEntrega
    if pedido.mesaId:
        pedido_dict["mesa_id"] = pedido.mesaId
    if pedido.numeroMesa is not None:
        pedido_dict["numero_mesa"] = pedido.numeroMesa
    if pedido.restauranteId:
        pedido_dict["restaurante_id"] = pedido.restauranteId

    # Sucursal del pedido — el descuento de stock va contra ESTA sucursal,
    # nunca contra otra (aunque haya un ingrediente con el mismo nombre).
    rid_pedido = pedido.restauranteId

    resultado = None
    try:
        with cliente.start_session() as session:
            with session.start_transaction():
                _descontar_stock(items_dict, session=session, restaurante_id=rid_pedido)
                resultado = coleccion_pedidos.insert_one(pedido_dict, session=session)
    except AppError:
        raise
    except DuplicateKeyError:
        # Race condition: otro request con la misma idempotency_key llegó antes.
        # Recuperamos el pedido existente y lo devolvemos.
        existing = coleccion_pedidos.find_one(
            {"usuario_id": usuario_id_pedido, "idempotency_key": idempotency_key.strip()}
        )
        if existing:
            items_raw = existing.get("items", [])
            n = len(items_raw) if isinstance(items_raw, list) else 0
            return _pedido_a_respuesta(existing, n)
        raise  # error DuplicateKey en otro campo — propagar
    except OperationFailure as e:
        # MongoDB standalone no soporta transacciones: fallback a operaciones atómicas por documento
        if "Transaction numbers are only allowed" in str(e) or e.code == 20:
            logger.warning("MongoDB standalone detectado: usando actualizaciones atómicas sin transacción")
            try:
                _descontar_stock(items_dict, restaurante_id=rid_pedido)
                resultado = coleccion_pedidos.insert_one(pedido_dict)
            except DuplicateKeyError:
                existing = coleccion_pedidos.find_one(
                    {"usuario_id": usuario_id_pedido, "idempotency_key": idempotency_key.strip()}
                ) if idempotency_key else None
                if existing:
                    items_raw = existing.get("items", [])
                    n = len(items_raw) if isinstance(items_raw, list) else 0
                    return _pedido_a_respuesta(existing, n)
                raise
        else:
            logger.error(f"Error de base de datos creando pedido: {e}")
            raise  # deja que el handler global lo capture como 500
    except Exception:
        raise  # deja que el handler global lo capture como 500

    pedido_id = str(resultado.inserted_id)

    # Enviar factura al correo del usuario (sin bloquear la respuesta si falla)
    usuario = coleccion_usuarios.find_one({"_id": ObjectId(pedido.userId)}) if ObjectId.is_valid(pedido.userId) else None
    if not usuario:
        usuario = coleccion_usuarios.find_one({"_id": pedido.userId})

    if usuario:
        correo = usuario.get("correo", "")
        if correo and "@" in correo and "." in correo.split("@")[-1]:
            try:
                await _enviar_factura(
                    email_destino=correo,
                    nombre_usuario=usuario.get("nombre", "Cliente"),
                    pedido_id=pedido_id,
                    pedido=pedido_dict,
                )
            except Exception as e:
                logger.error(f"Error enviando factura para pedido {pedido_id}: {e}")

    return {
        "id": pedido_id,
        "fecha": pedido_dict["fecha"],
        "total": total_calculado,
        "estado": "pendiente",
        "estadoPago": pedido_dict["estado_pago"],
        "items": len(pedido.items),
        "mesaId": pedido_dict.get("mesa_id"),
        "numeroMesa": pedido_dict.get("numero_mesa"),
    }


@router.patch("/actualizar-estado-pago")
def actualizar_estado_pago(
    payload: ActualizarEstadoPago,
    current_user: dict = Depends(get_current_user),
):
    """Marca el estado de pago de un pedido identificado por su referencia.

    Lo llama el frontend del cliente tras un checkout de Stripe/PayPal.
    Requiere token JWT. Si el llamante es cliente, se verifica que la
    referencia de pago pertenezca a un pedido suyo.
    Camarero / admin / super_admin pueden actualizarlo sin esa restricción.
    """
    rol = normalizar_rol(current_user.get("rol", ""))

    filtro: dict = {"referencia_pago": payload.referenciaPago}

    if rol == "cliente":
        # El cliente solo puede actualizar pagos de sus propios pedidos
        filtro["usuario_id"] = current_user["sub"]

    elif rol not in {"camarero", "admin", "super_admin"}:
        raise HTTPException(
            status_code=403,
            detail="No tienes permiso para esta acción",
        )

    result = coleccion_pedidos.update_one(
        filtro,
        {"$set": {"estado_pago": payload.estadoPago}},
    )
    if result.matched_count == 0:
        raise NotFoundError("Pedido no encontrado con esa referencia de pago")
    return {"updated": result.modified_count > 0}


@router.patch("/{pedido_id}/estado")
def actualizar_estado_pedido(
    pedido_id: str,
    payload: ActualizarEstado,
    current_user: dict = Depends(require_role(["cocinero", "camarero", "admin", "super_admin"])),
):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")
    if payload.estado not in _ESTADOS_VALIDOS:
        raise ValidacionError(f"Estado inválido. Válidos: {sorted(_ESTADOS_VALIDOS)}")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    estado_actual = pedido.get("estado", "pendiente")

    # No-op: misma transición → 200 sin cambio
    if estado_actual == payload.estado:
        logger.info(
            "actualizar_estado_pedido no-op | sub=%s correo=%s pedido_id=%s estado=%s",
            current_user.get("sub"), current_user.get("correo"),
            pedido_id, payload.estado,
        )
        return {"updated": False, "estado": payload.estado}

    # Validación de la máquina de estados
    transiciones_permitidas = _TRANSICIONES_VALIDAS.get(estado_actual, set())
    if payload.estado not in transiciones_permitidas:
        raise ConflictError(
            f"Transición inválida: '{estado_actual}' → '{payload.estado}'. "
            f"Desde '{estado_actual}' solo se permite: {sorted(transiciones_permitidas) or '(estado terminal)'}"
        )

    update: dict = {"$set": {"estado": payload.estado}}
    # RGPD-03 — minimización de datos de geolocalización: cuando un pedido
    # alcanza un estado terminal (entregado o cancelado) ya no es necesario
    # conservar las coordenadas de la dirección de entrega. Las eliminamos
    # del documento del pedido.
    if payload.estado in {"entregado", "cancelado"}:
        update["$unset"] = {
            "direccion_lat": "",
            "direccion_lon": "",
            "latitud": "",
            "longitud": "",
        }

    result = coleccion_pedidos.update_one({"_id": ObjectId(pedido_id)}, update)
    if result.matched_count == 0:
        raise NotFoundError("Pedido no encontrado")

    # Auditoría mínima (importante 5)
    logger.info(
        "actualizar_estado_pedido | sub=%s correo=%s pedido_id=%s transicion=%s→%s",
        current_user.get("sub"), current_user.get("correo"),
        pedido_id, estado_actual, payload.estado,
    )

    return {"updated": result.modified_count > 0, "estado": payload.estado}


def _marcar_item_hecho_por_id(
    pedido_id: str,
    item_id: str,
    payload: ActualizarItemHecho,
    current_user: dict,
) -> dict:
    """Lógica compartida para marcar un item como hecho/no hecho usando su item_id.

    Usa un único update_one con condición de estado en el filtro para
    evitar race conditions (importante 3): solo actualiza si el pedido
    está en estado activo. La transición automática a 'listo' se protege
    con un segundo update_one condicional (idempotente).
    """
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    items = pedido.get("items", [])
    if not isinstance(items, list):
        raise ValidacionError("El pedido no tiene items válidos")

    # Buscar el item por su item_id
    item_idx_encontrado = None
    for idx, it in enumerate(items):
        if it.get("item_id") == item_id:
            item_idx_encontrado = idx
            break

    if item_idx_encontrado is None:
        raise NotFoundError(f"Item con id '{item_id}' no encontrado en el pedido")

    # Actualización atómica: solo marca si el pedido está en estado activo.
    # Esto evita doble disparo de la transición en requests concurrentes.
    result = coleccion_pedidos.update_one(
        {
            "_id": ObjectId(pedido_id),
            "estado": {"$in": ["pendiente", "preparando", "listo"]},
        },
        {"$set": {f"items.{item_idx_encontrado}.hecho": payload.hecho}},
    )

    if result.matched_count == 0:
        # El pedido existe (ya lo obtuvimos) pero está en estado terminal o no matchea
        estado_actual = pedido.get("estado", "")
        if estado_actual in {"entregado", "cancelado"}:
            raise ConflictError(
                f"No se puede modificar un item de un pedido en estado '{estado_actual}'"
            )
        raise NotFoundError("Pedido no encontrado o en estado no modificable")

    # Comprobar si todos los items están hechos y hacer la transición a 'listo'
    # de forma condicional (idempotente): solo si AÚN no está en 'listo'.
    pedido_actualizado = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    items_actualizados = pedido_actualizado.get("items", []) if pedido_actualizado else []
    todos_hechos = (
        len(items_actualizados) > 0
        and all(it.get("hecho", False) for it in items_actualizados)
    )

    if todos_hechos:
        # Condición explícita en filtro: solo avanza si el estado es activo.
        # Dos requests concurrentes que lleguen aquí solo uno matcheará.
        coleccion_pedidos.update_one(
            {
                "_id": ObjectId(pedido_id),
                "estado": {"$in": ["pendiente", "preparando"]},
            },
            {"$set": {"estado": "listo"}},
        )

    # Auditoría mínima (importante 5)
    logger.info(
        "marcar_item_hecho | sub=%s correo=%s pedido_id=%s item_id=%s hecho=%s todos_hechos=%s",
        current_user.get("sub"), current_user.get("correo"),
        pedido_id, item_id, payload.hecho, todos_hechos,
    )

    return {
        "updated": True,
        "hecho": payload.hecho,
        "todosHechos": todos_hechos,
    }


@router.patch("/{pedido_id}/items/{item_id}/hecho")
def marcar_item_hecho_por_id(
    pedido_id: str,
    item_id: str,
    payload: ActualizarItemHecho,
    current_user: dict = Depends(require_role(["cocinero", "camarero", "admin", "super_admin"])),
):
    """Marca un item de pedido como hecho/no hecho usando su item_id estable.

    El item_id es un UUID generado al crear el pedido; no cambia aunque se
    reordenen los items, lo que evita el bug de índice posicional (importante 4).
    """
    return _marcar_item_hecho_por_id(pedido_id, item_id, payload, current_user)


# TODO: deprecar cuando frontend migre a item_id (usar /items/{item_id}/hecho)
@router.patch("/{pedido_id}/items/{item_idx}/hecho-por-indice")
def marcar_item_hecho(
    pedido_id: str,
    item_idx: int,
    payload: ActualizarItemHecho,
    current_user: dict = Depends(require_role(["cocinero", "camarero", "admin", "super_admin"])),
):
    """[DEPRECATED] Marca un item como hecho usando su índice posicional.

    Usar /items/{item_id}/hecho en su lugar. Este endpoint se mantiene
    temporalmente para retrocompatibilidad con clientes que envían el índice.
    """
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")
    if item_idx < 0:
        raise ValidacionError("Índice de item inválido")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    items = pedido.get("items", [])
    if not isinstance(items, list) or item_idx >= len(items):
        raise ValidacionError(f"Índice de item fuera de rango (0..{max(len(items) - 1, 0)})")

    # Resolución del item_id a partir del índice, si existe
    item_id_from_idx = items[item_idx].get("item_id")
    if item_id_from_idx:
        return _marcar_item_hecho_por_id(pedido_id, item_id_from_idx, payload, current_user)

    # Fallback legacy: el item no tiene item_id (datos anteriores a este cambio)
    coleccion_pedidos.update_one(
        {
            "_id": ObjectId(pedido_id),
            "estado": {"$in": ["pendiente", "preparando", "listo"]},
        },
        {"$set": {f"items.{item_idx}.hecho": payload.hecho}},
    )

    pedido_actualizado = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    items_actualizados = pedido_actualizado.get("items", []) if pedido_actualizado else []
    todos_hechos = (
        len(items_actualizados) > 0
        and all(it.get("hecho", False) for it in items_actualizados)
    )

    if todos_hechos:
        coleccion_pedidos.update_one(
            {
                "_id": ObjectId(pedido_id),
                "estado": {"$in": ["pendiente", "preparando"]},
            },
            {"$set": {"estado": "listo"}},
        )

    logger.info(
        "marcar_item_hecho_legacy | sub=%s correo=%s pedido_id=%s item_idx=%s hecho=%s",
        current_user.get("sub"), current_user.get("correo"),
        pedido_id, item_idx, payload.hecho,
    )

    return {
        "updated": True,
        "hecho": payload.hecho,
        "todosHechos": todos_hechos,
    }


@router.patch("/{pedido_id}")
def actualizar_pedido(
    pedido_id: str,
    payload: ActualizarItemsPedido,
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    campos = {}
    if payload.items is not None:
        campos["items"] = payload.items
    if payload.total is not None:
        campos["total"] = payload.total
    if payload.estadoPago is not None:
        campos["estado_pago"] = payload.estadoPago
    if payload.estado is not None:
        campos["estado"] = payload.estado
    if payload.metodoPago is not None:
        campos["metodo_pago"] = payload.metodoPago

    if not campos:
        return {"updated": False}

    result = coleccion_pedidos.update_one(
        {"_id": ObjectId(pedido_id)},
        {"$set": campos},
    )

    if result.matched_count == 0:
        raise NotFoundError("Pedido no encontrado")

    return {"updated": result.modified_count > 0}



def _normalizar_fecha_query(valor: str, fin_de_dia: bool) -> str:
    """Acepta YYYY-MM-DD o ISO completo. Si solo viene fecha, devuelve
    'T00:00:00' o 'T23:59:59' según fin_de_dia. Lanza ValidacionError si
    el formato es inválido."""
    valor = valor.strip()
    # Intentar parsear con fromisoformat para validar
    try:
        datetime.fromisoformat(valor)
    except ValueError:
        raise ValidacionError(
            f"Fecha inválida: '{valor}'. Use formato YYYY-MM-DD o ISO 8601 completo."
        )
    # Si solo viene fecha (sin hora), extender con hora según fin_de_dia
    if len(valor) == 10:
        sufijo = "T23:59:59" if fin_de_dia else "T00:00:00"
        return valor + sufijo
    # Si llega con hora explícita, respetarla tal cual
    return valor


# ── Estados que representan ventas reales (contabilidad) ─────────────────────
# "listo" equivale a servido en este proyecto ("entregado" no se usa como
# estado final en el flujo actual, pero lo incluimos por si se añade).
_ESTADOS_VENTA = {"listo", "entregado"}

# Límite máximo de días permitido en export para evitar OOM
_MAX_DIAS_EXPORT = 90


def _construir_filtro_contabilidad(
    fecha_desde: Optional[str],
    fecha_hasta: Optional[str],
    restaurante_id: Optional[str],
    current_user: dict,
) -> dict:
    """Devuelve el filtro Mongo para los endpoints de contabilidad.

    Aplica aislamiento igual que GET /pedidos: el admin usa su propio
    restaurante_id del JWT; el super_admin puede recibir uno por query.
    """
    rol = normalizar_rol(current_user.get("rol", ""))
    filtro: dict = {"estado": {"$in": list(_ESTADOS_VENTA)}}

    # Aislamiento por sucursal
    if rol == "super_admin":
        # El super_admin puede filtrar por restaurante_id explícito
        rid = restaurante_id
    else:
        # Admin (y cualquier otro rol de personal): usa el del JWT, ignora el query
        rid = current_user.get("restaurante_id")

    if rid:
        filtro["$or"] = [
            {"restaurante_id": rid},
            {"restaurante_id": {"$exists": False}},
        ]

    # Filtro temporal
    rango_fecha: dict = {}
    if fecha_desde:
        rango_fecha["$gte"] = _normalizar_fecha_query(fecha_desde, fin_de_dia=False)
    if fecha_hasta:
        rango_fecha["$lte"] = _normalizar_fecha_query(fecha_hasta, fin_de_dia=True)
    if rango_fecha:
        filtro["fecha"] = rango_fecha

    return filtro


@router.get("/resumen")
def obtener_resumen_pedidos(
    fecha_desde: Optional[str] = Query(None),
    fecha_hasta: Optional[str] = Query(None),
    restaurante_id: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user),
):
    """Devuelve agregados de contabilidad: totales, por día, por método de
    pago, por tipo de entrega y top 10 productos más vendidos.

    Solo cuenta pedidos en estado 'listo' o 'entregado' (ventas reales).
    El cálculo se hace en Python sobre el cursor para máxima compatibilidad
    con mongomock y volúmenes típicos de cientos de pedidos por sucursal/mes.
    """
    filtro = _construir_filtro_contabilidad(
        fecha_desde, fecha_hasta, restaurante_id, current_user
    )

    pedidos = list(coleccion_pedidos.find(filtro))

    # Acumuladores
    total_ingresos = 0.0
    total_pedidos = 0
    total_items = 0

    # Clave: "YYYY-MM-DD", valor: {"ingresos": float, "pedidos": int}
    por_dia: dict[str, dict] = {}

    # Clave: método de pago, valor: {"ingresos": float, "pedidos": int}
    por_metodo: dict[str, dict] = {}

    # Clave: tipo de entrega, valor: {"ingresos": float, "pedidos": int}
    por_tipo: dict[str, dict] = {}

    # Clave: (producto_id o nombre), valor: {"nombre": str, "unidades": int, "ingresos": float}
    productos: dict[str, dict] = {}

    for p in pedidos:
        total_pedido = float(p.get("total", 0))
        fecha_raw = p.get("fecha", "")
        # Normalizamos a minúsculas + strip para evitar duplicados
        # ("Efectivo" y "efectivo" deben agruparse en la misma card).
        metodo_raw = p.get("metodo_pago") or "desconocido"
        metodo = (
            metodo_raw.strip().lower()
            if isinstance(metodo_raw, str) and metodo_raw.strip()
            else "desconocido"
        )
        tipo_raw = p.get("tipo_entrega") or "local"
        tipo = (
            tipo_raw.strip().lower()
            if isinstance(tipo_raw, str) and tipo_raw.strip()
            else "local"
        )
        items_doc = p.get("items", [])
        if not isinstance(items_doc, list):
            items_doc = []

        # Contar solo items con cantidad > 0 y precio > 0
        items_validos = [
            it for it in items_doc
            if isinstance(it, dict)
            and it.get("cantidad", 0) > 0
            and it.get("precio", 0) > 0
        ]
        n_items = sum(int(it.get("cantidad", 0)) for it in items_validos)

        total_ingresos += total_pedido
        total_pedidos += 1
        total_items += n_items

        # Agrupación por día (extrae YYYY-MM-DD del string ISO)
        dia = fecha_raw[:10] if len(fecha_raw) >= 10 else "desconocido"
        if dia not in por_dia:
            por_dia[dia] = {"fecha": dia, "ingresos": 0.0, "pedidos": 0}
        por_dia[dia]["ingresos"] += total_pedido
        por_dia[dia]["pedidos"] += 1

        # Agrupación por método de pago
        if metodo not in por_metodo:
            por_metodo[metodo] = {"metodo": metodo, "ingresos": 0.0, "pedidos": 0}
        por_metodo[metodo]["ingresos"] += total_pedido
        por_metodo[metodo]["pedidos"] += 1

        # Agrupación por tipo de entrega
        if tipo not in por_tipo:
            por_tipo[tipo] = {"tipo": tipo, "ingresos": 0.0, "pedidos": 0}
        por_tipo[tipo]["ingresos"] += total_pedido
        por_tipo[tipo]["pedidos"] += 1

        # Agrupación de productos
        for it in items_validos:
            pid = str(it.get("producto_id", "")).strip()
            nombre = it.get("nombre") or it.get("producto_nombre") or "Desconocido"
            # Prefiere agrupar por producto_id si existe; si no, por nombre
            clave = pid if pid else nombre
            cant = int(it.get("cantidad", 0))
            ingreso_item = float(it.get("precio", 0)) * cant
            if clave not in productos:
                productos[clave] = {"producto_id": pid or None, "nombre": nombre, "unidades": 0, "ingresos": 0.0}
            productos[clave]["unidades"] += cant
            productos[clave]["ingresos"] += ingreso_item

    # Ticket medio
    ticket_medio = round(total_ingresos / total_pedidos, 2) if total_pedidos > 0 else 0.0

    # Porcentajes por método de pago — devolvemos el label canónico
    # (_ETIQUETA_PAGO) para que la UI muestre "Efectivo" / "Tarjeta" siempre
    # igual, independientemente de cómo esté guardado en BBDD legacy.
    lista_metodos = []
    for v in por_metodo.values():
        pct = round(v["pedidos"] / total_pedidos * 100, 1) if total_pedidos > 0 else 0.0
        clave = v["metodo"]
        label = _ETIQUETA_PAGO.get(clave, clave.capitalize())
        lista_metodos.append({
            "metodo": label,
            "ingresos": round(v["ingresos"], 2),
            "pedidos": v["pedidos"],
            "porcentaje": pct,
        })

    # Top 10 productos ordenados desc por unidades
    top_productos = sorted(productos.values(), key=lambda x: x["unidades"], reverse=True)[:10]
    for tp in top_productos:
        tp["ingresos"] = round(tp["ingresos"], 2)

    return {
        "totales": {
            "ingresos": round(total_ingresos, 2),
            "pedidos": total_pedidos,
            "ticket_medio": ticket_medio,
            "items_vendidos": total_items,
        },
        "por_dia": sorted(
            [{"fecha": v["fecha"], "ingresos": round(v["ingresos"], 2), "pedidos": v["pedidos"]}
             for v in por_dia.values()],
            key=lambda x: x["fecha"],
        ),
        "por_metodo_pago": lista_metodos,
        "por_tipo_entrega": [
            {"tipo": v["tipo"], "ingresos": round(v["ingresos"], 2), "pedidos": v["pedidos"]}
            for v in por_tipo.values()
        ],
        "top_productos": top_productos,
    }


@router.get("/exportar")
def exportar_pedidos(
    fecha_desde: Optional[str] = Query(None),
    fecha_hasta: Optional[str] = Query(None),
    restaurante_id: Optional[str] = Query(None),
    formato: str = Query("csv", pattern="^(csv|pdf)$"),
    current_user: dict = Depends(get_current_user),
):
    """Exporta el listado de pedidos en CSV o PDF.

    Restricciones:
    - Rango máximo de 90 días (evita OOM con volúmenes grandes).
    - Misma lógica de aislamiento que GET /pedidos/resumen.
    - PDF devuelve 501 porque reportlab no está instalado.
    """
    # Validar rango máximo de 90 días si se proporcionan ambas fechas
    if fecha_desde and fecha_hasta:
        try:
            dt_desde = datetime.fromisoformat(fecha_desde.strip()[:10])
            dt_hasta = datetime.fromisoformat(fecha_hasta.strip()[:10])
        except ValueError:
            # _construir_filtro_contabilidad llamará a _normalizar_fecha_query
            # y lanzará ValidacionError con mensaje apropiado
            dt_desde = dt_hasta = None

        if dt_desde and dt_hasta:
            delta = (dt_hasta - dt_desde).days
            if delta > _MAX_DIAS_EXPORT:
                raise ValidacionError(
                    f"Reduce el rango a {_MAX_DIAS_EXPORT} días o menos "
                    f"(solicitado: {delta} días)."
                )

    if formato == "pdf":
        # reportlab no está instalado; devolvemos 501 claro
        raise HTTPException(
            status_code=501,
            detail=(
                "El backend no tiene biblioteca PDF disponible. "
                "Solicita instalar reportlab (pip install reportlab) "
                "y añadirlo a requirements.txt."
            ),
        )

    # Construir filtro con los mismos criterios que el resumen
    filtro = _construir_filtro_contabilidad(
        fecha_desde, fecha_hasta, restaurante_id, current_user
    )
    pedidos = list(coleccion_pedidos.find(filtro))

    # Determinar nombre de archivo
    rid_label = (
        current_user.get("restaurante_id")
        or restaurante_id
        or "todos"
    )
    desde_label = fecha_desde or "inicio"
    hasta_label = fecha_hasta or "fin"
    filename = f"contabilidad_{rid_label}_{desde_label}_{hasta_label}.csv"

    # Generar CSV en memoria (RFC 4180).
    # Delimitador `;`: Excel en es-ES usa `,` como decimal, así que el
    # separador esperado para autorrellenar columnas es el punto y coma.
    output = io.StringIO()
    writer = csv.writer(output, delimiter=";", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(
        ["fecha", "id", "total", "metodo_pago", "tipo_entrega", "estado", "items"]
    )

    for p in pedidos:
        items_raw = p.get("items", [])
        n_items = len(items_raw) if isinstance(items_raw, list) else 0

        # Fecha legible dd/mm/yyyy HH:MM (Excel la entiende como datetime ES)
        fecha_raw = p.get("fecha", "") or ""
        try:
            fecha_fmt = datetime.fromisoformat(fecha_raw).strftime("%d/%m/%Y %H:%M")
        except (ValueError, TypeError):
            fecha_fmt = fecha_raw

        # Normalizar método de pago y tipo de entrega al label canónico
        metodo_raw = (p.get("metodo_pago") or "").strip().lower()
        metodo_label = _ETIQUETA_PAGO.get(metodo_raw, metodo_raw.capitalize())
        tipo_raw = (p.get("tipo_entrega") or "").strip().lower()
        tipo_label = _ETIQUETA_ENTREGA.get(tipo_raw, tipo_raw.capitalize())

        # Total con coma decimal (formato es-ES) — Excel en es-ES lo parsea
        # como número directo cuando se combina con delimitador `;`.
        total_raw = p.get("total", 0) or 0
        try:
            total_fmt = f"{float(total_raw):.2f}".replace(".", ",")
        except (ValueError, TypeError):
            total_fmt = str(total_raw)

        writer.writerow([
            fecha_fmt,
            str(p["_id"]),
            total_fmt,
            metodo_label,
            tipo_label,
            p.get("estado", ""),
            n_items,
        ])

    output.seek(0)
    # Codificar a bytes con BOM UTF-8 para compatibilidad con Excel
    contenido = output.getvalue().encode("utf-8-sig")

    return StreamingResponse(
        io.BytesIO(contenido),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("")
def obtener_pedidos(
    userId: Optional[str] = Query(None),
    mesaId: Optional[str] = Query(None),
    estadoPago: Optional[str] = Query(None),
    restauranteId: Optional[str] = Query(None),
    estado: Optional[str] = Query(None),
    # Filtro multi-estado en CSV: ?estados=pendiente,preparando,listo
    # Cuando se envía, tiene prioridad sobre ?estado (parámetro individual).
    estados: Optional[str] = Query(None),
    # Filtros temporales: ISO 8601 (YYYY-MM-DD o con hora)
    fecha_desde: Optional[str] = Query(None),
    fecha_hasta: Optional[str] = Query(None),
    # Límite de resultados: None = sin límite (compatibilidad). Con límite,
    # se ordena descendente para devolver los N más recientes.
    limit: Optional[int] = Query(None, ge=1, le=1000),
    current_user: dict = Depends(get_current_user),
):
    rol = normalizar_rol(current_user.get("rol", ""))

    # ── Aislamiento por rol ───────────────────────────────────────────────────
    if rol == "cliente":
        # Un cliente solo puede ver sus propios pedidos, independientemente de
        # lo que llegue en ?userId. El sub del JWT es la fuente de verdad.
        userId = current_user["sub"]
        restauranteId = None  # un cliente no filtra por sucursal
    else:
        # Personal: si el JWT lleva restaurante_id, restringimos a esa sucursal
        # salvo que sea super_admin (puede ver todas las sucursales).
        # NOTA: si en el futuro el JWT no incluyera restaurante_id para algún
        # rol de personal legacy, simplemente no se aplica la restricción aquí
        # y se loguea un aviso para que quede trazabilidad.
        jwt_restaurante = current_user.get("restaurante_id")
        if rol != "super_admin":
            if jwt_restaurante:
                restauranteId = jwt_restaurante
            else:
                logger.warning(
                    "obtener_pedidos: usuario personal sin restaurante_id en JWT "
                    "(rol=%s sub=%s). No se aplica restricción por sucursal.",
                    rol, current_user.get("sub"),
                )

    # ── Validar y resolver filtro de estado(s) ────────────────────────────────
    estados_filtro: Optional[list[str]] = None

    if estados:
        # CSV → lista; quitamos blancos alrededor de cada token.
        lista = [s.strip() for s in estados.split(",") if s.strip()]
        invalidos = [s for s in lista if s not in _ESTADOS_VALIDOS]
        if invalidos:
            raise ValidacionError(
                f"Estado(s) inválido(s): {invalidos}. Válidos: {sorted(_ESTADOS_VALIDOS)}"
            )
        estados_filtro = lista
    elif estado:
        if estado not in _ESTADOS_VALIDOS:
            raise ValidacionError(
                f"Estado inválido: '{estado}'. Válidos: {sorted(_ESTADOS_VALIDOS)}"
            )
        estados_filtro = [estado]

    # ── Construir filtro Mongo ────────────────────────────────────────────────
    filtro: dict = {}

    if userId:
        filtro["usuario_id"] = userId
    if mesaId:
        filtro["mesa_id"] = mesaId
    if estadoPago:
        filtro["estado_pago"] = estadoPago
    if restauranteId:
        # Retrocompatibilidad: incluir pedidos sin restaurante_id (legacy)
        filtro["$or"] = [
            {"restaurante_id": restauranteId},
            {"restaurante_id": {"$exists": False}},
        ]
    if estados_filtro:
        if len(estados_filtro) == 1:
            filtro["estado"] = estados_filtro[0]
        else:
            filtro["estado"] = {"$in": estados_filtro}

    # ── Filtros temporales ────────────────────────────────────────────────────
    # El campo "fecha" se guarda como string ISO 8601, que es lexicográficamente
    # ordenable, por lo que la comparación $gte/$lte funciona correctamente sin
    # necesidad de convertir a datetime.
    rango_fecha: dict = {}
    if fecha_desde:
        rango_fecha["$gte"] = _normalizar_fecha_query(fecha_desde, fin_de_dia=False)
    if fecha_hasta:
        rango_fecha["$lte"] = _normalizar_fecha_query(fecha_hasta, fin_de_dia=True)
    if rango_fecha:
        filtro["fecha"] = rango_fecha

    cursor = coleccion_pedidos.find(filtro)
    # Con limit aplicamos orden descendente para que el caller reciba los N más recientes
    if limit is not None:
        cursor = cursor.sort("fecha", -1).limit(limit)
    pedidos = cursor
    resultado = []
    for p in pedidos:
        items_raw = p.get("items", [])
        resultado.append({
            "id": str(p["_id"]),
            "fecha": p.get("fecha", ""),
            "total": p.get("total", 0),
            "estado": p.get("estado", "pendiente"),
            "estadoPago": p.get("estado_pago", "pendiente"),
            "items": len(items_raw) if isinstance(items_raw, list) else items_raw,
            "productos": items_raw if isinstance(items_raw, list) else [],
            "tipoEntrega": p.get("tipo_entrega", ""),
            "metodoPago": p.get("metodo_pago", ""),
            "direccion": p.get("direccion_entrega", ""),
            "mesaId": p.get("mesa_id"),
            "numeroMesa": p.get("numero_mesa"),
            "notas": p.get("notas", ""),
            "restauranteId": str(p["restaurante_id"]) if p.get("restaurante_id") else None,
        })
    return resultado



@router.get("/{pedido_id}")
def obtener_pedido(
    pedido_id: str,
    current_user: dict = Depends(get_current_user),
):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")
    p = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(p, current_user)
    items_raw = p.get("items", [])
    return {
        "id": str(p["_id"]),
        "fecha": p.get("fecha", ""),
        "total": p.get("total", 0),
        "estado": p.get("estado", "pendiente"),
        "estadoPago": p.get("estado_pago", "pendiente"),
        "items": len(items_raw) if isinstance(items_raw, list) else items_raw,
        "productos": items_raw if isinstance(items_raw, list) else [],
        "tipoEntrega": p.get("tipo_entrega", ""),
        "metodoPago": p.get("metodo_pago", ""),
        "direccion": p.get("direccion_entrega", ""),
        "mesaId": p.get("mesa_id"),
        "numeroMesa": p.get("numero_mesa"),
        "notas": p.get("notas", ""),
    }


@router.patch("/{pedido_id}/items")
def actualizar_items_pedido(
    pedido_id: str,
    payload: ActualizarItemsPedido,
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    total = payload.total if payload.total is not None else sum(
        it.get("cantidad", 1) * it.get("precio", 0) for it in payload.items
    )

    coleccion_pedidos.update_one(
        {"_id": ObjectId(pedido_id)},
        {"$set": {"items": payload.items, "total": total}},
    )

    return {
        "id": pedido_id,
        "items": payload.items,
        "total": total,
    }
