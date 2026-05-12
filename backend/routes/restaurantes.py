import re
import random
import string
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from database import coleccion_restaurantes
from bson import ObjectId
from bson.errors import InvalidId
from security import require_role, get_current_user, normalizar_rol
from models import RestauranteActualizar

router = APIRouter(prefix="/restaurantes", tags=["Restaurantes"])

class RestauranteCrear(BaseModel):
    nombre: str
    direccion: str


def _serializar_restaurante(r: dict) -> dict:
    """Serializa un documento de restaurante con todos los campos públicos."""
    return {
        "id": str(r["_id"]),
        "nombre": r.get("nombre", ""),
        "direccion": r.get("direccion", ""),
        "codigo": r.get("codigo", ""),
        # Docs legacy sin el campo se tratan como activos
        "activo": r.get("activo", True),
        "suspendido_at": r.get("suspendido_at"),
        # Logo
        "logo_url": r.get("logo_url"),
        "logo_public_id": r.get("logo_public_id"),
        # Horarios por día (formato {lunes: {apertura, cierre, abierto}, ...})
        "horarios_dia": r.get("horarios_dia"),
        # Datos fiscales
        "cif": r.get("cif"),
        "razon_social": r.get("razon_social"),
        "direccion_fiscal": r.get("direccion_fiscal"),
        "codigo_postal": r.get("codigo_postal"),
        "ciudad": r.get("ciudad"),
        "provincia": r.get("provincia"),
        "pais": r.get("pais"),
        # Métodos de pago
        "metodos_pago": r.get("metodos_pago", []),
    }


@router.get("")
def listar_restaurantes(
    incluir_suspendidos: bool = Query(
        True,
        description="Si es false, excluye las sucursales suspendidas (activo=false)",
    ),
    _user: dict = Depends(get_current_user),
):
    """Lista todas las sucursales.

    Por defecto devuelve todas (incluidas las suspendidas) para que el panel
    de super_admin las muestre. Pasa ?incluir_suspendidos=false para filtrar
    solo las activas (útil para los dropdowns de clientes y administradores).

    Requiere autenticación (cualquier rol). La lista de sucursales no es
    multi-tenant — todos los roles necesitan verla para navegación intra-app.
    """
    try:
        filtro: dict = {}
        if not incluir_suspendidos:
            # Excluye documentos con activo=false; los legacy sin el campo
            # (tratados como True) siguen apareciendo.
            filtro["activo"] = {"$ne": False}

        restaurantes = list(coleccion_restaurantes.find(filtro))
        return [_serializar_restaurante(r) for r in restaurantes]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al obtener restaurantes: {str(e)}")

@router.get("/{id}")
def obtener_restaurante(
    id: str,
    _user: dict = Depends(get_current_user),
):
    """Obtiene los datos de una sucursal por ID.

    Requiere autenticación (cualquier rol).
    """
    restaurante = coleccion_restaurantes.find_one({"_id": ObjectId(id)})
    if restaurante:
        return _serializar_restaurante(restaurante)
    raise HTTPException(status_code=404, detail="Restaurante no encontrado")

@router.post("")
def crear_restaurante(
    datos: RestauranteCrear,
    _actor: dict = Depends(require_role(["super_admin"])),
):
    codigo = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    nuevo = {
        "nombre": datos.nombre.strip(),
        "direccion": datos.direccion.strip(),
        "codigo": codigo,
    }
    resultado = coleccion_restaurantes.insert_one(nuevo)
    return {"id": str(resultado.inserted_id), "nombre": nuevo["nombre"], "direccion": nuevo["direccion"], "codigo": codigo}

# Métodos de pago reconocidos en el sistema
_METODOS_PAGO_VALIDOS = {"efectivo", "tarjeta", "paypal", "google_pay", "stripe"}

# Días válidos para horarios_dia
_DIAS_VALIDOS = {"lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo"}

# Patrón HH:MM estricto para horas en horarios_dia
_RE_HORA = re.compile(r"^\d{2}:\d{2}$")


def _validar_hora_formato(valor: str, campo: str) -> str:
    """Valida que el valor tenga formato HH:MM con rango correcto."""
    if not _RE_HORA.match(valor):
        raise HTTPException(
            status_code=422,
            detail=f"El campo '{campo}' tiene formato inválido (esperado HH:MM, recibido '{valor}')",
        )
    h, m = int(valor[:2]), int(valor[3:])
    if not (0 <= h <= 23 and 0 <= m <= 59):
        raise HTTPException(
            status_code=422,
            detail=f"El campo '{campo}' tiene hora fuera de rango: '{valor}'",
        )
    return valor


