import re
from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional

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
    items: list
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
