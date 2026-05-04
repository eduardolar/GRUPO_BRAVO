from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from pydantic import BaseModel
from bson import ObjectId
from bson.errors import InvalidId
from database import coleccion_productos, coleccion_ingredientes
from models import ProductoCrear
from security import require_role

router = APIRouter(prefix="/productos", tags=["Productos"])


class ProductoOrden(BaseModel):
    orden: List[str]


class AsignarSucursalRequest(BaseModel):
    """Asigna una sucursal a un grupo de productos. Si `solo_huerfanos`
    es True, ignora `ids` y opera sobre todos los productos sin
    `restaurante_id` (atajo para migrar el catálogo legacy)."""
    restaurante_id: str
    ids: List[str] = []
    solo_huerfanos: bool = False


def _normalizar_payload(producto: ProductoCrear) -> dict:
    """Convierte el modelo Pydantic a un dict listo para Mongo.

    `restaurante_id=None` se omite del `$set` para que un PUT que no envíe
    ese campo NO borre el restaurante asignado al producto.
    """
    datos = producto.dict()
    if datos.get("restaurante_id") is None:
        datos.pop("restaurante_id", None)
    return datos


def _obj_id(id_str: str) -> ObjectId:
    try:
        return ObjectId(id_str)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail="ID inválido")


def _siguiente_orden() -> int:
    ultima = coleccion_productos.find_one(
        {"orden": {"$exists": True}},
        sort=[("orden", -1)],
    )
    if ultima and isinstance(ultima.get("orden"), int):
        return ultima["orden"] + 1
    return coleccion_productos.count_documents({})


@router.get("", summary="Listar productos (opcionalmente filtrados por restaurante)")
def obtener_productos(
    categoria: Optional[str] = Query(None),
    restauranteId: Optional[str] = Query(
        None,
        description="Filtra productos por sucursal (acepta camelCase desde el frontend)",
    ),
    restaurante_id: Optional[str] = Query(
        None, description="Alias snake_case del filtro por sucursal"
    ),
    incluirSinAsignar: bool = Query(
        False,
        description="Si filtras por sucursal, incluye también los productos legacy sin restaurante_id",
    ),
):
    filtro: dict = {}
    if categoria:
        filtro["categoria"] = categoria
    rid = restauranteId or restaurante_id
    if rid:
        if incluirSinAsignar:
            # Productos del restaurante O productos huérfanos (sin restaurante_id
            # o con restaurante_id vacío). Útil en panel super admin para
            # asignar el catálogo legacy a una sucursal.
            filtro["$or"] = [
                {"restaurante_id": rid},
                {"restaurante_id": {"$in": [None, ""]}},
                {"restaurante_id": {"$exists": False}},
            ]
        else:
            filtro["restaurante_id"] = rid
    productos_raw = list(coleccion_productos.find(filtro))
    con_orden = [p for p in productos_raw if isinstance(p.get("orden"), int)]
    sin_orden = [p for p in productos_raw if not isinstance(p.get("orden"), int)]
    con_orden.sort(key=lambda p: p["orden"])
    productos = con_orden + sin_orden
    resultado = []
    for p in productos:
        ingredientes_raw = p.get("ingredientes", [])
        ingredientes = []
        for ing in ingredientes_raw:
            if isinstance(ing, str):
                ing_db = coleccion_ingredientes.find_one({"nombre": {"$regex": f"^{ing}$", "$options": "i"}})
                if ing_db:
                    ingredientes.append({
                        "id": str(ing_db["_id"]),
                        "nombre": ing_db["nombre"],
                        "cantidad_actual": ing_db.get("cantidad_actual", 0),
                        "unidad": ing_db.get("unidad", "kg"),
                        "stock_minimo": ing_db.get("stock_minimo", 0),
                    })
                else:
                    ingredientes.append({"id": "", "nombre": ing})
            elif isinstance(ing, dict):
                ingredientes.append(ing)
        # Determinar disponibilidad: si algún ingrediente tiene stock <= 0, producto no disponible
        disponible_por_stock = True
        for ing_info in ingredientes:
            cantidad = ing_info.get("cantidad_actual")
            if cantidad is not None and cantidad <= 0:
                disponible_por_stock = False
                break

        # Combinar: el producto está disponible solo si está marcado como disponible Y tiene stock
        esta_disponible = p.get("disponible", p.get("estaDisponible", True)) and disponible_por_stock

        resultado.append({
            "id": str(p["_id"]),
            "nombre": p.get("nombre", ""),
            "descripcion": p.get("descripcion", p.get("description", "")),
            "precio": p.get("precio", 0),
            "imagenUrl": p.get("imagen", p.get("imagenUrl", "")),
            "categoria": p.get("categoria", ""),
            "estaDisponible": esta_disponible,
            "ingredientes": ingredientes,
            # Devolvemos el restaurante en ambas convenciones para que tanto
            # frontends nuevos (camelCase) como antiguos (snake_case) funcionen.
            "restauranteId": p.get("restaurante_id"),
            "restaurante_id": p.get("restaurante_id"),
        })
    return resultado

