# ============================================================================
# backend/models.py
# ----------------------------------------------------------------------------
# Modelos Pydantic que validan los DATOS DE ENTRADA y SALIDA de la API.
#
# Pydantic se encarga de:
#   - Convertir el JSON recibido en objetos Python tipados.
#   - Validar tipos (int, float, EmailStr, Enum...).
#   - Validar reglas de negocio definidas con `@field_validator`.
#   - Convertir Enums a strings al serializar la respuesta.
#
# Por qué `model_config = ConfigDict(extra="forbid")`:
#   Rechaza campos extra en el JSON entrante. Es defensa en profundidad:
#   evita que un cliente "feo" mande basura que acabe persistida en Mongo
#   por accidente. Si quieres tolerar campos desconocidos, usa "ignore".
#
# Convención de nombres:
#   - Snapshot de la BD (camelCase histórico en muchos campos: `userId`,
#     `tipoEntrega`, `metodoPago`) por compatibilidad con el frontend que
#     ya manda esos nombres.
#   - Nuevos modelos preferimos snake_case en Python pero respetamos el
#     contrato que ya espera Flutter.
# ============================================================================
import re
from enum import Enum
from typing import Annotated, Any, Dict, List, Optional
from pydantic import BaseModel, EmailStr
from email_validator import EmailNotValidError, validate_email
from pydantic import AfterValidator, BaseModel, ConfigDict, Field, field_validator

import config


def _validar_correo(value: str) -> str:
    """Valida un correo. En entornos no-producción permite TLDs reservados
    (.test, .localhost, etc.) para facilitar pruebas E2E sin emails reales.
    Siempre normaliza a minúsculas el dominio.

    Por qué no usamos `EmailStr` a secas:
        EmailStr de Pydantic ya valida formato, pero NO acepta dominios
        reservados como `.test` aunque sea útil en CI. Con esta función
        ajustamos el comportamiento según `config.IS_PRODUCTION`.
    """
    try:
        result = validate_email(
            value,
            # `test_environment=True` activa la tolerancia con TLDs reservados.
            test_environment=not config.IS_PRODUCTION,
            # Desactivado para no hacer DNS lookups durante validación
            # (ralentiza y depende de red disponible).
            check_deliverability=False,
        )
    except EmailNotValidError as exc:
        # Convertimos al ValueError que Pydantic sabe transformar en 422.
        raise ValueError(str(exc)) from exc
    return result.normalized


# Tipo de correo permisivo en dev/test y estricto en prod. Sustituye a EmailStr
# cuando se quiera aceptar dominios reservados durante pruebas.
# Annotated[X, AfterValidator(f)] = "es un X, y además aplicarle f después
# de la validación estándar".
CorreoStr = Annotated[str, AfterValidator(_validar_correo)]


# ── Enums ─────────────────────────────────────────────────────────────────────
# Usar Enum (en vez de strings sueltos) tiene dos ventajas:
#   1) Pydantic rechaza valores no listados → 422 limpio en lugar de bug.
#   2) Autocompletado en el IDE y refactorización segura.

class TipoEntrega(str, Enum):
    """Cómo se entrega el pedido al cliente."""
    local = "local"        # consumir en el restaurante (mesa)
    domicilio = "domicilio"  # reparto a domicilio
    recoger = "recoger"    # take-away: cliente pasa a buscarlo


class MetodoPago(str, Enum):
    """Métodos de pago aceptados."""
    efectivo = "efectivo"
    # tarjeta_fisica = TPV físico operado por el camarero (cobro en sala).
    # tarjeta legacy (= TPV) se mantiene por compatibilidad con pedidos antiguos.
    tarjeta = "tarjeta"
    tarjeta_fisica = "tarjeta_fisica"
    paypal = "paypal"
    google_pay = "google_pay"
    apple_pay = "apple_pay"


class EstadoPago(str, Enum):
    """Estado del cobro asociado a un pedido."""
    pendiente = "pendiente"  # esperando confirmación de pasarela
    pagado = "pagado"        # confirmado por Stripe webhook / cobrado en caja
    fallido = "fallido"      # rechazado por el banco / cancelado


# ── Item de pedido ─────────────────────────────────────────────────────────────

