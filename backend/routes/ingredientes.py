from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import coleccion_ingredientes
from models import IngredienteCrear, IngredienteActualizar

router = APIRouter(prefix="/ingredientes", tags=["Ingredientes"])

@router.get("")
def obtener_ingredientes():
    ingredientes = coleccion_ingredientes.find()
    resultado = []
    for i in ingredientes:
        resultado.append({
            "id": str(i["_id"]),
            "nombre": i.get("nombre", i.get("ingrediente", "")),
            "cantidad_actual": i.get("cantidad_actual", 0),
            "unidad": i.get("unidad", "kg"),
            "stock_minimo": i.get("stock_minimo", 0),
        })
    return resultado

@router.post("")
def crear_ingrediente(ingrediente: IngredienteCrear):
    ing_dict = ingrediente.dict()
    resultado = coleccion_ingredientes.insert_one(ing_dict)
    return {"id": str(resultado.inserted_id), "mensaje": "Ingrediente creado"}

@router.put("/{ingrediente_id}")
def actualizar_ingrediente(ingrediente_id: str, datos: IngredienteActualizar):
    campos = {}
    if datos.cantidad_actual is not None:
        campos["cantidad_actual"] = datos.cantidad_actual
    if datos.stock_minimo is not None:
        campos["stock_minimo"] = datos.stock_minimo
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

@router.get("/stock-bajo")
def ingredientes_stock_bajo():
    ingredientes = coleccion_ingredientes.find()
    resultado = []
    for i in ingredientes:
        cantidad = i.get("cantidad_actual", 0)
        minimo = i.get("stock_minimo", 0)
        if cantidad <= minimo:
            resultado.append({
                "id": str(i["_id"]),
                "nombre": i.get("nombre", i.get("ingrediente", "")),
                "cantidad_actual": cantidad,
                "unidad": i.get("unidad", "kg"),
                "stock_minimo": minimo,
            })
    return resultado
