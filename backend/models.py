import re
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, Any

class UsuarioRegistro(BaseModel):
    nombre: str
    password_hash: str = Field(..., min_length=8)
    correo: EmailStr
    telefono: str
    direccion: str
    rol: str = "cliente"
    restaurante_id: Optional[str] = None
    is_verified: bool = False
    verification_code: Optional[str] = None

    @field_validator("password_hash")
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
    password_hash: str  # Sin min_length: la validación de contraseña se hace solo en registro

class UsuarioActualizar(BaseModel):
    nombre: str
    correo: str
    telefono: str
    direccion: str

class PedidoCrear(BaseModel):
    userId: str
    items: list[dict[str, Any]]
    tipoEntrega: str
    metodoPago: str
    total: float
    direccionEntrega: Optional[str] = None
    mesaId: Optional[str] = None
    numeroMesa: Optional[int] = None
    notas: Optional[str] = None
    referenciaPago: Optional[str] = None
    estadoPago: Optional[str] = "pendiente"

class ReservaCrear(BaseModel):
    usuario_id: str
    nombre_completo: str
    fecha: str
    hora: str
    comensales: int
    turno: str
    mesa_id: Optional[str] = None
    notas: Optional[str] = None

class ValidarQR(BaseModel):
    codigo_qr: str

class IngredienteCrear(BaseModel):
    nombre: str
    cantidad_actual: float = 0
    unidad: str = "kg"
    stock_minimo: float = 0
    categoria: str = "Otros"

class IngredienteActualizar(BaseModel):
    nombre: Optional[str] = None
    cantidad_actual: Optional[float] = None
    unidad: Optional[str] = None
    stock_minimo: Optional[float] = None
    categoria: Optional[str] = None

class ProductoCrear(BaseModel):
    nombre: str
    descripcion: str = ""
    precio: float
    categoria: str
    imagen: Optional[str] = None
    disponible: bool = True
    ingredientes: list[str] = []
