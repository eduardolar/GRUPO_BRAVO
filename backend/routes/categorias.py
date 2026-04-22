from fastapi import APIRouter
from database import coleccion_categorias

router = APIRouter(prefix="/categorias", tags=["Categorías"])

@router.get("")
def obtener_categorias():
    categorias = coleccion_categorias.find()
    return [cat["nombre"] for cat in categorias]
