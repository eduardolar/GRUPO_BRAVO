from pydantic import BaseModel
from typing import Optional


class UsuarioRegistro(BaseModel):
    nombre: str
    password_hash: str
    correo: str
    telefono: str
    direccion: str
    rol: str = "cliente"

class UsuarioLogin(BaseModel):
    correo: str
    password_hash: str

class UsuarioActualizar(BaseModel):
    nombre: str
    correo: str
    telefono: str
    direccion: str

class PedidoCrear(BaseModel):
    usuario_id: str
    items: list
    tipo_entrega: str
    metodo_pago: str
    total: float
    direccion_entrega: Optional[str] = None
    mesa_id: Optional[str] = None
    numero_mesa: Optional[int] = None
    notas: Optional[str] = None

class ReservaCrear(BaseModel):
    usuario_id: str
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

class IngredienteActualizar(BaseModel):
    cantidad_actual: Optional[float] = None
    stock_minimo: Optional[float] = None

class ProductoCrear(BaseModel):
    nombre: str
    descripcion: str = ""
    precio: float
    categoria: str
    imagen: Optional[str] = None
    disponible: bool = True
    ingredientes: list = []