class ItemPedido(BaseModel):
    """Una línea dentro de un pedido (1 producto, cantidad N, modificaciones).

    Ejemplo:
        { "producto_id": "...", "cantidad": 2, "precio": 8.5, "sin": ["pepinillo"] }
    """
    # extra="forbid" rechaza campos no declarados: evita que el cliente
    # mande, por error, datos que acaben filtrados en BD.
    model_config = ConfigDict(extra="forbid")

    producto_id: str
    nombre: Optional[str] = None     # snapshot del nombre al pedir (por si cambia luego)
    cantidad: int = Field(default=1, ge=1)  # ge=1 → mínimo 1, no se aceptan 0 ni negativos
    precio: float = Field(ge=0)      # snapshot del precio en el momento del pedido
    sin: list[str] = []              # ingredientes a omitir (alergia/preferencia)
    hecho: bool = False              # marcado por cocina cuando termina ese ítem

class UsuarioRegistro(BaseModel):
    """Payload para POST /auth/register (alta de cliente normalmente)."""
    nombre: str
    password: str = Field(..., min_length=8)  # validación extra abajo con field_validator
    correo: CorreoStr
    telefono: str
    direccion: str
    rol: str = "cliente"               # por defecto el alta es de cliente
    restaurante_id: Optional[str] = None
    consentimiento_rgpd: bool = False  # checkbox legal obligatorio en UI
    puntos: int = 0                    # Puntos de fidelidad acumulados por el cliente.

    @field_validator("password")
    @classmethod
    def validar_password_registro(cls, value: str) -> str:
        """Política de contraseñas: 8+ caracteres, mayúscula, número y especial.

        Acumulamos todos los errores antes de levantar para que el usuario
        vea TODOS los problemas a la vez en el formulario, no uno a uno.
        """
        errores = []
        if len(value) < 8:
            errores.append("al menos 8 caracteres")
        if not re.search(r"[A-Z]", value):
            errores.append("al menos una mayúscula")
        if not re.search(r"\d", value):
            errores.append("al menos un número")
        if not re.search(r"[^\w\s]", value):
            # [^\w\s] = "ni letra/dígito/underscore ni espacio" = especial.
            errores.append("al menos un carácter especial")

        if errores:
            raise ValueError("La contraseña debe tener " + ", ".join(errores))

        return value

class UsuarioLogin(BaseModel):
    """Payload para POST /auth/login."""
    correo: str
    password: str

class UsuarioActualizar(BaseModel):
    """Payload para PUT /usuarios/{id} (perfil editable por el propio usuario)."""
    nombre: str
    correo: str
    telefono: str
    direccion: str
    latitud: float | None = None   # Permitimos que sea opcional o nulo
    longitud: float | None = None  # (geocodificación se hace en el frontend)

