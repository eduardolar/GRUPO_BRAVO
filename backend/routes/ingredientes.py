from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Optional
from bson import ObjectId
from bson.errors import InvalidId
from database import coleccion_ingredientes
from models import IngredienteCrear, IngredienteActualizar
from security import get_current_user, normalizar_rol, require_role

router = APIRouter(prefix="/ingredientes", tags=["Ingredientes"])

# ─── Helpers ────────────────────────────────────────────────────────────────

def _formato(i: dict) -> dict:
    return {
        "id": str(i["_id"]),
        "nombre": i.get("nombre", i.get("ingrediente", "")),
        "cantidadActual": i.get("cantidad_actual", 0),
        "unidad": i.get("unidad", "kg"),
        "stockMinimo": i.get("stock_minimo", 0),
        "categoria": i.get("categoria", "Otros"),
        # Devolvemos la sucursal en ambas convenciones para que tanto
        # frontends nuevos (camelCase) como antiguos (snake_case) funcionen.
        "restauranteId": i.get("restaurante_id"),
        "restaurante_id": i.get("restaurante_id"),
    }


def _filtro_restaurante(restaurante_id: Optional[str]) -> dict:
    return {"restaurante_id": restaurante_id} if restaurante_id else {}


def _oid(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail="ID inválido")


def _exigir_misma_sucursal(ingrediente: dict, usuario: dict) -> None:
    """Un admin de sucursal X NO puede tocar ingredientes de la sucursal Y.
    Los super admins sí pueden — el chequeo se salta para ellos.
    """
    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol == "super_admin":
        return
    rid_ing = ingrediente.get("restaurante_id")
    rid_user = usuario.get("restaurante_id") or usuario.get("restauranteId")
    if rid_ing and rid_user and rid_ing != rid_user:
        raise HTTPException(
            status_code=403,
            detail="No puedes modificar ingredientes de otra sucursal",
        )


# ─── Lecturas ───────────────────────────────────────────────────────────────

@router.get("", summary="Listar ingredientes (filtra por restaurante_id si se pasa)")
def obtener_ingredientes(
    restaurante_id: Optional[str] = Query(None),
    _user: dict = Depends(get_current_user),
):
    filtro = _filtro_restaurante(restaurante_id)
    return [_formato(i) for i in coleccion_ingredientes.find(filtro)]


@router.get("/por-categoria", summary="Ingredientes agrupados por categoría")
def ingredientes_por_categoria(
    restaurante_id: Optional[str] = Query(None),
    _user: dict = Depends(get_current_user),
):
    filtro = _filtro_restaurante(restaurante_id)
    agrupados: dict = {}
    for i in coleccion_ingredientes.find(filtro):
        cat = i.get("categoria", "Otros")
        agrupados.setdefault(cat, []).append(_formato(i))
    return agrupados


@router.get("/stock-bajo", summary="Ingredientes por debajo del stock mínimo")
def ingredientes_stock_bajo(
    restaurante_id: Optional[str] = Query(None),
    _user: dict = Depends(get_current_user),
):
    filtro = _filtro_restaurante(restaurante_id)
    resultado = []
    for i in coleccion_ingredientes.find(filtro):
        if i.get("cantidad_actual", 0) <= i.get("stock_minimo", 0):
            resultado.append(_formato(i))
    return resultado


# ─── Mutaciones (admin) ─────────────────────────────────────────────────────

@router.post("", summary="Crear ingrediente (admin)")
def crear_ingrediente(
    ingrediente: IngredienteCrear,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    doc = {
        "nombre": ingrediente.nombre,
        "cantidad_actual": ingrediente.cantidadActual,
        "unidad": ingrediente.unidad,
        "stock_minimo": ingrediente.stockMinimo,
        "categoria": ingrediente.categoria,
    }
    # Si el admin es de sucursal y NO ha mandado restauranteId (caso bug
    # legacy o petición incompleta), tomamos la suya. Así el ingrediente
    # nunca queda huérfano cuando un admin lo crea.
    rid = ingrediente.restauranteId
    if not rid:
        rol = normalizar_rol(usuario.get("rol", "") or "")
        if rol != "super_admin":
            rid = usuario.get("restaurante_id") or usuario.get("restauranteId")
    if rid:
        doc["restaurante_id"] = rid
    resultado = coleccion_ingredientes.insert_one(doc)
    return {"id": str(resultado.inserted_id), "mensaje": "Ingrediente creado"}


@router.put("/{ingrediente_id}", summary="Actualizar ingrediente (admin)")
def actualizar_ingrediente(
    ingrediente_id: str,
    datos: IngredienteActualizar,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(ingrediente_id)
    existente = coleccion_ingredientes.find_one({"_id": oid})
    if not existente:
        raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    _exigir_misma_sucursal(existente, usuario)

    mapa_campos = {
        "cantidadActual": "cantidad_actual",
        "stockMinimo": "stock_minimo",
        "nombre": "nombre",
        "unidad": "unidad",
        "categoria": "categoria",
    }
    campos = {
        mapa_campos[k]: v
        for k, v in datos.model_dump().items()
        if v is not None and k in mapa_campos
    }
    if not campos:
        raise HTTPException(status_code=400, detail="No hay campos para actualizar")
    coleccion_ingredientes.update_one({"_id": oid}, {"$set": campos})
    return {"mensaje": "Ingrediente actualizado"}


@router.delete("/{ingrediente_id}", summary="Eliminar ingrediente (admin)")
def eliminar_ingrediente(
    ingrediente_id: str,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _oid(ingrediente_id)
    existente = coleccion_ingredientes.find_one({"_id": oid})
    if not existente:
        raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    _exigir_misma_sucursal(existente, usuario)

    resultado = coleccion_ingredientes.delete_one({"_id": oid})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    return {"mensaje": "Ingrediente eliminado"}
