from fastapi import APIRouter, Query
from typing import Optional
from database import coleccion_productos, coleccion_ingredientes
from models import ProductoCrear

router = APIRouter(prefix="/productos", tags=["Productos"])

@router.get("")
def obtener_productos(categoria: Optional[str] = Query(None)):
    filtro = {}
    if categoria:
        filtro["categoria"] = categoria
    productos = coleccion_productos.find(filtro)
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
        })
    return resultado

@router.post("")
def crear_producto(producto: ProductoCrear):
    producto_dict = producto.dict()
    resultado = coleccion_productos.insert_one(producto_dict)
    return {"id": str(resultado.inserted_id), "mensaje": "Producto creado"}
