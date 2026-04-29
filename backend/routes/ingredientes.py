from fastapi import APIRouter, HTTPException, Query
from typing import Optional
from bson import ObjectId
from database import coleccion_ingredientes
from models import IngredienteCrear, IngredienteActualizar

router = APIRouter(prefix="/ingredientes", tags=["Ingredientes"])

def _formato(i: dict) -> dict:
    return {
        "id": str(i["_id"]),
        "nombre": i.get("nombre", i.get("ingrediente", "")),
        "cantidadActual": i.get("cantidad_actual", 0),
        "unidad": i.get("unidad", "kg"),
        "stockMinimo": i.get("stock_minimo", 0),
        "categoria": i.get("categoria", "Otros"),
    }

def _filtro_restaurante(restaurante_id: Optional[str]) -> dict:
    return {"restaurante_id": restaurante_id} if restaurante_id else {}

@router.get("")
def obtener_ingredientes(restaurante_id: Optional[str] = Query(None)):
    filtro = _filtro_restaurante(restaurante_id)
    return [_formato(i) for i in coleccion_ingredientes.find(filtro)]

@router.get("/por-categoria")
def ingredientes_por_categoria(restaurante_id: Optional[str] = Query(None)):
    filtro = _filtro_restaurante(restaurante_id)
    agrupados: dict = {}
    for i in coleccion_ingredientes.find(filtro):
        cat = i.get("categoria", "Otros")
        agrupados.setdefault(cat, []).append(_formato(i))
    return agrupados

@router.get("/stock-bajo")
def ingredientes_stock_bajo(restaurante_id: Optional[str] = Query(None)):
    filtro = _filtro_restaurante(restaurante_id)
    resultado = []
    for i in coleccion_ingredientes.find(filtro):
        if i.get("cantidad_actual", 0) <= i.get("stock_minimo", 0):
            resultado.append(_formato(i))
    return resultado

@router.post("")
def crear_ingrediente(ingrediente: IngredienteCrear):
    doc = {
        "nombre": ingrediente.nombre,
        "cantidad_actual": ingrediente.cantidadActual,
        "unidad": ingrediente.unidad,
        "stock_minimo": ingrediente.stockMinimo,
        "categoria": ingrediente.categoria,
    }
    if ingrediente.restauranteId:
        doc["restaurante_id"] = ingrediente.restauranteId
    resultado = coleccion_ingredientes.insert_one(doc)
    return {"id": str(resultado.inserted_id), "mensaje": "Ingrediente creado"}

@router.put("/{ingrediente_id}")
def actualizar_ingrediente(ingrediente_id: str, datos: IngredienteActualizar):
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
    resultado = coleccion_ingredientes.update_one(
        {"_id": ObjectId(ingrediente_id)},
        {"$set": campos}
    )
    if resultado.matched_count == 0:
        raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    return {"mensaje": "Ingrediente actualizado"}

@router.delete("/{ingrediente_id}")
def eliminar_ingrediente(ingrediente_id: str):
    resultado = coleccion_ingredientes.delete_one({"_id": ObjectId(ingrediente_id)})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Ingrediente no encontrado")
    return {"mensaje": "Ingrediente eliminado"}
