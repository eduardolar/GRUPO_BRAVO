import logging
import re
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from typing import Optional
from pydantic import BaseModel, field_validator
from bson import ObjectId
from bson.errors import InvalidId

from database import coleccion_cupones
from security import require_role, get_current_user, normalizar_rol
import audit_general as ag

logger = logging.getLogger("uvicorn")
from database import coleccion_cupones, coleccion_usuarios
from security import require_role, get_current_user
import re
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


router = APIRouter(prefix="/cupones", tags=["Cupones"])


# ─── Modelos Pydantic ──────────────────────────────────────────────────────────

class CuponCrear(BaseModel):
    codigo: str
    tipo: str  # "porcentaje" | "fijo"
    valor: float
    descripcion: Optional[str] = ""
    usos_maximos: Optional[int] = None
    fecha_inicio: Optional[str] = None  # ISO date string "YYYY-MM-DD"
    fecha_fin: Optional[str] = None
    restaurante_id: Optional[str] = None

    @field_validator("codigo")
    @classmethod
    def validar_codigo(cls, v: str) -> str:
        v = v.strip().upper()
        if not v:
            raise ValueError("El código no puede estar vacío")
        if not re.match(r"^[A-Z0-9_-]{2,20}$", v):
            raise ValueError("El código solo puede contener letras, números, guiones y guiones bajos")
        return v

class CuponValidar(BaseModel):
    codigo: str
    subtotal: float
    coste_envio: float = 0.0
    restaurante_id: Optional[str] = None


# ─── Utilidades Internas ──────────────────────────────────────────────────────

def _cupon_vigente(cupon: dict) -> Optional[str]:
    """Verifica si el cupón está activo, en fecha y con usos disponibles."""
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

# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/validar", summary="Validar un cupón y calcular descuento")
def validar_cupon(datos: CuponValidar):
    codigo_limpio = datos.codigo.strip().upper()
    cupon = coleccion_cupones.find_one({"codigo": codigo_limpio})
    
    if not cupon:
        return {
            "valido": False,
            "mensaje": "Cupón no encontrado",
            "descuento": 0.0
        }

    # Validar vigencia
    error = _cupon_vigente(cupon)
    if error:
        return {"valido": False, "mensaje": error, "descuento": 0.0}

    # Validar restricción de restaurante
    rid_cupon = cupon.get("restaurante_id")
    if rid_cupon and datos.restaurante_id and str(rid_cupon) != str(datos.restaurante_id):
        return {
            "valido": False,
            "mensaje": "Este cupón no es válido para este restaurante",
            "descuento": 0.0
        }

    tipo = cupon.get("tipo")
    valor = float(cupon.get("valor", 0))
    subtotal = round(datos.subtotal, 2)
    descuento = 0.0

    if tipo == "porcentaje":
        descuento = round(subtotal * (valor / 100), 2)
    elif tipo == "fijo":
        # No descontar más del total del pedido
        total_max = round(subtotal + datos.coste_envio, 2)
        descuento = round(min(valor, total_max), 2)
    else:
        return {"valido": False, "mensaje": "Tipo de cupón desconocido", "descuento": 0.0}

    return {
        "valido": True,
        "mensaje": "Cupón aplicado correctamente",
        "descuento": descuento,
        "codigo": codigo_limpio,
        "tipo": tipo
    }

@router.get("/")
def listar_cupones(solo_activos: bool = False, user=Depends(require_role(["admin", "root"]))):
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

 }

def enviar_email_tarea(email_destino: str, nombre: str, codigo: str, descripcion: str):
    """Tarea en segundo plano para enviar el email sin bloquear el servidor"""
    
    # Leemos las credenciales desde tu archivo .env
    remitente = os.getenv("MAIL_USERNAME") 
    password = os.getenv("MAIL_PASSWORD")
    servidor_smtp = os.getenv("MAIL_SERVER", "smtp.gmail.com") 
    puerto_smtp = int(os.getenv("MAIL_PORT", 587))

    msg = MIMEMultipart()
    msg['Subject'] = f"¡{nombre}, tenemos un regalo para ti!"
    msg['From'] = f"Bravo App <{remitente}>"
    msg['To'] = email_destino

    cuerpo_html = f"""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto;">
        <h2 style="color: #d4af37;">¡Hola {nombre}!</h2>
        <p>Tienes un nuevo beneficio exclusivo de <strong>Bravo</strong>.</p>
        <div style="background: #111; color: #fff; padding: 20px; border-radius: 10px; text-align: center;">
            <h1 style="font-size: 35px; letter-spacing: 4px; color: #d4af37;">{codigo}</h1>
            <p style="color: #ccc; font-size: 16px;">{descripcion}</p>
        </div>
        <p style="color: #666; font-size: 12px; margin-top: 20px;">Válido por tiempo limitado. ¡Te esperamos!</p>
    </div>
    """
    msg.attach(MIMEText(cuerpo_html, 'html'))

    try:
        # Nos conectamos usando los datos del .env
        with smtplib.SMTP(servidor_smtp, puerto_smtp) as server:
            server.starttls()
            server.login(remitente, password)
            server.sendmail(remitente, email_destino, msg.as_string())
            print(f"¡Correo enviado con éxito a {email_destino}!") # para pruebas
    except Exception as e:
        print(f"Error enviando correo a {email_destino}: {e}")


