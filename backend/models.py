import re
from enum import Enum
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from typing import Optional


# ── Enums ─────────────────────────────────────────────────────────────────────

class TipoEntrega(str, Enum):
    local = "local"
    domicilio = "domicilio"
    recoger = "recoger"


class MetodoPago(str, Enum):
    efectivo = "efectivo"
    tarjeta = "tarjeta"
    paypal = "paypal"
    google_pay = "google_pay"


class EstadoPago(str, Enum):
    pendiente = "pendiente"
    pagado = "pagado"
    fallido = "fallido"


# ── Item de pedido ─────────────────────────────────────────────────────────────

class ItemPedido(BaseModel):
    model_config = ConfigDict(extra="allow")

    producto_id: str
    nombre: Optional[str] = None
    cantidad: int = Field(default=1, ge=1)
    precio: float = Field(ge=0)
    sin: list[str] = []

class UsuarioRegistro(BaseModel):
    nombre: str
    password: str = Field(..., min_length=8)
    correo: EmailStr
    telefono: str
    direccion: str
    rol: str = "cliente"
    restauranteId: Optional[str] = None

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
    total: float = Field(ge=0)
    direccionEntrega: Optional[str] = None
    mesaId: Optional[str] = None
    numeroMesa: Optional[int] = None
    notas: Optional[str] = None
    referenciaPago: Optional[str] = None
    estadoPago: Optional[EstadoPago] = EstadoPago.pendiente

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

class VerificarRecuperacion(BaseModel):
    user_id: str
    codigo: str


class ReservaCrear(BaseModel):
    usuarioId: str
    nombreCompleto: str
    fecha: str
    hora: str
    comensales: int
    turno: str
    mesaId: Optional[str] = None
    notas: Optional[str] = None

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

class ProductoCrear(BaseModel):
    nombre: str
    descripcion: str = ""
    precio: float
    categoria: str
    imagen: Optional[str] = None
    disponible: bool = True
    ingredientes: list = []
