"""Tests de aislamiento por sucursal para los endpoints de lectura de
/api/v1/ingredientes.

Cubre:
 - Autenticación: sin token → 401.
 - Autorización: rol cliente → 403 en los tres endpoints de lectura.
 - Aislamiento: admin de R1 no puede ver ingredientes de R2 aunque lo pida en query.
 - super_admin: puede usar ?restaurante_id=R2 libremente.
 - stock-bajo: filtra por sucursal del JWT, no mezcla.
 - por-categoria: filtra por sucursal del JWT, no mezcla.
 - Legacy (admin sin restaurante_id en JWT): no restringe y devuelve todos.
"""
from unittest.mock import MagicMock, patch
from bson import ObjectId

from security import crear_token


# ─── Helpers de autenticación ────────────────────────────────────────────────

def _auth_admin_r1() -> dict:
    token = crear_token({
        "sub": "u_admin_r1",
        "correo": "admin_r1@test.com",
        "rol": "admin",
        "restaurante_id": "R1",
    })
    return {"Authorization": f"Bearer {token}"}


def _auth_admin_r2() -> dict:
    token = crear_token({
        "sub": "u_admin_r2",
        "correo": "admin_r2@test.com",
        "rol": "admin",
        "restaurante_id": "R2",
    })
    return {"Authorization": f"Bearer {token}"}


def _auth_super_admin() -> dict:
    token = crear_token({
        "sub": "u_super",
        "correo": "super@test.com",
        "rol": "super_admin",
    })
    return {"Authorization": f"Bearer {token}"}


def _auth_cliente() -> dict:
    token = crear_token({
        "sub": "u_cliente",
        "correo": "cliente@test.com",
        "rol": "cliente",
    })
    return {"Authorization": f"Bearer {token}"}


def _auth_admin_legacy_sin_rid() -> dict:
    """Admin cuyo JWT no lleva restaurante_id (cuenta legacy)."""
    token = crear_token({
        "sub": "u_legacy",
        "correo": "legacy@test.com",
        "rol": "admin",
        # sin restaurante_id deliberadamente
    })
    return {"Authorization": f"Bearer {token}"}


# ─── Datos de prueba ─────────────────────────────────────────────────────────

def _ing_r1(nombre: str = "Harina", cantidad: int = 10, minimo: int = 5) -> dict:
    return {
        "_id": ObjectId(),
        "nombre": nombre,
        "cantidad_actual": cantidad,
        "unidad": "kg",
        "stock_minimo": minimo,
        "categoria": "Almidones y Cereales",
        "restaurante_id": "R1",
    }


def _ing_r2(nombre: str = "Azucar") -> dict:
    return {
        "_id": ObjectId(),
        "nombre": nombre,
        "cantidad_actual": 8,
        "unidad": "kg",
        "stock_minimo": 3,
        "categoria": "Otros",
        "restaurante_id": "R2",
    }


# ─── Test 1: sin token → 401 ─────────────────────────────────────────────────

def test_sin_token_devuelve_401(client):
    resp = client.get("/api/v1/ingredientes")
    assert resp.status_code == 401


# ─── Test 2: cliente → 403 en los tres endpoints de lectura ──────────────────

def test_cliente_ingredientes_devuelve_403(client):
    resp = client.get("/api/v1/ingredientes", headers=_auth_cliente())
    assert resp.status_code == 403


def test_cliente_stock_bajo_devuelve_403(client):
    resp = client.get("/api/v1/ingredientes/stock-bajo", headers=_auth_cliente())
    assert resp.status_code == 403


def test_cliente_por_categoria_devuelve_403(client):
    resp = client.get("/api/v1/ingredientes/por-categoria", headers=_auth_cliente())
    assert resp.status_code == 403


# ─── Test 3: admin de R1 ve solo R1 aunque query pida R2 ─────────────────────