class PedidoCrear(BaseModel):
    """Payload para POST /pedidos. Es el modelo más complejo: lleva todo lo
    necesario para crear un pedido, validar stock, calcular total y derivar
    el flujo de pago. Ver `routes/pedidos.py` para el ciclo de vida completo.
    """
    # Opcional: cuando el actor es cliente, el back fuerza su `sub`. Cuando
    # es staff (camarero/admin) y crea un pedido de recoger/domicilio/sala
    # sin cliente identificado, lo aceptamos como null — la ruta derivará el
    # usuario_id al sub del propio camarero para mantener trazabilidad.
    userId: Optional[str] = None
    items: list[ItemPedido] = Field(min_length=1)  # un pedido vacío no tiene sentido
    tipoEntrega: TipoEntrega
    metodoPago: MetodoPago
    direccionEntrega: Optional[str] = None  # obligatorio en "domicilio" (validación funcional aparte)
    mesaId: Optional[str] = None            # obligatorio en "local"
    numeroMesa: Optional[int] = None        # snapshot legible para tickets
    notas: Optional[str] = None
    referenciaPago: Optional[str] = None    # id externo (Stripe PaymentIntent...)
    estadoPago: Optional[EstadoPago] = EstadoPago.pendiente
    restauranteId: Optional[str] = None     # multi-tenant: sucursal
    # Prioridad para cocina: pedidos urgentes (cliente con prisa, alergia, etc.)
    # se destacan en la pantalla del cocinero con un banner rojo.
    prioritario: bool = False
    puntosUsados: int = 0                   # canje de puntos de fidelidad

    # --- Normalizadores: aceptamos variantes del frontend ----------------
    # `mode="before"` corre ANTES de validar el tipo Enum, así podemos
    # transformar el string y dejar que la validación final acepte el
    # valor canónico.

    @field_validator("tipoEntrega", mode="before")
    @classmethod
    def _normalizar_tipo_entrega(cls, v: object) -> str:
        if not isinstance(v, str):
            return v
        texto = v.strip().lower()
        if texto in ("local", "mesa", "en mesa"):
            return "local"
        if "domicilio" in texto:
            return "domicilio"
        if "recoger" in texto:
            return "recoger"
        return texto  # cae al Enum y lanzará 422 si no encaja

    @field_validator("metodoPago", mode="before")
    @classmethod
    def _normalizar_metodo_pago(cls, v: object) -> str:
        if not isinstance(v, str):
            return v
        texto = v.strip().lower().replace(" ", "_")
        # Variantes en español y display strings de Flutter.
        _ALIAS = {
            "efectivo": "efectivo",
            "tarjeta": "tarjeta",
            "crédito": "tarjeta", "credito": "tarjeta",
            "débito": "tarjeta",  "debito": "tarjeta",
            "paypal": "paypal",
            "google_pay": "google_pay",
            "googlepay": "google_pay",
            "apple_pay": "apple_pay",
            "applepay": "apple_pay",
        }
        return _ALIAS.get(texto, texto)

    @field_validator("estadoPago", mode="before")
    @classmethod
    def _normalizar_estado_pago(cls, v: object) -> str:
        if not isinstance(v, str):
            return v
        texto = v.strip().lower()
        # 'pendiente_stripe', 'pendiente_paypal', etc. → 'pendiente'.
        # El frontend a veces envía sufijo con la pasarela para debug; aquí
        # lo colapsamos al estado canónico antes de validar.
        if texto.startswith("pendiente"):
            return "pendiente"
        return texto

class VerificarRecuperacion(BaseModel):
    """Payload del flujo "olvidé mi contraseña": user manda código recibido."""
    user_id: str
    codigo: str


class ReservaCrear(BaseModel):
    """Payload para POST /reservas. Tanto cliente como camarero pueden crear,
    pero las reglas cambian: ver `routes/reservas.py`.
    """
    # Opcional: cliente registrado lo manda con su id; camarero/admin
    # creando "walk-in" para alguien sin cuenta no lo manda. El backend
    # fuerza el sub del JWT cuando el actor es cliente (no se confía en
    # lo que envíe).
    usuarioId: Optional[str] = None
    nombreCompleto: str
    fecha: str         # ISO yyyy-mm-dd (validación de formato en el servicio)
    hora: str          # "HH:MM"
    comensales: int
    turno: str         # "comida" / "cena" / etc. (lo define la sucursal)
    mesaId: Optional[str] = None
    notas: Optional[str] = None
    restauranteId: Optional[str] = None
    # Campos opcionales para que camarero/admin registre datos del cliente real
    # (ignorados si el actor es cliente: el cliente solo se reserva a sí mismo)
    telefonoCliente: Optional[str] = None
    correoCliente: Optional[str] = None

class ValidarQR(BaseModel):
    """Payload del scanner: el camarero escanea el QR de una mesa para
    abrir la comanda asociada.
    """
    codigoQr: str

class IngredienteCrear(BaseModel):
    """Alta de ingrediente para el control de stock."""
    nombre: str
    cantidadActual: float = 0
    unidad: str = "kg"          # "kg", "L", "ud", etc.
    stockMinimo: float = 0      # umbral para alertar al admin
    categoria: str = "Otros"
    restauranteId: Optional[str] = None

class IngredienteActualizar(BaseModel):
    """Edición parcial: campos no enviados se conservan."""
    nombre: Optional[str] = None
    cantidadActual: Optional[float] = None
    unidad: Optional[str] = None
    stockMinimo: Optional[float] = None
    categoria: Optional[str] = None


