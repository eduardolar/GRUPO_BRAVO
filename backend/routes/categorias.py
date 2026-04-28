from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from database import coleccion_categorias, coleccion_productos

router = APIRouter(prefix="/categorias", tags=["Categorías"])


class CategoriaCrear(BaseModel):
    nombre: str


class CategoriaRenombrar(BaseModel):
    nombre: str


class CategoriaOrden(BaseModel):
    orden: List[str]


def _siguiente_orden() -> int:
    ultima = coleccion_categorias.find_one(
        {"orden": {"$exists": True}},
        sort=[("orden", -1)],
    )
    if ultima and isinstance(ultima.get("orden"), int):
        return ultima["orden"] + 1
    return coleccion_categorias.count_documents({})


@router.get("")
def obtener_categorias():
    # Las categorías se devuelven ordenadas por el campo `orden` (asc).
    # Las que no lo tienen quedan al final preservando el orden de inserción.
    categorias = list(coleccion_categorias.find())
    con_orden = [c for c in categorias if isinstance(c.get("orden"), int)]
    sin_orden = [c for c in categorias if not isinstance(c.get("orden"), int)]
    con_orden.sort(key=lambda c: c["orden"])
    return [c["nombre"] for c in (con_orden + sin_orden)]


@router.post("", status_code=201)
def crear_categoria(payload: CategoriaCrear):
    nombre = payload.nombre.strip()
    if not nombre:
        raise HTTPException(status_code=400, detail="El nombre no puede estar vacío")
    if coleccion_categorias.find_one({"nombre": nombre}):
        raise HTTPException(status_code=409, detail="La categoría ya existe")
    coleccion_categorias.insert_one(
        {"nombre": nombre, "orden": _siguiente_orden()}
    )
    return {"mensaje": "Categoría creada", "nombre": nombre}


@router.put("/orden")
def reordenar_categorias(payload: CategoriaOrden):
    # Reasigna el campo `orden` siguiendo la lista recibida. Las categorías que
    # no aparezcan en la lista quedan al final, en su orden original.
    nombres_recibidos = [n.strip() for n in payload.orden if n and n.strip()]
    existentes = {c["nombre"] for c in coleccion_categorias.find({}, {"nombre": 1})}

    desconocidos = [n for n in nombres_recibidos if n not in existentes]
    if desconocidos:
        raise HTTPException(
            status_code=400,
            detail=f"Categorías no encontradas: {', '.join(desconocidos)}",
        )

    for indice, nombre in enumerate(nombres_recibidos):
        coleccion_categorias.update_one(
            {"nombre": nombre},
            {"$set": {"orden": indice}},
        )

    # Las que no estaban en la lista van detrás
    siguiente = len(nombres_recibidos)
    for cat in coleccion_categorias.find({"nombre": {"$nin": nombres_recibidos}}):
        coleccion_categorias.update_one(
            {"_id": cat["_id"]},
            {"$set": {"orden": siguiente}},
        )
        siguiente += 1

    return {"mensaje": "Orden actualizado", "total": len(nombres_recibidos)}


@router.put("/{nombre}")
def renombrar_categoria(nombre: str, payload: CategoriaRenombrar):
    nuevo = payload.nombre.strip()
    if not nuevo:
        raise HTTPException(status_code=400, detail="El nombre no puede estar vacío")

    actual = coleccion_categorias.find_one({"nombre": nombre})
    if not actual:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")

    if nuevo != nombre and coleccion_categorias.find_one({"nombre": nuevo}):
        raise HTTPException(status_code=409, detail="Ya existe una categoría con ese nombre")

    coleccion_categorias.update_one({"nombre": nombre}, {"$set": {"nombre": nuevo}})
    # Cascada: actualizar la categoría en los productos asociados
    coleccion_productos.update_many(
        {"categoria": nombre},
        {"$set": {"categoria": nuevo}},
    )
    return {"mensaje": "Categoría renombrada", "nombre": nuevo}


@router.delete("/{nombre}")
def eliminar_categoria(nombre: str):
    cat = coleccion_categorias.find_one({"nombre": nombre})
    if not cat:
        raise HTTPException(status_code=404, detail="Categoría no encontrada")
    coleccion_categorias.delete_one({"nombre": nombre})
    # Cascada: eliminar productos asociados a la categoría
    eliminados = coleccion_productos.delete_many({"categoria": nombre})
    return {
        "mensaje": "Categoría eliminada",
        "productosEliminados": eliminados.deleted_count,
    }