def test_admin_r1_ignora_query_r2(client):
    """Un admin de R1 que pasa ?restaurante_id=R2 en la query debe recibir
    SOLO los ingredientes de R1 (el backend fuerza el JWT)."""
    ing_r1 = _ing_r1("Harina")
    ing_r2 = _ing_r2("Azucar")

    cursor_mock = MagicMock()
    cursor_mock.__iter__ = MagicMock(return_value=iter([ing_r1]))

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find.return_value = cursor_mock
        resp = client.get(
            "/api/v1/ingredientes?restaurante_id=R2",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    # El backend debió llamar a find con filtro {"restaurante_id": "R1"}, no "R2"
    mock_col.find.assert_called_once_with({"restaurante_id": "R1"})
    nombres = [i["nombre"] for i in resp.json()]
    assert "Harina" in nombres
    # Azucar pertenece a R2 y no debería aparecer
    assert "Azucar" not in nombres


# ─── Test 4: super_admin con ?restaurante_id=R2 filtra por R2 ────────────────

def test_super_admin_filtra_por_query(client):
    """super_admin tiene libertad: ?restaurante_id=R2 efectivamente filtra R2."""
    ing_r2 = _ing_r2("Azucar")

    cursor_mock = MagicMock()
    cursor_mock.__iter__ = MagicMock(return_value=iter([ing_r2]))

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find.return_value = cursor_mock
        resp = client.get(
            "/api/v1/ingredientes?restaurante_id=R2",
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200
    mock_col.find.assert_called_once_with({"restaurante_id": "R2"})
    nombres = [i["nombre"] for i in resp.json()]
    assert "Azucar" in nombres


# ─── Test 5: stock-bajo con admin R1 solo trae los de R1 ─────────────────────

def test_stock_bajo_filtra_por_sucursal_del_jwt(client):
    """El endpoint /stock-bajo debe aislarse al restaurante del JWT.
    Ingrediente R1 con stock bajo sí sale; el de R2 (también bajo) no sale."""
    # R1: stock bajo (cantidad <= minimo)
    ing_r1_bajo = _ing_r1("Sal", cantidad=2, minimo=5)
    # R2: también bajo, pero no debe aparecer porque el admin es de R1
    ing_r2_bajo = _ing_r2("Pimienta")
    ing_r2_bajo["cantidad_actual"] = 1
    ing_r2_bajo["stock_minimo"] = 3

    # El mock devuelve ambos pero el filtro del backend debe restringir a R1
    cursor_mock = MagicMock()
    cursor_mock.__iter__ = MagicMock(return_value=iter([ing_r1_bajo]))

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find.return_value = cursor_mock
        resp = client.get(
            "/api/v1/ingredientes/stock-bajo",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    # El filtro aplicado debe ser solo R1
    mock_col.find.assert_called_once_with({"restaurante_id": "R1"})
    nombres = [i["nombre"] for i in resp.json()]
    assert "Sal" in nombres


# ─── Test 6: por-categoria con admin R1 solo trae los de R1 ──────────────────

def test_por_categoria_filtra_por_sucursal_del_jwt(client):
    """El endpoint /por-categoria debe aislarse al restaurante del JWT."""
    ing_r1 = _ing_r1("Harina")
    ing_r2 = _ing_r2("Azucar")

    # El mock devuelve solo R1 porque el filtro correcto se aplicó
    cursor_mock = MagicMock()
    cursor_mock.__iter__ = MagicMock(return_value=iter([ing_r1]))

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find.return_value = cursor_mock
        resp = client.get(
            "/api/v1/ingredientes/por-categoria",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    mock_col.find.assert_called_once_with({"restaurante_id": "R1"})
    data = resp.json()
    # La respuesta es un dict categoria→lista
    assert isinstance(data, dict)
    todos_nombres = [
        ing["nombre"] for ings in data.values() for ing in ings
    ]
    assert "Harina" in todos_nombres
    assert "Azucar" not in todos_nombres


# ─── Test 7: admin legacy (sin restaurante_id en JWT) no restringe ────────────

def test_admin_legacy_sin_rid_no_restringe(client):
    """Cuando el JWT no lleva restaurante_id (cuenta legacy), el backend NO
    aplica restricción por sucursal (devuelve lo que el filtro de query permita
    o todo si query también es null). Queda log de advertencia."""
    ing_r1 = _ing_r1("Harina")
    ing_r2 = _ing_r2("Azucar")

    cursor_mock = MagicMock()
    cursor_mock.__iter__ = MagicMock(return_value=iter([ing_r1, ing_r2]))

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find.return_value = cursor_mock
        resp = client.get(
            "/api/v1/ingredientes",
            headers=_auth_admin_legacy_sin_rid(),
        )

    assert resp.status_code == 200
    # Sin restricción → find se llama con filtro vacío (sin restaurante_id)
    mock_col.find.assert_called_once_with({})
    nombres = [i["nombre"] for i in resp.json()]
    assert "Harina" in nombres
    assert "Azucar" in nombres


# ─── Test 8-12: duplicados y fusión ──────────────────────────────────────────

def test_duplicados_lista_grupos_con_dos_o_mas(client):
    """GET /duplicados devuelve grupos donde hay más de un ingrediente con
    el mismo nombre (normalizado a minúsculas) en la misma sucursal."""
    id1 = ObjectId()
    id2 = ObjectId()

    grupo = {
        "_id": {"rid": "R1", "nombre_norm": "pollo"},
        "ids": [id1, id2],
        "ingredientes": [
            {"_id": id1, "nombre": "Pollo", "cantidad_actual": 5, "unidad": "kg",
             "stock_minimo": 1, "categoria": "Otros", "restaurante_id": "R1"},
            {"_id": id2, "nombre": "pollo", "cantidad_actual": 3, "unidad": "kg",
             "stock_minimo": 1, "categoria": "Otros", "restaurante_id": "R1"},
        ],
        "count": 2,
    }

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.aggregate.return_value = [grupo]
        resp = client.get("/api/v1/ingredientes/duplicados", headers=_auth_admin_r1())

    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["count"] == 2
    assert data[0]["nombre_normalizado"] == "pollo"
    # Cada grupo incluye la lista completa de ingredientes formateados
    assert len(data[0]["ingredientes"]) == 2


def test_duplicados_aislamiento_admin_R1_no_ve_R2(client):
    """Un admin de R1 que llama a /duplicados solo ve duplicados de R1.
    El filtro de la aggregation debe incluir restaurante_id=R1."""
    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.aggregate.return_value = []
        resp = client.get("/api/v1/ingredientes/duplicados", headers=_auth_admin_r1())

    assert resp.status_code == 200
    # El primer stage del pipeline ($match) debe filtrar por R1
    pipeline = mock_col.aggregate.call_args[0][0]
    match_stage = pipeline[0]["$match"]
    assert match_stage.get("restaurante_id") == "R1"


def test_fusionar_suma_cantidades_y_borra_absorbidos(client):
    """POST /fusionar suma el stock de los absorbidos al principal y los borra."""
    id_principal = ObjectId()
    id_abs1 = ObjectId()
    id_abs2 = ObjectId()

    principal = {"_id": id_principal, "nombre": "Pollo", "cantidad_actual": 10.0, "restaurante_id": "R1"}
    abs1 = {"_id": id_abs1, "nombre": "pollo", "cantidad_actual": 4.0, "restaurante_id": "R1"}
    abs2 = {"_id": id_abs2, "nombre": "Pollo ", "cantidad_actual": 2.0, "restaurante_id": "R1"}
    # Después de la operación, el principal tendrá 16.0
    principal_actualizado = {**principal, "cantidad_actual": 16.0}

    mock_session = MagicMock()
    mock_session.start_transaction.return_value.__enter__ = MagicMock(return_value=None)
    mock_session.start_transaction.return_value.__exit__ = MagicMock(return_value=False)

    mock_update = MagicMock()
    mock_update.matched_count = 1
    mock_delete = MagicMock()
    mock_delete.deleted_count = 2

    def find_one_side_effect(filtro, **kwargs):
        fid = filtro.get("_id")
        if fid == id_principal:
            # Primera llamada: validar existencia; última: stock final
            return principal_actualizado
        if fid == id_abs1:
            return abs1
        if fid == id_abs2:
            return abs2
        return None

    with patch("routes.ingredientes.cliente") as mock_cliente, \
         patch("routes.ingredientes.coleccion_ingredientes") as mock_col, \
         patch("routes.ingredientes.coleccion_productos") as mock_prod:

        mock_cliente.start_session.return_value.__enter__.return_value = mock_session
        mock_col.find_one.side_effect = find_one_side_effect
        mock_col.update_one.return_value = mock_update
        mock_col.delete_many.return_value = mock_delete
        mock_prod.find.return_value = []  # sin productos referenciando estos ingredientes

        resp = client.post(
            "/api/v1/ingredientes/fusionar",
            json={
                "principal_id": str(id_principal),
                "absorber_ids": [str(id_abs1), str(id_abs2)],
            },
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["fusionados"] == 2
    # El stock final debe ser el del principal_actualizado (16.0)
    assert data["stock_total_principal"] == 16.0


def test_fusionar_reescribe_ingrediente_id_en_productos(client):
    """POST /fusionar actualiza los productos que referencian un absorbido
    para que apunten al principal."""
    id_principal = ObjectId()
    id_absorbido = ObjectId()

    principal = {"_id": id_principal, "nombre": "Harina", "cantidad_actual": 5.0, "restaurante_id": "R1"}
    absorbido = {"_id": id_absorbido, "nombre": "harina", "cantidad_actual": 3.0, "restaurante_id": "R1"}

    prod_con_referencia = {
        "_id": ObjectId(),
        "nombre": "Pan",
        "restaurante_id": "R1",
        "ingredientes": [
            {"ingrediente_id": str(id_absorbido), "nombre": "harina", "cantidad_receta": 0.5},
        ],
    }

    mock_session = MagicMock()
    mock_session.start_transaction.return_value.__enter__ = MagicMock(return_value=None)
    mock_session.start_transaction.return_value.__exit__ = MagicMock(return_value=False)

    def find_one_ing(filtro, **kwargs):
        fid = filtro.get("_id")
        if fid == id_principal:
            return {**principal, "cantidad_actual": 8.0}
        if fid == id_absorbido:
            return absorbido
        return None

    with patch("routes.ingredientes.cliente") as mock_cliente, \
         patch("routes.ingredientes.coleccion_ingredientes") as mock_ing, \
         patch("routes.ingredientes.coleccion_productos") as mock_prod:

        mock_cliente.start_session.return_value.__enter__.return_value = mock_session
        mock_ing.find_one.side_effect = find_one_ing
        mock_ing.update_one.return_value = MagicMock(matched_count=1)
        mock_ing.delete_many.return_value = MagicMock(deleted_count=1)
        # find de productos devuelve el producto con referencia al absorbido
        mock_prod.find.return_value = [prod_con_referencia]
        mock_prod.update_one.return_value = MagicMock(matched_count=1)

        resp = client.post(
            "/api/v1/ingredientes/fusionar",
            json={
                "principal_id": str(id_principal),
                "absorber_ids": [str(id_absorbido)],
            },
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200, resp.text

    # Verificar que update_one en coleccion_productos fue llamado con el nuevo ingrediente_id
    prod_update_call = mock_prod.update_one.call_args
    set_doc = prod_update_call[0][1]["$set"]
    ings_actualizados = set_doc["ingredientes"]
    assert ings_actualizados[0]["ingrediente_id"] == str(id_principal)
    assert ings_actualizados[0]["nombre"] == "Harina"


def test_fusionar_distinta_sucursal_devuelve_403(client):
    """Un admin de R1 no puede fusionar ingredientes de R2 con R1.
    Cuando el absorbido es de R2, debe devolver 403."""
    id_principal = ObjectId()
    id_absorbido_r2 = ObjectId()

    principal = {"_id": id_principal, "nombre": "Sal", "cantidad_actual": 5.0, "restaurante_id": "R1"}
    absorbido_r2 = {"_id": id_absorbido_r2, "nombre": "sal", "cantidad_actual": 2.0, "restaurante_id": "R2"}

    def find_one_side(filtro, **kwargs):
        fid = filtro.get("_id")
        if fid == id_principal:
            return principal
        if fid == id_absorbido_r2:
            return absorbido_r2
        return None

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find_one.side_effect = find_one_side

        resp = client.post(
            "/api/v1/ingredientes/fusionar",
            json={
                "principal_id": str(id_principal),
                "absorber_ids": [str(id_absorbido_r2)],
            },
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 403