@router.post("/asignar-sucursal", summary="Asignar sucursal a productos en masa (super admin)")
def asignar_sucursal(
    payload: AsignarSucursalRequest,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    """Reasigna `restaurante_id` en bloque. Útil para migrar productos
    legacy (sin sucursal) a una sucursal concreta."""
    rid = payload.restaurante_id.strip()
    if not rid:
        raise HTTPException(status_code=400, detail="restaurante_id requerido")

    if payload.solo_huerfanos:
        filtro = {
            "$or": [
                {"restaurante_id": {"$in": [None, ""]}},
                {"restaurante_id": {"$exists": False}},
            ]
        }
    else:
        oids = []
        for id_str in payload.ids:
            try:
                oids.append(ObjectId(id_str))
            except (InvalidId, TypeError):
                raise HTTPException(status_code=400, detail=f"ID inválido: {id_str}")
        if not oids:
            raise HTTPException(status_code=400, detail="Sin IDs para asignar")
        filtro = {"_id": {"$in": oids}}

    resultado = coleccion_productos.update_many(
        filtro, {"$set": {"restaurante_id": rid}}
    )
    return {
        "mensaje": "Sucursal asignada",
        "actualizados": resultado.modified_count,
        "coincidencias": resultado.matched_count,
    }


@router.post("", summary="Crear producto (admin)")
def crear_producto(
    producto: ProductoCrear,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    producto_dict = _normalizar_payload(producto)
    producto_dict["orden"] = _siguiente_orden()
    resultado = coleccion_productos.insert_one(producto_dict)
    return {"id": str(resultado.inserted_id), "mensaje": "Producto creado"}


@router.put("/orden", summary="Reordenar productos (admin)")
def reordenar_productos(
    payload: ProductoOrden,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    ids_recibidos = [i.strip() for i in payload.orden if i and i.strip()]
    oids = []
    for id_str in ids_recibidos:
        try:
            oids.append(ObjectId(id_str))
        except (InvalidId, TypeError):
            raise HTTPException(status_code=400, detail=f"ID inválido: {id_str}")

    for indice, oid in enumerate(oids):
        coleccion_productos.update_one({"_id": oid}, {"$set": {"orden": indice}})

    siguiente = len(oids)
    for prod in coleccion_productos.find({"_id": {"$nin": oids}}):
        coleccion_productos.update_one(
            {"_id": prod["_id"]}, {"$set": {"orden": siguiente}}
        )
        siguiente += 1

    return {"mensaje": "Orden actualizado", "total": len(oids)}


@router.put("/{producto_id}", summary="Actualizar producto (admin)")
def actualizar_producto(
    producto_id: str,
    producto: ProductoCrear,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _obj_id(producto_id)
    if not coleccion_productos.find_one({"_id": oid}):
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    coleccion_productos.update_one(
        {"_id": oid},
        {"$set": _normalizar_payload(producto)},
    )
    actualizado = coleccion_productos.find_one({"_id": oid})
    if not actualizado:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    actualizado["id"] = str(actualizado.pop("_id"))
    return actualizado


@router.delete("/{producto_id}", summary="Eliminar producto (admin)")
def eliminar_producto(
    producto_id: str,
    _admin: dict = Depends(require_role(["admin", "super_admin"])),
):
    oid = _obj_id(producto_id)
    resultado = coleccion_productos.delete_one({"_id": oid})
    if resultado.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    return {"mensaje": "Producto eliminado"}
