from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from pydantic import BaseModel
from bson import ObjectId
from bson.errors import InvalidId
import logging
from database import coleccion_ingredientes, coleccion_productos, cliente
from models import IngredienteCrear, IngredienteActualizar
from security import get_current_user, normalizar_rol, require_role

router = APIRouter(prefix="/ingredientes", tags=["Ingredientes"])
logger = logging.getLogger("uvicorn")

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


def _restaurante_filtrado(usuario: dict, query_rid: Optional[str]) -> Optional[str]:
    """Devuelve el restaurante_id que debe aplicarse en lecturas, forzando
    el aislamiento por sucursal. super_admin pasa libre; el resto se ata al
    JWT. Si el JWT no lleva sucursal (legacy), no se restringe (con aviso)."""
    rol = normalizar_rol(usuario.get("rol", "") or "")
    if rol == "super_admin":
        # super_admin puede cruzar sucursales: usa el filtro de la query tal cual
        return query_rid
    # Personal normal: ignoramos lo que llegue en la query y forzamos el JWT
    jwt_rid = usuario.get("restaurante_id")
    if jwt_rid:
        return jwt_rid
    # JWT sin restaurante_id (cuenta legacy): no restringimos, pero lo trazamos
    logger.warning(
        "ingredientes lectura: usuario sin restaurante_id en JWT "
        "(rol=%s sub=%s). No se aplica restricción por sucursal.",
        rol,
        usuario.get("sub"),
    )
    return query_rid


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
    usuario: dict = Depends(get_current_user),
):
    # Los clientes no tienen acceso al inventario de ingredientes
    if normalizar_rol(usuario.get("rol", "") or "") == "cliente":
        raise HTTPException(status_code=403, detail="Acceso denegado")
    rid_efectivo = _restaurante_filtrado(usuario, restaurante_id)
    filtro = _filtro_restaurante(rid_efectivo)
    return [_formato(i) for i in coleccion_ingredientes.find(filtro)]


@router.get("/por-categoria", summary="Ingredientes agrupados por categoría")
def ingredientes_por_categoria(
    restaurante_id: Optional[str] = Query(None),
    usuario: dict = Depends(get_current_user),
):
    # Los clientes no tienen acceso al inventario de ingredientes
    if normalizar_rol(usuario.get("rol", "") or "") == "cliente":
        raise HTTPException(status_code=403, detail="Acceso denegado")
    rid_efectivo = _restaurante_filtrado(usuario, restaurante_id)
    filtro = _filtro_restaurante(rid_efectivo)
    agrupados: dict = {}
    for i in coleccion_ingredientes.find(filtro):
        cat = i.get("categoria", "Otros")
        agrupados.setdefault(cat, []).append(_formato(i))
    return agrupados


@router.get("/stock-bajo", summary="Ingredientes por debajo del stock mínimo")
def ingredientes_stock_bajo(
    restaurante_id: Optional[str] = Query(None),
    usuario: dict = Depends(get_current_user),
):
    # Los clientes no tienen acceso al inventario de ingredientes
    if normalizar_rol(usuario.get("rol", "") or "") == "cliente":
        raise HTTPException(status_code=403, detail="Acceso denegado")
    rid_efectivo = _restaurante_filtrado(usuario, restaurante_id)
    filtro = _filtro_restaurante(rid_efectivo)
    resultado = []
    for i in coleccion_ingredientes.find(filtro):
        if i.get("cantidad_actual", 0) <= i.get("stock_minimo", 0):
            resultado.append(_formato(i))
    return resultado


# ─── Mantenimiento de duplicados (admin / super_admin) ──────────────────────

class FusionarRequest(BaseModel):
    principal_id: str
    absorber_ids: List[str]


