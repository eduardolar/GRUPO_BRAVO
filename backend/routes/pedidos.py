# ============================================================================
# backend/routes/pedidos.py
# ----------------------------------------------------------------------------
# Endpoints para crear, consultar y operar pedidos. Es el módulo MÁS
# transversal del backend: toca productos (stock), ingredientes (descuento),
# pagos (estadoPago), cocina (timeline de items) y usuarios (puntos).
#
# Flujos principales:
#
#   POST /pedidos
#     1) Valida (Pydantic + reglas: stock disponible, mesa libre, etc.).
#     2) Inicia una TRANSACCIÓN MongoDB (atomicidad: si falla algo a la
#        mitad, NADA queda persistido — sin pedidos huérfanos ni stock
#        descontado por error).
#     3) Inserta el pedido con estado "pendiente" + descuenta stock.
#     4) Si metodoPago=stripe → marca estado_pago="pendiente" y deja al
#        endpoint de pagos crear el Checkout Session.
#     5) Si metodoPago=efectivo → pedido aceptado y enviado a cocina.
#
#   GET /pedidos/server-time → sincronización de cronómetros con cliente.
#
#   GET /pedidos/activos → lista en tiempo real para cocina/camarero.
#
#   PATCH /pedidos/{id}/items/{idx}/hecho → cocina marca item como listo.
#
# Helpers clave:
#   - _descontar_stock: resta ingredientes por sucursal (ver MEMORIA
#     "BBDD de Grupo Bravo contiene datos de pruebas").
#   - Idempotencia: header `Idempotency-Key` evita pedidos duplicados si
#     el cliente reintenta la petición tras un timeout.
# ============================================================================
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from fastapi.responses import StreamingResponse
from exceptions import AppError, NotFoundError, ConflictError, ValidacionError
from datetime import datetime, timezone, timedelta
from bson import ObjectId
from bson.errors import InvalidId
from fastapi_mail import FastMail, MessageSchema, MessageType
from pydantic import BaseModel, ConfigDict, Field
from typing import Optional
import csv
import io
import logging
import uuid
from pymongo.errors import DuplicateKeyError, OperationFailure

from database import coleccion_pedidos, coleccion_productos, coleccion_ingredientes, coleccion_usuarios, cliente
from models import PedidoCrear, MetodoPago
from routes.auth import conf
from security import require_role, get_current_user, normalizar_rol
from limiter import limiter
import audit_general as ag

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
    # Método de pago empleado al cobrar manualmente (efectivo/tarjeta_fisica).
    # Obligatorio cuando camarero/admin marca pagado directamente.
    metodoPago: Optional[str] = None


class ActualizarItemsPedido(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: Optional[list[dict]] = None
    total: Optional[float] = None
    estadoPago: Optional[str] = None
    estado: Optional[str] = None
    metodoPago: Optional[str] = None
    version: Optional[int] = None
    # Fix 2 — motivo obligatorio cuando se cancela un pedido
    motivo_cancelacion: Optional[str] = None
    # Fase 2 — descuento y propina aplicados al cobrar manualmente.
    # Ambos en € (no porcentaje: el frontend ya hace el cálculo).
    # `descuento` no puede superar el subtotal del pedido.
    descuento: Optional[float] = Field(default=None, ge=0)
    propina: Optional[float] = Field(default=None, ge=0)
    # Fase 4 — destacar pedido urgente para cocina.
    prioritario: Optional[bool] = None


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
        "version": pedido_doc.get("version", 1),
        "prioritario": bool(pedido_doc.get("prioritario", False)),
    }