@router.put("/{id}", summary="Editar sucursal (super_admin global; admin solo su sucursal)")
def editar_restaurante(
    id: str,
    datos: RestauranteActualizar,
    current_user: dict = Depends(get_current_user),
):
    """Actualiza los campos de una sucursal. Solo persiste los campos que llegan
    con valor no-None.

    - super_admin: puede editar cualquier sucursal.
    - admin: solo puede editar la sucursal asociada a su propio restaurante_id del JWT.
    - Cualquier otro rol: 403.
    """
    rol = normalizar_rol(current_user.get("rol", ""))
    if rol == "super_admin":
        pass  # acceso global
    elif rol == "admin":
        # El admin solo puede editar su propia sucursal
        rid_usuario = current_user.get("restaurante_id", "")
        # Comparar como strings (ambos llegan como str desde JWT y URL)
        if str(rid_usuario) != str(id):
            raise HTTPException(
                status_code=403,
                detail="No tienes permiso para editar otra sucursal",
            )
    else:
        raise HTTPException(
            status_code=403,
            detail="No tienes permiso para esta acción",
        )

    try:
        oid = ObjectId(id)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail="ID de restaurante inválido")

    if not coleccion_restaurantes.find_one({"_id": oid}):
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")

    set_data: dict = {}

    # ── Campos simples de texto ───────────────────────────────────────────────
    for campo in ("nombre", "direccion", "codigo", "logo_url", "logo_public_id",
                  "razon_social", "direccion_fiscal", "ciudad", "provincia", "pais"):
        valor = getattr(datos, campo)
        if valor is not None:
            set_data[campo] = valor.strip()

    # ── CIF ───────────────────────────────────────────────────────────────────
    if datos.cif is not None:
        cif = datos.cif.strip().upper()
        if not (8 <= len(cif) <= 12):
            raise HTTPException(status_code=422, detail="El CIF debe tener entre 8 y 12 caracteres")
        set_data["cif"] = cif

    # ── Código postal ─────────────────────────────────────────────────────────
    if datos.codigo_postal is not None:
        cp = datos.codigo_postal.strip()
        if not cp.isdigit():
            raise HTTPException(status_code=422, detail="El codigo_postal debe contener solo dígitos")
        set_data["codigo_postal"] = cp

    # ── Métodos de pago ───────────────────────────────────────────────────────
    if datos.metodos_pago is not None:
        invalidos = [m for m in datos.metodos_pago if m not in _METODOS_PAGO_VALIDOS]
        if invalidos:
            raise HTTPException(
                status_code=422,
                detail=(
                    f"Métodos de pago no reconocidos: {invalidos}. "
                    f"Permitidos: {sorted(_METODOS_PAGO_VALIDOS)}"
                ),
            )
        set_data["metodos_pago"] = datos.metodos_pago

    # ── Horarios por día ──────────────────────────────────────────────────────
    if datos.horarios_dia is not None:
        claves = set(datos.horarios_dia.keys())
        invalidas = claves - _DIAS_VALIDOS
        if invalidas:
            raise HTTPException(
                status_code=422,
                detail=f"Días no válidos en horarios_dia: {sorted(invalidas)}. Permitidos: {sorted(_DIAS_VALIDOS)}",
            )
        if not claves:
            raise HTTPException(status_code=422, detail="horarios_dia no puede estar vacío")

        horarios_validados: dict = {}
        for dia, entry in datos.horarios_dia.items():
            if "apertura" not in entry or "cierre" not in entry:
                raise HTTPException(
                    status_code=422,
                    detail=f"El día '{dia}' requiere los campos 'apertura' y 'cierre'",
                )
            apertura = _validar_hora_formato(entry["apertura"], f"{dia}.apertura")
            cierre = _validar_hora_formato(entry["cierre"], f"{dia}.cierre")
            # 'abierto' es opcional; si no viene, por defecto True
            abierto_raw = entry.get("abierto", "true")
            if isinstance(abierto_raw, bool):
                abierto = abierto_raw
            elif isinstance(abierto_raw, str):
                abierto = abierto_raw.lower() not in ("false", "0", "no")
            else:
                abierto = bool(abierto_raw)
            horarios_validados[dia] = {"apertura": apertura, "cierre": cierre, "abierto": abierto}

        set_data["horarios_dia"] = horarios_validados

    if not set_data:
        raise HTTPException(status_code=422, detail="No se enviaron campos válidos para actualizar")

    coleccion_restaurantes.update_one({"_id": oid}, {"$set": set_data})
    return {"mensaje": "Restaurante actualizado"}



class RestauranteActivo(BaseModel):
    activo: bool

@router.patch("/{id}/activo")
def toggle_activo_restaurante(
    id: str,
    datos: RestauranteActivo,
    _actor: dict = Depends(require_role(["super_admin"])),
):
    resultado = coleccion_restaurantes.update_one(
        {"_id": ObjectId(id)},
        {"$set": {"activo": datos.activo}},
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    estado = "activado" if datos.activo else "suspendido"
    return {"mensaje": f"Restaurante {estado}"}

@router.delete("/{id}", summary="Hard-delete de una sucursal (super_admin)")
def eliminar_restaurante(
    id: str,
    _actor: dict = Depends(require_role(["super_admin"])),
):
    """Elimina permanentemente una sucursal.

    La doble confirmación es responsabilidad del frontend. Este endpoint
    borra el documento sin posibilidad de recuperación.
    Para suspensión reversible usa PATCH /super-admin/restaurantes/{id}/suspender.
    """
    resultado = coleccion_restaurantes.delete_one({"_id": ObjectId(id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Restaurante no encontrado")
    return {"mensaje": "Restaurante eliminado"}