import re
from enum import Enum
from typing import Annotated, Any, Dict, List, Optional

from email_validator import EmailNotValidError, validate_email
from pydantic import AfterValidator, BaseModel, ConfigDict, Field, field_validator

import config


def _validar_correo(value: str) -> str:
    """Valida un correo. En entornos no-producción permite TLDs reservados
    (.test, .localhost, etc.) para facilitar pruebas E2E sin emails reales.
    Siempre normaliza a minúsculas el dominio.
    """
    try:
        result = validate_email(
            value,
            test_environment=not config.IS_PRODUCTION,
            check_deliverability=False,
        )
    except EmailNotValidError as exc:
        raise ValueError(str(exc)) from exc
    return result.normalized


# Tipo de correo permisivo en dev/test y estricto en prod. Sustituye a EmailStr
# cuando se quiera aceptar dominios reservados durante pruebas.
CorreoStr = Annotated[str, AfterValidator(_validar_correo)]


# ── Enums ─────────────────────────────────────────────────────────────────────

class TipoEntrega(str, Enum):
    local = "local"
    domicilio = "domicilio"
    recoger = "recoger"


class MetodoPago(str, Enum):
    efectivo = "efectivo"
    # tarjeta_fisica = TPV físico operado por el camarero (cobro en sala).
    # tarjeta legacy (= TPV) se mantiene por compatibilidad con pedidos antiguos.
    tarjeta = "tarjeta"
    tarjeta_fisica = "tarjeta_fisica"
    paypal = "paypal"
    google_pay = "google_pay"
    apple_pay = "apple_pay"


class EstadoPago(str, Enum):
    pendiente = "pendiente"
    pagado = "pagado"
    fallido = "fallido"


# ── Item de pedido ─────────────────────────────────────────────────────────────

class ItemPedido(BaseModel):
    model_config = ConfigDict(extra="forbid")

    producto_id: str
    nombre: Optional[str] = None
    cantidad: int = Field(default=1, ge=1)
    precio: float = Field(ge=0)
    sin: list[str] = []
    hecho: bool = False

class UsuarioRegistro(BaseModel):
    nombre: str
    password: str = Field(..., min_length=8)
    correo: CorreoStr
    telefono: str
    direccion: str
    rol: str = "cliente"
    restauranteId: Optional[str] = None
    consentimiento_rgpd: bool = False

    @field_validator("password")
    @classmethod
    def validar_password_registro(cls, value: str) -> str:
        errores = []
        if len(value) < 8:
            errores.append("al menos 8 caracteres")
        if not re.search(r"[A-Z]", value):
            errores.append("al menos una mayúscula")
        if not re.search(r"\d", value):
            errores.append("al menos un número")
        if not re.search(r"[^\w\s]", value):
            errores.append("al menos un carácter especial")

        if errores:
            raise ValueError("La contraseña debe tener " + ", ".join(errores))

        return value

class UsuarioLogin(BaseModel):
    correo: str
    password: str

class UsuarioActualizar(BaseModel):
    nombre: str
    correo: str
    telefono: str
    direccion: str
    latitud: float | None = None  # Permitimos que sea opcional o nulo
    longitud: float | None = None

class PedidoCrear(BaseModel):
    userId: str
    items: list[ItemPedido] = Field(min_length=1)
    tipoEntrega: TipoEntrega
    metodoPago: MetodoPago
    direccionEntrega: Optional[str] = None
    mesaId: Optional[str] = None
    numeroMesa: Optional[int] = None
    notas: Optional[str] = None
    referenciaPago: Optional[str] = None
    estadoPago: Optional[EstadoPago] = EstadoPago.pendiente
    restauranteId: Optional[str] = None
    # Prioridad para cocina: pedidos urgentes (cliente con prisa, alergia, etc.)
    # se destacan en la pantalla del cocinero con un banner rojo.
    prioritario: bool = False

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
        return texto

    @field_validator("metodoPago", mode="before")
    @classmethod
    def _normalizar_metodo_pago(cls, v: object) -> str:
        if not isinstance(v, str):
            return v
        texto = v.strip().lower().replace(" ", "_")
        # Variantes en español y display strings de Flutter
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
        # 'pendiente_stripe', 'pendiente_paypal', etc. → 'pendiente'
        if texto.startswith("pendiente"):
            return "pendiente"
        return texto

class VerificarRecuperacion(BaseModel):
    user_id: str
    codigo: str


class ReservaCrear(BaseModel):
    # Opcional: cliente registrado lo manda con su id; camarero/admin
    # creando "walk-in" para alguien sin cuenta no lo manda. El backend
    # fuerza el sub del JWT cuando el actor es cliente (no se confía en
    # lo que envíe).
    usuarioId: Optional[str] = None
    nombreCompleto: str
    fecha: str
    hora: str
    comensales: int
    turno: str
    mesaId: Optional[str] = None
    notas: Optional[str] = None
    restauranteId: Optional[str] = None
    # Campos opcionales para que camarero/admin registre datos del cliente real
    # (ignorados si el actor es cliente: el cliente solo se reserva a sí mismo)
    telefonoCliente: Optional[str] = None
    correoCliente: Optional[str] = None

class ValidarQR(BaseModel):
    codigoQr: str

class IngredienteCrear(BaseModel):
    nombre: str
    cantidadActual: float = 0
    unidad: str = "kg"
    stockMinimo: float = 0
    categoria: str = "Otros"
    restauranteId: Optional[str] = None

class IngredienteActualizar(BaseModel):
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
        _PERMITIDAS = {"interior", "terraza"}
        if v is not None and v not in _PERMITIDAS:
            raise ValueError(f"ubicacion debe ser uno de: {', '.join(sorted(_PERMITIDAS))}")
        return v

    @field_validator("codigoQr", "codigo_qr")
    @classmethod
    def qr_no_vacio(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not v.strip():
            raise ValueError("codigoQr no puede estar vacío")
        return v

class ProductoCrear(BaseModel):
    nombre: str
    descripcion: str = ""
    precio: float
    categoria: str
    imagen: Optional[str] = None
    disponible: bool = True
    ingredientes: list = []
    # ID de la sucursal a la que pertenece el producto. Si lo omites al
    # editar, el documento conserva el restaurante_id que ya tenía: no lo
    # sobreescribimos con None desde la capa de ruta.
    restaurante_id: Optional[str] = None

    #Validacion para verficar login 2 FA.
class VerificarLogin2FA(BaseModel):
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

    # Datos fiscales
    cif: Optional[str] = None
    razon_social: Optional[str] = None
    direccion_fiscal: Optional[str] = None
    codigo_postal: Optional[str] = None
    ciudad: Optional[str] = None
    provincia: Optional[str] = None
    pais: Optional[str] = None

    # Métodos de pago habilitados en la sucursal
    metodos_pago: Optional[List[str]] = None