@router.get("/duplicados", summary="Listar grupos de ingredientes duplicados por nombre en la misma sucursal")
def listar_duplicados(
    restaurante_id: Optional[str] = Query(None),
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    rid_efectivo = _restaurante_filtrado(usuario, restaurante_id)
    filtro = _filtro_restaurante(rid_efectivo)

    pipeline = [
        {"$match": filtro},
        {"$group": {
            "_id": {
                "rid": "$restaurante_id",
                "nombre_norm": {"$toLower": {"$trim": {"input": "$nombre"}}},
            },
            "ids": {"$push": "$_id"},
            "ingredientes": {"$push": "$$ROOT"},
            "count": {"$sum": 1},
        }},
        {"$match": {"count": {"$gt": 1}}},
    ]
    grupos = list(coleccion_ingredientes.aggregate(pipeline))

    resultado = []
    for grupo in grupos:
        ings_formateados = [_formato(i) for i in grupo["ingredientes"]]
        # El principal sugerido es el de mayor stock; en caso de empate, el más antiguo
        principal = max(
            grupo["ingredientes"],
            key=lambda i: (i.get("cantidad_actual", 0), -i["_id"].generation_time.timestamp()),
        )
        resultado.append({
            "nombre_normalizado": grupo["_id"]["nombre_norm"],
            "restaurante_id": grupo["_id"]["rid"],
            "count": grupo["count"],
            "ingredientes": ings_formateados,
            "principal_sugerido": str(principal["_id"]),
        })
    return resultado


@router.post("/fusionar", summary="Fusionar ingredientes duplicados (admin / super_admin)")
def fusionar_ingredientes(
    payload: FusionarRequest,
    usuario: dict = Depends(require_role(["admin", "super_admin"])),
):
    # Validar principal
    principal_oid = _oid(payload.principal_id)
    principal_doc = coleccion_ingredientes.find_one({"_id": principal_oid})
    if not principal_doc:
        raise HTTPException(status_code=404, detail="Ingrediente principal no encontrado")
    _exigir_misma_sucursal(principal_doc, usuario)

    if not payload.absorber_ids:
        raise HTTPException(status_code=400, detail="absorber_ids no puede estar vacío")

    # Validar absorbidos: deben existir y pertenecer a la misma sucursal que el principal
    absorber_oids = []
    stock_extra = 0.0
    rid_principal = principal_doc.get("restaurante_id")
    for aid in payload.absorber_ids:
        a_oid = _oid(aid)
        if a_oid == principal_oid:
            raise HTTPException(status_code=400, detail="principal_id no puede estar en absorber_ids")
        a_doc = coleccion_ingredientes.find_one({"_id": a_oid})
        if not a_doc:
            raise HTTPException(status_code=404, detail=f"Ingrediente {aid} no encontrado")
        # Verificar misma sucursal entre los absorbidos y el principal
        rid_abs = a_doc.get("restaurante_id")
        if rid_principal and rid_abs and rid_principal != rid_abs:
            raise HTTPException(
                status_code=403,
                detail=f"El ingrediente {aid} pertenece a otra sucursal",
            )
        stock_extra += a_doc.get("cantidad_actual", 0.0)
        absorber_oids.append(a_oid)

    nombre_principal = principal_doc.get("nombre", "")
    absorber_ids_str = [str(oid) for oid in absorber_oids]

    # Toda la operación en transacción para que sea atómica
    try:
        with cliente.start_session() as session:
            with session.start_transaction():
                # 1. Sumar stock de los absorbidos al principal
                coleccion_ingredientes.update_one(
                    {"_id": principal_oid},
                    {"$inc": {"cantidad_actual": stock_extra}},
                    session=session,
                )

                # 2. Reescribir referencias en productos: cualquier item cuyo
                #    ingrediente_id apunte a un absorbido pasa a apuntar al principal
                for prod in coleccion_productos.find(
                    {"ingredientes.ingrediente_id": {"$in": absorber_ids_str}},
                    session=session,
                ):
                    nuevos_ings = []
                    for ing in prod.get("ingredientes", []):
                        if isinstance(ing, dict) and ing.get("ingrediente_id") in absorber_ids_str:
                            ing = dict(ing)
                            ing["ingrediente_id"] = payload.principal_id
                            ing["nombre"] = nombre_principal
                        nuevos_ings.append(ing)
                    coleccion_productos.update_one(
                        {"_id": prod["_id"]},
                        {"$set": {"ingredientes": nuevos_ings}},
                        session=session,
                    )

                # 3. Borrar los absorbidos
                coleccion_ingredientes.delete_many(
                    {"_id": {"$in": absorber_oids}},
                    session=session,
                )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Error en fusión de ingredientes: %s", exc)
        raise HTTPException(status_code=500, detail="Error interno al fusionar ingredientes")

    stock_final = coleccion_ingredientes.find_one({"_id": principal_oid})
    stock_total = stock_final.get("cantidad_actual", 0) if stock_final else 0

    return {
        "fusionados": len(absorber_oids),
        "stock_total_principal": stock_total,
    }


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
