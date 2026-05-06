from fastapi import APIRouter, Depends, HTTPException, Query
from exceptions import AppError, NotFoundError, ConflictError, ValidacionError
from datetime import datetime, timezone
from bson import ObjectId
from bson.errors import InvalidId
from fastapi_mail import FastMail, MessageSchema, MessageType
from pydantic import BaseModel
from typing import Optional
import logging
from pymongo.errors import OperationFailure

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
    referenciaPago: str
    estadoPago: str = "pagado"


class ActualizarItemsPedido(BaseModel):
    items: Optional[list[dict]] = None
    total: Optional[float] = None
    estadoPago: Optional[str] = None
    estado: Optional[str] = None
    metodoPago: Optional[str] = None


class ActualizarEstado(BaseModel):
    estado: str


class ActualizarItemHecho(BaseModel):
    hecho: bool


_ESTADOS_VALIDOS = {"pendiente", "preparando", "listo", "entregado", "cancelado"}


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("")
async def crear_pedido(pedido: PedidoCrear):
    items_dict = [item.model_dump() for item in pedido.items]

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

    pedido_dict = {
        "usuario_id": pedido.userId,
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
    except OperationFailure as e:
        # MongoDB standalone no soporta transacciones: fallback a operaciones atómicas por documento
        if "Transaction numbers are only allowed" in str(e) or e.code == 20:
            logger.warning("MongoDB standalone detectado: usando actualizaciones atómicas sin transacción")
            _descontar_stock(items_dict, restaurante_id=rid_pedido)
            resultado = coleccion_pedidos.insert_one(pedido_dict)
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
def actualizar_estado_pago(payload: ActualizarEstadoPago):
    result = coleccion_pedidos.update_one(
        {"referencia_pago": payload.referenciaPago},
        {"$set": {"estado_pago": payload.estadoPago}},
    )
    if result.matched_count == 0:
        raise NotFoundError("Pedido no encontrado con esa referencia de pago")
    return {"updated": result.modified_count > 0}


@router.patch("/{pedido_id}/estado")
def actualizar_estado_pedido(
    pedido_id: str,
    payload: ActualizarEstado,
    _user: dict = Depends(require_role(["cocinero", "camarero", "admin", "super_admin"])),
):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")
    if payload.estado not in _ESTADOS_VALIDOS:
        raise ValidacionError(f"Estado inválido. Válidos: {_ESTADOS_VALIDOS}")

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
    return {"updated": result.modified_count > 0, "estado": payload.estado}


@router.patch("/{pedido_id}/items/{item_idx}/hecho")
def marcar_item_hecho(
    pedido_id: str,
    item_idx: int,
    payload: ActualizarItemHecho,
    _user: dict = Depends(require_role(["cocinero", "camarero", "admin", "super_admin"])),
):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")
    if item_idx < 0:
        raise ValidacionError("Índice de item inválido")

    pedido = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    if not pedido:
        raise NotFoundError("Pedido no encontrado")

    items = pedido.get("items", [])
    if not isinstance(items, list) or item_idx >= len(items):
        raise ValidacionError(f"Índice de item fuera de rango (0..{len(items) - 1})")

    coleccion_pedidos.update_one(
        {"_id": ObjectId(pedido_id)},
        {"$set": {f"items.{item_idx}.hecho": payload.hecho}},
    )

    pedido_actualizado = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    items_actualizados = pedido_actualizado.get("items", [])
    todos_hechos = (
        len(items_actualizados) > 0
        and all(it.get("hecho", False) for it in items_actualizados)
    )

    if todos_hechos and pedido_actualizado.get("estado") in {"pendiente", "preparando"}:
        coleccion_pedidos.update_one(
            {"_id": ObjectId(pedido_id)},
            {"$set": {"estado": "listo"}},
        )

    return {
        "updated": True,
        "hecho": payload.hecho,
        "todosHechos": todos_hechos,
    }


@router.patch("/{pedido_id}")
def actualizar_pedido(pedido_id: str, payload: ActualizarItemsPedido):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

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
def obtener_pedido(pedido_id: str):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")
    p = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    if not p:
        raise NotFoundError("Pedido no encontrado")
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
def actualizar_items_pedido(pedido_id: str, payload: ActualizarItemsPedido):
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    pedido = coleccion_pedidos.find_one({"_id": ObjectId(pedido_id)})
    if not pedido:
        raise NotFoundError("Pedido no encontrado")

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