# ─── Endpoints ─────────────────────────────────────────────────────────────────
# Lectura permitida a cualquier usuario autenticado; mutación restringida a admins.

@router.get("", summary="Listar cupones")
def listar_cupones(
    solo_activos: bool = Query(False),
    _user: dict = Depends(get_current_user),
):
    filtro = {"activo": True} if solo_activos else {}
    lista = list(coleccion_cupones.find(filtro))
    for c in lista:
        c["_id"] = str(c["_id"])
    return lista

@router.post("/")
def crear_cupon(datos: CuponCrear, user=Depends(require_role(["admin", "root"]))):
    if coleccion_cupones.find_one({"codigo": datos.codigo}):
        raise HTTPException(status_code=400, detail="El código de cupón ya existe")
    
    nuevo_cupon = datos.model_dump()
    nuevo_cupon["activo"] = True
    nuevo_cupon["usos_actuales"] = 0
    
    res = coleccion_cupones.insert_one(nuevo_cupon)
    ag.registrar_evento(user["email"], "CREAR_CUPON", f"Cupón {datos.codigo} creado")
    return {"id": str(res.inserted_id), "status": "success"}

@router.post("/{cupon_id}/usar")
def registrar_uso_cupon(cupon_id: str):
    try:
        oid = ObjectId(cupon_id)
    except InvalidId:
        raise HTTPException(status_code=400, detail="ID de cupón inválido")
        
    res = coleccion_cupones.update_one(
        {"_id": oid},
        {"$inc": {"usos_actuales": 1}}
    )
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    return {"status": "uso registrado"}
    return {"mensaje": "Cupón " + ("activado" if activo else "desactivado")}


@router.delete("/{cupon_id}", summary="Eliminar cupón (admin)")
def eliminar_cupon(
    cupon_id: str,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    resultado = coleccion_cupones.delete_one({"_id": _oid(cupon_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")
    return {"mensaje": "Cupón eliminado"}


@router.post("/{cupon_id}/usar", summary="Registrar uso del cupón")
def registrar_uso(cupon_id: str, _user: dict = Depends(get_current_user)):
    """Incrementa el contador de usos. Llámalo al aplicar el cupón en un pedido."""
    oid = _oid(cupon_id)
    # Operación atómica: sólo incrementa si está activo y aún no agotado.
    c = coleccion_cupones.find_one_and_update(
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
        return_document=True,
    )
    if not c:
        # Diferenciar si no existe vs. si está agotado/inactivo
        existente = coleccion_cupones.find_one({"_id": oid})
        if not existente:
            raise HTTPException(status_code=404, detail="Cupón no encontrado")
        if not existente.get("activo", True):
            raise HTTPException(status_code=400, detail="El cupón está inactivo")
        raise HTTPException(status_code=400, detail="El cupón ha alcanzado el límite de usos")
    return {"mensaje": "Uso registrado", "usos_actuales": c.get("usos_actuales", 0)}

@router.post("/enviar-masivo", summary="Enviar cupón masivo (admin)")
def enviar_cupon_masivo(
    datos: EnvioMasivoRequest,
    background_tasks: BackgroundTasks,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    # Buscar el cupón 
    cupon = coleccion_cupones.find_one({"_id": _oid(datos.cuponId)})
    if not cupon:
        raise HTTPException(status_code=404, detail="Cupón no encontrado")

    # filtro de búsqueda
    query = {"rol": "cliente", "activo": True}
    
    if datos.filtro == "restaurante" and datos.restauranteId:
        query["restaurante_id"] = datos.restauranteId

    # Solo traemos correo y nombre para no saturar la memoria
    clientes = list(coleccion_usuarios.find(query, {"correo": 1, "nombre": 1}))

    if not clientes:
        raise HTTPException(status_code=404, detail="No se encontraron clientes para este filtro")

    # Añadir las tareas de envío al BackgroundTasks
    codigo = cupon.get("codigo", "")
    descripcion = cupon.get("descripcion", "")

    for cliente in clientes:
        # Algunos usuarios podrían no tener nombre guardado
        nombre_cliente = cliente.get("nombre", "Cliente") 
        correo_cliente = cliente.get("correo")
        
        if correo_cliente:
            background_tasks.add_task(
                enviar_email_tarea, 
                correo_cliente, 
                nombre_cliente, 
                codigo, 
                descripcion
            )

    return {"mensaje": f"Procesando el envío de {len(clientes)} correos."}