@router.post("")
@limiter.limit("20/minute")
async def crear_pedido(
    request: Request,
    pedido: PedidoCrear,
    current_user: dict = Depends(get_current_user),
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    # ── 1. RESOLUCIÓN SEGURA DEL ID DEL CLIENTE (Bugs #8 y #9) ──
    rol_actor = normalizar_rol(current_user.get("rol", ""))
    uid_cliente = None
    
    if rol_actor == "cliente":
        uid_cliente = ObjectId(current_user["sub"])
    else:
        # Si es staff (camarero/admin), el cliente es el indicado en el body
        if pedido.userId and ObjectId.is_valid(pedido.userId):
            uid_temp = ObjectId(pedido.userId)
            # Validamos que el destinatario sea realmente un cliente
            target = coleccion_usuarios.find_one({"_id": uid_temp})
            if target and normalizar_rol(target.get("rol", "")) == "cliente":
                uid_cliente = uid_temp

    # ── 2. PREPARACIÓN DE ITEMS Y CÁLCULO BASE (Bug #5) ──
    items_dict = [item.model_dump() for item in pedido.items]
    total_articulos = 0.0

    for item in items_dict:
        if not item.get("item_id"):
            item["item_id"] = str(uuid.uuid4())
        
        pid = item.get("producto_id", "")
        try:
            producto_db = coleccion_productos.find_one({"_id": ObjectId(pid)}) if pid else None
        except:
            producto_db = None
            
        if not producto_db:
            raise NotFoundError(f"Producto no encontrado: {pid}")
            
        precio_real = float(producto_db.get("precio", 0))
        item["precio"] = precio_real
        total_articulos += precio_real * item["cantidad"]

        # Marcar bebidas como hechas (no pasan por cocina)
        if str(producto_db.get("categoria", "")).lower().strip() == "bebidas":
            item["hecho"] = True

    # Calcular total incluyendo envío (Bug #5)
    # Nota: Asegúrate de que este valor coincida con el del frontend (_kCosteEnvio)
    coste_envio = 2.50 if pedido.tipoEntrega == TipoEntrega.domicilio else 0.0
    total_antes_de_puntos = total_articulos + coste_envio
    # (Si implementas cupones en el futuro, se restarían aquí antes de los puntos)

    # ── 3. CANJE ATÓMICO DE PUNTOS (Bugs #2, #3 y #6) ──
    puntos_usados = getattr(pedido, "puntosUsados", 0)
    descuento_por_puntos = 0.0

    if puntos_usados > 0:
        if not uid_cliente:
            raise ValidacionError("Se requieren puntos pero no se identificó un cliente válido")

        # Operación ATÓMICA: Filtramos por ID y por tener puntos suficientes
        # Esto evita que dos pedidos descuenten puntos al mismo tiempo (Race Condition)
        resultado_resta = coleccion_usuarios.update_one(
            {"_id": uid_cliente, "puntos": {"$gte": puntos_usados}},
            {"$inc": {"puntos": -puntos_usados}}
        )
        
        if resultado_resta.modified_count == 0:
            raise ValidacionError("Puntos insuficientes o error en la cuenta de fidelización")
            
        descuento_por_puntos = puntos_usados / 10.0
        logger.info(f"Usuario {uid_cliente} canjeó {puntos_usados} puntos (-{descuento_por_puntos}€)")

    # Total final que se guardará en el pedido
    total_final_pedido = max(0.0, total_antes_de_puntos - descuento_por_puntos)

    # ── 4. CREACIÓN DEL PEDIDO EN BASE DE DATOS ──
    nuevo_pedido = {
        "userId": str(uid_cliente) if uid_cliente else pedido.userId,
        "items": items_dict,
        "total": total_final_pedido,
        "tipoEntrega": pedido.tipoEntrega,
        "metodoPago": pedido.metodoPago,
        "direccionEntrega": pedido.direccionEntrega,
        "mesaId": pedido.mesaId,
        "numeroMesa": pedido.numeroMesa,
        "notas": pedido.notas,
        "estado": "recibido",
        "estadoPago": pedido.estadoPago,
        "referenciaPago": pedido.referenciaPago,
        "restauranteId": pedido.restauranteId,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "puntosUsados": puntos_usados,
        "descuentoAplicado": descuento_por_puntos
    }

    try:
        resultado = coleccion_pedidos.insert_one(nuevo_pedido)
        nuevo_pedido_id = str(resultado.inserted_id)
    except Exception as e:
        # Si falla la creación del pedido, deberíamos devolver los puntos (Rollback manual)
        if puntos_usados > 0 and uid_cliente:
            coleccion_usuarios.update_one({"_id": uid_cliente}, {"$inc": {"puntos": puntos_usados}})
        raise HTTPException(status_code=500, detail=f"Error al crear el pedido: {e}")

    # ── 5. SUMA DE PUNTOS POR COMPRA (Bugs #4 y #10) ──
    # Solo sumamos puntos si el pago NO es un "pendiente" de pasarela externa (Stripe/PayPal)
    estado_pago_lower = str(pedido.estadoPago or "").lower()
    es_pago_pendiente_externo = "stripe" in estado_pago_lower or "paypal" in estado_pago_lower
    
    if uid_cliente and not es_pago_pendiente_externo:
        # Bug #10: Usamos round() para redondear al entero más cercano (9.99€ -> 10 puntos)
        puntos_ganados = int(round(total_final_pedido))
        if puntos_ganados > 0:
            coleccion_usuarios.update_one(
                {"_id": uid_cliente},
                {"$inc": {"puntos": puntos_ganados}}
            )
            logger.info(f"Usuario {uid_cliente} ganó {puntos_ganados} puntos por su compra")

    return {
        "id": nuevo_pedido_id,
        "mensaje": "Pedido creado con éxito",
        "total": total_final_pedido
    }
    # ────────────────────────────────────────────────────────────────
    # Para clientes, ignorar userId del payload y usar el sub del JWT.
    # Admin y personal de sala/cocina pueden crear pedidos en nombre de cualquier usuario.
    # Si el staff no identifica al cliente (pedido en sala / recoger / domicilio
    # sin alta) aceptamos `userId` ausente o el literal histórico "TRABAJADOR"
    # y persistimos el sub del propio actor para trazabilidad por trabajador.
    rol_actor = normalizar_rol(current_user.get("rol", ""))
    if rol_actor == "cliente":
        usuario_id_pedido = current_user["sub"]
    else:
        uid_payload = (pedido.userId or "").strip()
        if not uid_payload or uid_payload.upper() == "TRABAJADOR":
            usuario_id_pedido = current_user.get("sub", "")
        else:
            usuario_id_pedido = uid_payload

    # ── Idempotencia server-side ──────────────────────────────────────────────
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

    # Si TODOS los items vienen marcados `hecho` (caso típico: pedido solo
    # de bebidas), el pedido va directo a `listo`: no hay nada que cocinar.
    # El camarero lo verá listo para entregar sin pasar por la pantalla de
    # cocinero.
    estado_inicial = (
        "listo"
        if items_dict and all(it.get("hecho", False) for it in items_dict)
        else "pendiente"
    )

    pedido_dict = {
        "usuario_id": usuario_id_pedido,
        "items": items_dict,
        "tipo_entrega": _normalizar_tipo_entrega(pedido.tipoEntrega),
        "metodo_pago": pedido.metodoPago,
        "total": total_calculado,
        "notas": pedido.notas,
        "fecha": datetime.now(timezone.utc).isoformat(),
        "estado": estado_inicial,
        "referencia_pago": pedido.referenciaPago,
        "estado_pago": pedido.estadoPago or "pendiente",
        "prioritario": bool(pedido.prioritario),
        # Responsable inicial = quien crea. Cambia con /transferir.
        "responsable_sub": current_user.get("sub"),
        "responsable_correo": current_user.get("correo"),
        # Auditoría de creación: sub/correo/rol del actor que abrió el pedido
        "creado_por_sub": current_user.get("sub"),
        "creado_por_correo": current_user.get("correo"),
        "creado_por_rol": normalizar_rol(current_user.get("rol", "")),
        "version": 1,
    }

    if idempotency_key and idempotency_key.strip():
        pedido_dict["idempotency_key"] = idempotency_key.strip()

    if pedido.direccionEntrega:
        pedido_dict["direccion_entrega"] = pedido.direccionEntrega
    if pedido.mesaId:
        pedido_dict["mesa_id"] = pedido.mesaId
    if pedido.numeroMesa is not None:
        pedido_dict["numero_mesa"] = pedido.numeroMesa

    if rol_actor in {"camarero", "admin"}:
        rid_jwt = current_user.get("restaurante_id")
        if not rid_jwt:
            raise HTTPException(
                status_code=400,
                detail="El token no contiene restaurante_id; contacta con soporte",
            )
        rid_pedido = rid_jwt
    elif rol_actor == "super_admin":
        rid_pedido = pedido.restauranteId
    else:
        rid_pedido = pedido.restauranteId

    if rid_pedido:
        pedido_dict["restaurante_id"] = rid_pedido

    resultado = None
    try:
        with cliente.start_session() as session:
            with session.start_transaction():
                _descontar_stock(items_dict, session=session, restaurante_id=rid_pedido)
                resultado = coleccion_pedidos.insert_one(pedido_dict, session=session)
    except AppError:
        raise
    except DuplicateKeyError:
        existing = coleccion_pedidos.find_one(
            {"usuario_id": usuario_id_pedido, "idempotency_key": idempotency_key.strip()}
        )
        if existing:
            items_raw = existing.get("items", [])
            n = len(items_raw) if isinstance(items_raw, list) else 0
            return _pedido_a_respuesta(existing, n)
        raise
    except OperationFailure as e:
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
            raise
    except Exception:
        raise

    pedido_id = str(resultado.inserted_id)

    # ── NUEVO: SISTEMA DE FIDELIZACIÓN ──
    # Si el pedido tiene un usuario asociado, le sumamos los puntos (1€ = 1 Coin)
    if usuario_id_pedido:
        try:
            puntos_a_sumar = int(total_calculado)
            if puntos_a_sumar > 0:
                # Convertimos ID a ObjectId si es necesario
                uid_obj = ObjectId(usuario_id_pedido) if ObjectId.is_valid(usuario_id_pedido) else usuario_id_pedido
                coleccion_usuarios.update_one(
                    {"_id": uid_obj},
                    {"$inc": {"puntos": puntos_a_sumar}}
                )
                logger.info(f"Usuario {usuario_id_pedido} ha ganado {puntos_a_sumar} Bravo Coins.")
        except Exception as e:
            logger.error(f"Error al sumar puntos de fidelidad: {e}")
    # ─────────────────────────────────────────────────────────────────

    # Enviar factura al correo del usuario
    usuario_doc = coleccion_usuarios.find_one({"_id": ObjectId(usuario_id_pedido)}) if ObjectId.is_valid(usuario_id_pedido) else None
    if not usuario_doc:
        usuario_doc = coleccion_usuarios.find_one({"_id": usuario_id_pedido})

    if usuario_doc:
        correo = usuario_doc.get("correo", "")
        if correo and "@" in correo:
            try:
                await _enviar_factura(
                    email_destino=correo,
                    nombre_usuario=usuario_doc.get("nombre", "Cliente"),
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

    Fix 1 — cobro manual: cuando el actor es camarero/admin y marca pagado,
    el método de pago debe ser "efectivo" o "tarjeta_fisica". Los métodos de
    pasarela (stripe, paypal, etc.) solo pueden confirmarse vía webhook;
    si un humano intenta usarlos aquí → 400.
    """
    # Métodos que representan pasarelas de pago online (no deben usarse en cobro manual)
    _METODOS_PASARELA = {"stripe", "paypal", "apple_pay", "applepay", "google_pay", "googlepay"}
    # Métodos válidos para cobro en mano por personal de sala
    _METODOS_COBRO_MANUAL = {"efectivo", "tarjeta_fisica"}

    rol = normalizar_rol(current_user.get("rol", ""))

    filtro: dict = {"referencia_pago": payload.referenciaPago}

    if rol == "cliente":
        # El cliente solo puede actualizar pagos de sus propios pedidos
        filtro["usuario_id"] = current_user["sub"]

    elif rol in {"camarero", "admin"}:
        # Bloqueante 1 — IDOR cross-sucursal: forzar restaurante_id del JWT
        rid = current_user.get("restaurante_id")
        if not rid:
            raise HTTPException(
                status_code=400,
                detail="El token no contiene restaurante_id; contacta con soporte",
            )
        filtro["restaurante_id"] = rid

        # Fix 1 — si el personal marca pagado, exigir método de cobro manual
        if payload.estadoPago == "pagado":
            metodo = (payload.metodoPago or "").strip().lower()
            if metodo in _METODOS_PASARELA:
                raise ValidacionError(
                    "Los pagos por pasarela deben confirmarse vía webhook"
                )
            if metodo not in _METODOS_COBRO_MANUAL:
                raise ValidacionError(
                    f"Para cobro manual el método debe ser uno de: {sorted(_METODOS_COBRO_MANUAL)}"
                )

    elif rol == "super_admin":
        pass  # sin restricción adicional

    else:
        raise HTTPException(
            status_code=403,
            detail="No tienes permiso para esta acción",
        )

    set_fields: dict = {"estado_pago": payload.estadoPago}
    # Auditoría de cobro: cuando la transición es hacia "pagado", registrar quién cobró
    if payload.estadoPago == "pagado":
        # Comprobamos si ya estaba pagado para no sobreescribir cobrado_at en reintentos
        pedido_prev = coleccion_pedidos.find_one(filtro, {"estado_pago": 1, "total": 1})
        if pedido_prev and pedido_prev.get("estado_pago") != "pagado":
            set_fields["cobrado_por_sub"] = current_user.get("sub")
            set_fields["cobrado_por_correo"] = current_user.get("correo")
            set_fields["cobrado_at"] = datetime.now(timezone.utc).isoformat()
            if payload.metodoPago:
                set_fields["metodo_pago"] = payload.metodoPago.strip().lower()
            # Auditoría de cobro manual
            if rol in {"camarero", "admin"}:
                ag.registrar(
                    ag.PEDIDO_COBRADO_MANUAL,
                    actor=current_user.get("sub"),
                    objetivo=str(pedido_prev.get("_id", "")),
                    detalle=f"metodo={payload.metodoPago} total={pedido_prev.get('total')}",
                    extra={"metodo_pago": payload.metodoPago, "total": pedido_prev.get("total")},
                )

    result = coleccion_pedidos.update_one(
        filtro,
        {"$set": set_fields},
    )
    if result.matched_count == 0:
        raise NotFoundError("Pedido no encontrado con esa referencia de pago")

    # Devolvemos el pedido_id para que el frontend pueda navegar a la pantalla
    # de seguimiento usando el ObjectId real (no el session_id de Stripe).
    actualizado = coleccion_pedidos.find_one(filtro, {"_id": 1})
    pedido_id = str(actualizado["_id"]) if actualizado else None
    return {
        "updated": result.modified_count > 0,
        "pedido_id": pedido_id,
    }


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
    Nota: con concurrencia el índice puede apuntar a un item distinto.
    """
    logger.warning(
        "DEPRECATED endpoint hecho-por-indice usado por sub=%s rol=%s pedido=%s. "
        "Migrar el caller a PATCH /items/{item_id}/hecho.",
        current_user.get("sub"),
        normalizar_rol(current_user.get("rol", "")),
        pedido_id,
    )
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

    estado_actual = pedido.get("estado", "pendiente")
    es_terminal = estado_actual in {"entregado", "cancelado"}

    # ── Máquina de estados ────────────────────────────────────────────────────
    if payload.estado is not None:
        if payload.estado not in _ESTADOS_VALIDOS:
            raise ValidacionError(
                f"Estado inválido. Válidos: {sorted(_ESTADOS_VALIDOS)}"
            )
        if payload.estado != estado_actual:
            transiciones_permitidas = _TRANSICIONES_VALIDAS.get(estado_actual, set())
            if payload.estado not in transiciones_permitidas:
                raise ConflictError(
                    f"Transición inválida: '{estado_actual}' → '{payload.estado}'. "
                    f"Desde '{estado_actual}' solo se permite: "
                    f"{sorted(transiciones_permitidas) or '(estado terminal)'}"
                )

        # Fix 2 — cancelación con motivo obligatorio para personal de sala.
        # El motivo queda en el documento y en la auditoría para trazabilidad.
        if payload.estado == "cancelado":
            motivo = (payload.motivo_cancelacion or "").strip()
            if not motivo:
                raise ValidacionError("Debes indicar el motivo de la cancelación")

    # ── Protección de estado terminal ─────────────────────────────────────────
    # En pedidos terminales (entregado/cancelado) solo se permite cambiar
    # estadoPago (ej: post-cobro pendiente → pagado) y, junto con él,
    # metodoPago — porque el cobro manual desde sala registra ambos a la vez
    # (estadoPago=pagado + metodoPago=efectivo|tarjeta_fisica).
    # En cualquier otro caso, metodoPago en estado terminal es manipulación
    # de un registro histórico y se rechaza.
    if es_terminal:
        campos_bloqueados = []
        es_cobro = (
            payload.estadoPago == "pagado"
            and pedido.get("estado_pago") != "pagado"
        )
        if payload.items is not None:
            campos_bloqueados.append("items")
        if payload.total is not None:
            campos_bloqueados.append("total")
        if payload.metodoPago is not None and not es_cobro:
            campos_bloqueados.append("metodoPago")
        if payload.estado is not None and payload.estado != estado_actual:
            campos_bloqueados.append("estado")
        if campos_bloqueados:
            raise ConflictError(
                f"El pedido está en estado terminal '{estado_actual}'. "
                f"No se pueden modificar: {', '.join(campos_bloqueados)}. "
                "Solo se permite actualizar estadoPago."
            )

    # ── Validar metodoPago contra enum ────────────────────────────────────────
    if payload.metodoPago is not None:
        metodos_validos = {m.value for m in MetodoPago}
        if payload.metodoPago not in metodos_validos:
            raise ValidacionError(
                f"metodoPago inválido: '{payload.metodoPago}'. "
                f"Valores válidos: {sorted(metodos_validos)}"
            )

    # ── Defensa en profundidad: cobro manual desde sala ──────────────────────
    # Cuando un camarero/admin marca un pedido como pagado por esta vía
    # (ruta usada por `cerrarPedido` del frontend), debe usar un método
    # físico. Las pasarelas (paypal, stripe…) solo pueden confirmarse vía
    # webhook, nunca por un humano. super_admin queda exento por si necesita
    # corregir un cobro a posteriori.
    _METODOS_PASARELA = {"paypal", "google_pay", "googlepay", "apple_pay", "applepay", "stripe"}
    _METODOS_COBRO_MANUAL = {"efectivo", "tarjeta_fisica"}
    rol_actor = normalizar_rol(current_user.get("rol", ""))
    if (
        payload.estadoPago == "pagado"
        and pedido.get("estado_pago") != "pagado"
        and rol_actor in {"camarero", "admin"}
    ):
        metodo = (payload.metodoPago or "").strip().lower()
        if not metodo:
            raise ValidacionError(
                "Indica el método de pago (efectivo o tarjeta_fisica) al cobrar manualmente"
            )
        if metodo in _METODOS_PASARELA:
            raise ValidacionError(
                "Los pagos por pasarela deben confirmarse vía webhook, no manualmente"
            )
        if metodo not in _METODOS_COBRO_MANUAL:
            raise ValidacionError(
                f"Método de pago manual inválido: '{metodo}'. "
                f"Valores válidos: {sorted(_METODOS_COBRO_MANUAL)}"
            )

    campos = {}
    if payload.items is not None:
        # Defensa: no se pueden quitar/reducir items que el cocinero ya
        # marcó como `hecho=True`. Esos platos ya están en plato y no se
        # pueden devolver al stock. El camarero solo puede AÑADIR items
        # nuevos o aumentar cantidades. Para cancelar, hay que cancelar el
        # pedido entero (estado=cancelado) — auditado.
        items_existentes = pedido.get("items", []) or []
        cantidades_hechas: dict[str, int] = {}
        for ex in items_existentes:
            if not isinstance(ex, dict):
                continue
            if not ex.get("hecho"):
                continue
            pid = str(ex.get("producto_id") or ex.get("item_id") or "")
            if not pid:
                continue
            cantidades_hechas[pid] = (
                cantidades_hechas.get(pid, 0) + int(ex.get("cantidad", 1))
            )
        # Sumamos las cantidades del payload por producto y comparamos.
        cantidades_nuevas: dict[str, int] = {}
        for it in payload.items:
            pid = str(it.get("producto_id") or it.get("item_id") or "")
            if not pid:
                continue
            cantidades_nuevas[pid] = (
                cantidades_nuevas.get(pid, 0) + int(it.get("cantidad", 1))
            )
        for pid, cant_hecha in cantidades_hechas.items():
            cant_nueva = cantidades_nuevas.get(pid, 0)
            if cant_nueva < cant_hecha:
                raise ConflictError(
                    "No se pueden quitar items que la cocina ya ha preparado. "
                    "Si el cliente lo rechaza, cancela el pedido completo "
                    "para dejar constancia del motivo."
                )

        # Recalcular total desde los precios del payload (cantidad * precio por ítem)
        # para no fiarnos del campo total que envíe el cliente.
        total_recalculado = sum(
            float(it.get("precio", 0)) * int(it.get("cantidad", 1))
            for it in payload.items
        )
        campos["items"] = payload.items
        campos["total"] = total_recalculado
    if payload.total is not None and payload.items is None:
        # Si solo viene total (sin items), lo aceptamos tal cual (ej: ajuste manual por admin)
        campos["total"] = payload.total
    if payload.estadoPago is not None:
        campos["estado_pago"] = payload.estadoPago
        # Auditoría de cobro: cuando la transición es hacia "pagado", persistir quién cobró
        if payload.estadoPago == "pagado" and pedido.get("estado_pago") != "pagado":
            campos["cobrado_por_sub"] = current_user.get("sub")
            campos["cobrado_por_correo"] = current_user.get("correo")
            campos["cobrado_at"] = datetime.now(timezone.utc).isoformat()
    if payload.estado is not None:
        campos["estado"] = payload.estado
        # Fix 2 — persistir metadatos de cancelación para trazabilidad
        if payload.estado == "cancelado":
            campos["motivo_cancelacion"] = (payload.motivo_cancelacion or "").strip()
            campos["cancelado_por_sub"] = current_user.get("sub")
            campos["cancelado_por_correo"] = current_user.get("correo")
            campos["cancelado_at"] = datetime.now(timezone.utc).isoformat()
    if payload.metodoPago is not None:
        campos["metodo_pago"] = payload.metodoPago
    if payload.prioritario is not None:
        campos["prioritario"] = bool(payload.prioritario)

    # Fase 2 — descuento y propina aplicados al cobro manual.
    # Validamos que el descuento no supere el subtotal vigente y persistimos
    # el `total_final` cobrado para que la contabilidad lo refleje.
    if payload.descuento is not None or payload.propina is not None:
        # Subtotal de referencia: el total ya recalculado (si vinieron items
        # nuevos) o el actual del pedido.
        subtotal = float(
            campos.get("total")
            if campos.get("total") is not None
            else pedido.get("total", 0)
        )
        descuento = float(payload.descuento or pedido.get("descuento", 0) or 0)
        propina = float(payload.propina or pedido.get("propina", 0) or 0)
        if descuento > subtotal:
            raise ValidacionError(
                f"El descuento ({descuento:.2f} €) no puede superar el subtotal "
                f"({subtotal:.2f} €)"
            )
        if payload.descuento is not None:
            campos["descuento"] = round(descuento, 2)
        if payload.propina is not None:
            campos["propina"] = round(propina, 2)
        campos["total_final"] = round(subtotal - descuento + propina, 2)

    if not campos:
        return {"updated": False}

    # ── Concurrencia optimista con version ────────────────────────────────────
    # Si el cliente envía `version`, el update solo aplica si el documento
    # aún tiene esa versión. Si no coincide → 409 (otro usuario modificó antes).
    # Sin `version` → comportamiento clásico last-writer-wins (compat antigua).
    version_actual = pedido.get("version", 1)
    if payload.version is not None:
        # Cuando se mutan items o estado, incrementar la versión
        if payload.items is not None or payload.estado is not None:
            campos["version"] = payload.version + 1
        filtro_version = {"_id": ObjectId(pedido_id), "version": payload.version}
        result = coleccion_pedidos.update_one(filtro_version, {"$set": campos})
        if result.matched_count == 0:
            raise ConflictError(
                "Conflicto de versión: el pedido fue modificado por otro usuario"
            )
    else:
        # Sin version: comportamiento anterior (last-writer-wins)
        if payload.items is not None or payload.estado is not None:
            campos["version"] = version_actual + 1
        result = coleccion_pedidos.update_one(
            {"_id": ObjectId(pedido_id)},
            {"$set": campos},
        )
        if result.matched_count == 0:
            raise NotFoundError("Pedido no encontrado")

    logger.info(
        "actualizar_pedido | sub=%s correo=%s pedido_id=%s campos=%s",
        current_user.get("sub"), current_user.get("correo"),
        pedido_id, list(campos.keys()),
    )

    # Fix 2 — auditoría de cancelación
    if payload.estado == "cancelado" and result.modified_count > 0:
        ag.registrar(
            ag.PEDIDO_CANCELADO,
            actor=current_user.get("sub"),
            objetivo=pedido_id,
            detalle=campos.get("motivo_cancelacion", ""),
            extra={"motivo": campos.get("motivo_cancelacion")},
        )
        # Si el pedido cancelado era de mesa, liberamos la mesa para que
        # el camarero la pueda volver a ocupar inmediatamente. Sin esto,
        # las mesas se quedaban "ocupadas" para siempre tras cancelar.
        from database import coleccion_mesas as _col_mesas

        mesa_id_pedido = pedido.get("mesa_id")
        if pedido.get("tipo_entrega") == "local" and mesa_id_pedido:
            try:
                _col_mesas.update_one(
                    {"_id": ObjectId(mesa_id_pedido)},
                    {"$set": {"estado": "libre"}},
                )
            except Exception:
                logger.warning(
                    "No se pudo liberar mesa %s tras cancelar pedido %s",
                    mesa_id_pedido, pedido_id,
                )

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
        # Admin (y cualquier otro rol de personal): usa el del JWT, ignora el query.
        # Si no hay restaurante_id en el JWT, rechazamos para evitar devolver
        # totales globales a una cuenta mal configurada.
        rid = current_user.get("restaurante_id")
        if not rid:
            logger.warning(
                "_construir_filtro_contabilidad: usuario personal sin restaurante_id "
                "en JWT (rol=%s sub=%s). Rechazando request.",
                rol, current_user.get("sub"),
            )
            raise HTTPException(
                status_code=400,
                detail="Tu cuenta no está asignada a una sucursal",
            )

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


@router.get(
    "/mi-turno",
    summary="Estadísticas del turno actual del camarero autenticado",
)
def estadisticas_mi_turno(
    desde: Optional[str] = Query(
        None,
        description="ISO datetime; default = hoy 00:00 hora local del servidor",
    ),
    hasta: Optional[str] = Query(
        None,
        description="ISO datetime; default = ahora",
    ),
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """KPIs del trabajador: cuánto ha cobrado, cuántos pedidos y mesas
    atendidas, propinas, descuentos aplicados y pedidos cancelados.

    Filtra por `cobrado_por_sub == actor.sub` (el que cobró) y rango
    temporal opcional. Por defecto, "hoy desde medianoche UTC".

    Convención horaria: el filtro se hace en UTC. Si el cliente envía un
    ISO con offset (`2026-05-13T00:00:00+02:00`), se normaliza a UTC antes
    de comparar; sin offset asumimos UTC. Esto evita el desfase que tenía
    el endpoint antes, cuando frontend mandaba horario local y el back lo
    comparaba como UTC.
    """
    def _a_utc(valor: str, nombre: str) -> datetime:
        try:
            dt = datetime.fromisoformat(valor)
        except ValueError:
            raise ValidacionError(
                f"Parámetro `{nombre}` con formato inválido (ISO 8601)"
            )
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)

    ahora = datetime.now(timezone.utc)
    dt_desde = _a_utc(desde, "desde") if desde else datetime(
        ahora.year, ahora.month, ahora.day, tzinfo=timezone.utc
    )
    dt_hasta = _a_utc(hasta, "hasta") if hasta else ahora

    if dt_hasta < dt_desde:
        raise ValidacionError("`hasta` no puede ser anterior a `desde`")

    sub = current_user.get("sub", "")
    rid = current_user.get("restaurante_id")

    # `cobrado_at` se persiste como ISO UTC con offset (`...+00:00`).
    # Comparamos contra ese mismo formato para que `$gte/$lte` sea
    # consistente en strings ISO ordenables.
    desde_iso = dt_desde.isoformat()
    hasta_iso = dt_hasta.isoformat()

    # Pedidos cobrados por el actor en el rango.
    filtro_cobrados: dict = {
        "cobrado_por_sub": sub,
        "estado_pago": "pagado",
        "cobrado_at": {
            "$gte": desde_iso,
            "$lte": hasta_iso,
        },
    }
    if rid:
        filtro_cobrados["restaurante_id"] = rid

    pedidos_cobrados = list(coleccion_pedidos.find(filtro_cobrados))
    total_cobrado = 0.0
    total_propinas = 0.0
    total_descuentos = 0.0
    mesas_atendidas: set[str] = set()
    for p in pedidos_cobrados:
        # Si hay total_final usamos ese (con descuento/propina aplicados).
        importe = p.get("total_final")
        if importe is None:
            importe = p.get("total", 0)
        total_cobrado += float(importe or 0)
        total_propinas += float(p.get("propina") or 0)
        total_descuentos += float(p.get("descuento") or 0)
        mid = p.get("mesa_id")
        if mid:
            mesas_atendidas.add(str(mid))

    # Cancelados: pedidos creados por este camarero (creado_por_sub) que
    # acabaron en cancelado dentro del rango temporal.
    filtro_cancelados: dict = {
        "creado_por_sub": sub,
        "estado": "cancelado",
        "cancelado_at": {
            "$gte": desde_iso,
            "$lte": hasta_iso,
        },
    }
    if rid:
        filtro_cancelados["restaurante_id"] = rid
    cancelados = coleccion_pedidos.count_documents(filtro_cancelados)

    return {
        "desde": dt_desde.isoformat(),
        "hasta": dt_hasta.isoformat(),
        "totalCobrado": round(total_cobrado, 2),
        "pedidosCobrados": len(pedidos_cobrados),
        "mesasAtendidas": len(mesas_atendidas),
        "totalPropinas": round(total_propinas, 2),
        "totalDescuentos": round(total_descuentos, 2),
        "pedidosCancelados": cancelados,
    }


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

    # Merge final por nombre normalizado: items legacy sin producto_id se
    # agrupaban en un bucket distinto del que tiene pid, produciendo entradas
    # duplicadas en el top (p. ej. "Refresco" aparecía dos veces). Aquí
    # consolidamos por nombre lowercase, prefiriendo conservar el producto_id
    # del bucket que sí lo tenga.
    productos_unificados: dict[str, dict] = {}
    for bucket in productos.values():
        nombre_norm = bucket["nombre"].strip().lower()
        existente = productos_unificados.get(nombre_norm)
        if existente is None:
            productos_unificados[nombre_norm] = {
                "producto_id": bucket.get("producto_id"),
                "nombre": bucket["nombre"],
                "unidades": bucket["unidades"],
                "ingresos": bucket["ingresos"],
            }
        else:
            existente["unidades"] += bucket["unidades"]
            existente["ingresos"] += bucket["ingresos"]
            # Preferimos conservar un producto_id real si alguno de los dos
            # buckets lo trae; así el frontend puede enlazar a la ficha.
            if not existente.get("producto_id") and bucket.get("producto_id"):
                existente["producto_id"] = bucket["producto_id"]

    # Top 10 productos ordenados desc por unidades
    top_productos = sorted(
        productos_unificados.values(), key=lambda x: x["unidades"], reverse=True
    )[:10]
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
        jwt_restaurante = current_user.get("restaurante_id")
        if rol != "super_admin":
            if jwt_restaurante:
                restauranteId = jwt_restaurante
            else:
                # Cuenta de personal sin sucursal asignada: rechazamos para
                # evitar que se devuelvan pedidos de todas las sucursales.
                logger.warning(
                    "obtener_pedidos: usuario personal sin restaurante_id en JWT "
                    "(rol=%s sub=%s). Rechazando request.",
                    rol, current_user.get("sub"),
                )
                raise HTTPException(
                    status_code=400,
                    detail="Tu cuenta no está asignada a una sucursal",
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
            "prioritario": bool(p.get("prioritario", False)),
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
        "prioritario": bool(p.get("prioritario", False)),
    }


class MoverMesaBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    nuevaMesaId: str


class TransferirResponsableBody(BaseModel):
    model_config = ConfigDict(extra="forbid")
    nuevoResponsableSub: str


@router.patch(
    "/{pedido_id}/transferir",
    summary="Transferir un pedido a otro camarero (cambio de turno)",
)
def transferir_pedido(
    pedido_id: str,
    payload: TransferirResponsableBody,
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """Cambia el camarero responsable de un pedido. El nuevo responsable
    asume las acciones (cobrar, modificar) sobre la mesa. Solo el
    responsable actual o admin/super_admin pueden transferir."""
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    estado_actual = pedido.get("estado", "pendiente")
    if estado_actual in {"entregado", "cancelado"}:
        raise ConflictError(
            f"No se puede transferir un pedido en estado '{estado_actual}'"
        )

    rol_actor = normalizar_rol(current_user.get("rol", ""))
    actor_sub = current_user.get("sub")
    responsable_actual = pedido.get("responsable_sub")
    if (
        rol_actor not in {"admin", "super_admin"}
        and responsable_actual
        and responsable_actual != actor_sub
    ):
        raise HTTPException(
            status_code=403,
            detail="Solo el camarero responsable o un admin pueden transferir",
        )

    # Validar que el nuevo responsable existe, está activo y es de la misma sucursal
    from database import coleccion_usuarios as _col_users

    try:
        nuevo_oid = ObjectId(payload.nuevoResponsableSub)
    except Exception:
        raise ValidacionError("ID de usuario inválido")

    nuevo = _col_users.find_one({"_id": nuevo_oid})
    if not nuevo:
        raise NotFoundError("Camarero no encontrado")
    if nuevo.get("activo") is False:
        raise ConflictError("El camarero está inactivo")
    rol_nuevo = normalizar_rol(nuevo.get("rol", ""))
    if rol_nuevo not in {"camarero", "admin", "super_admin"}:
        raise ValidacionError(
            "El usuario destino no tiene rol de camarero/admin"
        )

    rid_pedido = pedido.get("restaurante_id")
    rid_nuevo = nuevo.get("restaurante_id")
    if rid_pedido and rid_nuevo and rid_pedido != rid_nuevo:
        raise HTTPException(
            status_code=400,
            detail="El camarero destino es de otra sucursal",
        )

    coleccion_pedidos.update_one(
        {"_id": ObjectId(pedido_id)},
        {"$set": {
            "responsable_sub": payload.nuevoResponsableSub,
            "responsable_correo": nuevo.get("correo"),
        }},
    )
    ag.registrar(
        ag.PEDIDO_CREADO,  # reusamos categoría general; el detalle clarifica.
        actor=current_user.get("correo"),
        objetivo=pedido_id,
        detalle=(
            f"transferido a {nuevo.get('correo')} desde "
            f"{current_user.get('correo')}"
        ),
        extra={
            "tipo": "transferencia",
            "responsable_anterior_sub": responsable_actual,
            "responsable_nuevo_sub": payload.nuevoResponsableSub,
        },
    )
    return {
        "ok": True,
        "responsableSub": payload.nuevoResponsableSub,
        "responsableCorreo": nuevo.get("correo"),
    }


@router.get(
    "/camareros-disponibles",
    summary="Lista de camareros activos de la sucursal (para transferencias)",
)
def listar_camareros_disponibles(
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """Devuelve los camareros activos de la sucursal del actor (mínimo: id,
    nombre, correo). Lo usa el dialog de transferencia para que el camarero
    elija a quién pasarle la mesa al cambio de turno."""
    from database import coleccion_usuarios as _col_users

    rol = normalizar_rol(current_user.get("rol", ""))
    rid = current_user.get("restaurante_id")
    filtro: dict = {"activo": {"$ne": False}}
    # Aceptamos rol canónico camarero y los alias legacy de BD por defensa.
    filtro["rol"] = {"$in": ["camarero", "trabajador", "mesero"]}
    if rol != "super_admin" and rid:
        filtro["restaurante_id"] = rid

    cursor = _col_users.find(
        filtro,
        {"nombre": 1, "correo": 1, "_id": 1},
    ).sort("nombre", 1)
    return [
        {
            "id": str(u["_id"]),
            "nombre": u.get("nombre", ""),
            "correo": u.get("correo", ""),
        }
        for u in cursor
    ]


@router.patch("/{pedido_id}/mover-mesa", summary="Mover un pedido a otra mesa")
def mover_pedido_a_otra_mesa(
    pedido_id: str,
    payload: MoverMesaBody,
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """Cambia la mesa asignada a un pedido activo. Caso típico: un grupo
    se mueve de mesa. Libera la mesa origen y ocupa la destino. Solo se
    puede mover pedidos NO terminales (pendiente/preparando/listo)."""
    from database import coleccion_mesas as _col_mesas

    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    estado_actual = pedido.get("estado", "pendiente")
    if estado_actual in {"entregado", "cancelado"}:
        raise ConflictError(
            f"No se puede mover un pedido en estado '{estado_actual}'"
        )

    if pedido.get("tipo_entrega") != "local":
        raise ValidacionError(
            "Solo se pueden mover pedidos de mesa (tipo local)"
        )

    nueva_mesa_oid: ObjectId
    try:
        nueva_mesa_oid = ObjectId(payload.nuevaMesaId)
    except Exception:
        raise ValidacionError("ID de mesa inválido")

    nueva_mesa = _col_mesas.find_one({"_id": nueva_mesa_oid})
    if not nueva_mesa:
        raise NotFoundError("Mesa destino no encontrada")

    # Aislamiento por sucursal: la mesa destino debe ser del mismo restaurante
    rid_pedido = pedido.get("restaurante_id")
    rid_mesa = nueva_mesa.get("restaurante_id")
    if rid_pedido and rid_mesa and rid_pedido != rid_mesa:
        raise HTTPException(
            status_code=400,
            detail="La mesa destino pertenece a otra sucursal",
        )

    # Mesa destino debe estar libre.
    estado_dest = nueva_mesa.get("estado", "libre")
    if estado_dest == "ocupada":
        raise ConflictError("La mesa destino ya está ocupada")

    # Mesa origen — libérala. Captura por si el pedido huérfano no la tiene.
    mesa_origen_id = pedido.get("mesa_id")
    if mesa_origen_id:
        try:
            _col_mesas.update_one(
                {"_id": ObjectId(mesa_origen_id)},
                {"$set": {"estado": "libre"}},
            )
        except Exception:
            logger.warning(
                "No se pudo liberar mesa origen %s al mover pedido %s",
                mesa_origen_id, pedido_id,
            )

    # Mesa destino — ocúpala
    _col_mesas.update_one(
        {"_id": nueva_mesa_oid},
        {"$set": {"estado": "ocupada"}},
    )

    # Pedido — actualiza referencia
    coleccion_pedidos.update_one(
        {"_id": ObjectId(pedido_id)},
        {"$set": {
            "mesa_id": str(nueva_mesa_oid),
            "numero_mesa": nueva_mesa.get("numero", 0),
        }},
    )

    ag.registrar(
        ag.MESA_ESTADO_CAMBIADO,
        actor=current_user.get("correo"),
        objetivo=str(nueva_mesa_oid),
        detalle=f"pedido_id={pedido_id} origen={mesa_origen_id}",
        extra={"restaurante_id": rid_pedido, "tipo": "mover_pedido"},
    )

    return {
        "ok": True,
        "mesaId": str(nueva_mesa_oid),
        "numeroMesa": nueva_mesa.get("numero", 0),
    }


@router.patch("/{pedido_id}/items")
def actualizar_items_pedido(
    pedido_id: str,
    payload: ActualizarItemsPedido,
    current_user: dict = Depends(require_role(["camarero", "admin", "super_admin"])),
):
    """[DEPRECATED] Actualiza los items de un pedido.

    Fix 4 — este endpoint coexiste con PATCH /{id} que cubre el mismo caso
    y sí valida máquina de estados. El frontend actual usa PATCH /{id}.
    Se añaden aquí las mismas guardas de estados terminales para cerrar el
    vector por el que un camarero podría mutar items de un pedido ya entregado,
    cancelado o pagado usando esta ruta alternativa.

    Plan de retiro: cuando confirmemos que ningún cliente legacy lo usa
    (revisar logs ~30 días sin warnings) se puede eliminar.
    """
    if not ObjectId.is_valid(pedido_id):
        raise ValidacionError("ID de pedido inválido")

    logger.warning(
        "DEPRECATED endpoint PATCH /pedidos/%s/items usado por sub=%s rol=%s. "
        "Migrar el caller a PATCH /pedidos/{id}.",
        pedido_id,
        current_user.get("sub"),
        normalizar_rol(current_user.get("rol", "")),
    )

    pedido = _obtener_pedido_o_404(pedido_id)
    _verificar_acceso_pedido(pedido, current_user)

    # Fix 4 — estados en los que NO se deben aceptar cambios de items
    _ESTADOS_TERMINALES_ITEMS = {"entregado", "cancelado", "pagado"}
    estado_actual = pedido.get("estado", "pendiente")
    if estado_actual in _ESTADOS_TERMINALES_ITEMS:
        raise ConflictError(
            f"No se pueden modificar items de un pedido en estado '{estado_actual}'"
        )

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