class MesaActualizar(BaseModel):
    """Campos editables de una mesa; todos opcionales (PATCH semántico sobre PUT)."""
    numero: Optional[int] = None
    capacidad: Optional[int] = None
    # Aceptamos camelCase (codigoQr) y snake_case (codigo_qr) desde el cliente;
    # internamente siempre se persiste como codigoQr en BD (compatibilidad histórica).
    codigoQr: Optional[str] = None
    codigo_qr: Optional[str] = None
    ubicacion: Optional[str] = None

    @field_validator("numero")
    @classmethod
    def numero_positivo(cls, v: Optional[int]) -> Optional[int]:
        # None pasa de largo (PATCH); si llega un valor, debe ser >= 1.
        if v is not None and v < 1:
            raise ValueError("numero debe ser >= 1")
        return v

    @field_validator("capacidad")
    @classmethod
    def capacidad_positiva(cls, v: Optional[int]) -> Optional[int]:
        if v is not None and v < 1:
            raise ValueError("capacidad debe ser >= 1")
        return v

    @field_validator("ubicacion")
    @classmethod
    def ubicacion_valida(cls, v: Optional[str]) -> Optional[str]:
        # Valores cerrados: si crece la lista, ampliar aquí.
        _PERMITIDAS = {"interior", "terraza"}
        if v is not None and v not in _PERMITIDAS:
            raise ValueError(f"ubicacion debe ser uno de: {', '.join(sorted(_PERMITIDAS))}")
        return v

    @field_validator("codigoQr", "codigo_qr")
    @classmethod
    def qr_no_vacio(cls, v: Optional[str]) -> Optional[str]:
        # Permitimos None (no cambia) pero no string vacío (sería bug del cliente).
        if v is not None and not v.strip():
            raise ValueError("codigoQr no puede estar vacío")
        return v

class ProductoCrear(BaseModel):
    """Alta/edición de producto de la carta."""
    nombre: str
    descripcion: str = ""
    precio: float
    categoria: str
    imagen: Optional[str] = None      # URL absoluta (Cloudinary o equivalente)
    disponible: bool = True           # false oculta el producto al cliente
    ingredientes: list = []
    # ID de la sucursal a la que pertenece el producto. Si lo omites al
    # editar, el documento conserva el restaurante_id que ya tenía: no lo
    # sobreescribimos con None desde la capa de ruta.
    restaurante_id: Optional[str] = None

    #Validacion para verficar login 2 FA.
class VerificarLogin2FA(BaseModel):
    """Segunda fase del login 2FA: usuario manda el código del email."""
    correo: CorreoStr
    codigo: str


# ── Restaurante ────────────────────────────────────────────────────────────────

class RestauranteActualizar(BaseModel):
    """Campos editables de un restaurante vía PUT /restaurantes/{id}.

    Todos los campos son opcionales: el endpoint solo persiste los que lleguen
    con valor no-None (patrón PATCH semántico sobre verbo PUT).
    """
    nombre: Optional[str] = None
    direccion: Optional[str] = None
    codigo: Optional[str] = None

    # Logo de la sucursal (gestionado preferentemente via POST /restaurantes/{id}/logo,
    # pero se permite actualizar la URL directamente si ya se subió por otro medio)
    logo_url: Optional[str] = None
    logo_public_id: Optional[str] = None

    # Horarios detallados por día (lunes-domingo independientes)
    # Shape: {"lunes": {"apertura": "09:00", "cierre": "23:00", "abierto": true}, ...}
    # Se usa Dict[str, Any] para el valor interno porque 'abierto' puede ser bool o str.
    horarios_dia: Optional[Dict[str, Dict[str, Any]]] = None

    # Datos fiscales (van en el ticket/factura).
    cif: Optional[str] = None
    razon_social: Optional[str] = None
    direccion_fiscal: Optional[str] = None
    codigo_postal: Optional[str] = None
    ciudad: Optional[str] = None
    provincia: Optional[str] = None
    pais: Optional[str] = None

    # Métodos de pago habilitados en la sucursal (subset de MetodoPago).
    metodos_pago: Optional[List[str]] = None

    # ── Modelo de Respuesta del Usuario (Lo que el servidor envía al móvil) ──

class UsuarioResponse(BaseModel):
    """Vista pública del usuario (sin password_hash ni datos sensibles).

    Se usa como `response_model=UsuarioResponse` en los endpoints. Pydantic
    filtra automáticamente cualquier campo no listado aquí, así no se
    filtran accidentalmente datos privados.
    """
    id: str
    nombre: str
    correo: CorreoStr
    telefono: str
    direccion: str
    rol: str
    puntos: int = 0
    activo: bool = True
    restaurante_id: Optional[str] = None

    # from_attributes=True permite construir UsuarioResponse a partir de un
    # dict de Mongo con `UsuarioResponse.model_validate(doc)`.
    model_config = ConfigDict(from_attributes=True)
