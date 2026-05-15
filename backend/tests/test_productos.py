"""Tests de normalización del array `ingredientes` en los endpoints de productos,
y aislamiento multi-tenant de POST /asignar-sucursal (Fix 1).

Cubre el Bug 3: _normalizar_payload debe reducir cada item del array al esquema
mínimo {ingrediente_id?, nombre, cantidad_receta} descartando campos congelados
como cantidadActual, unidad, stockMinimo, categoria, etc.
"""
from unittest.mock import MagicMock, patch
from bson import ObjectId

from tests.tok_helpers import tok


# ─── Helpers de autenticación ────────────────────────────────────────────────

def _auth_admin(rid: str = "R1") -> dict:
    return tok("admin", restaurante_id=rid)


def _auth_super_admin() -> dict:
    return tok("super_admin")


# ─── Tests Fix 1 — POST /asignar-sucursal: aislamiento multi-tenant ──────────

def test_asignar_sucursal_admin_usa_rid_del_jwt_ignora_payload(client):
    """Admin de R1 que manda restaurante_id=R2 en payload debe ver su operación
    ejecutarse sobre R1 (el JWT manda, el payload se ignora)."""
    mock_result = MagicMock()
    mock_result.modified_count = 3
    mock_result.matched_count = 3

    with patch("routes.productos.coleccion_productos") as mock_col:
        mock_col.update_many.return_value = mock_result
        resp = client.post(
            "/api/v1/productos/asignar-sucursal",
            json={
                "restaurante_id": "R2",  # admin intenta apuntar a otra sucursal
                "ids": [str(ObjectId()), str(ObjectId()), str(ObjectId())],
            },
            headers=_auth_admin("R1"),
        )

    assert resp.status_code == 200, resp.text
    # El update_many debe haberse llamado con $set = {"restaurante_id": "R1"} (JWT), no "R2"
    call_args = mock_col.update_many.call_args
    set_doc = call_args[0][1]["$set"]
    assert set_doc["restaurante_id"] == "R1", (
        f"Se esperaba R1 (JWT) pero se usó '{set_doc['restaurante_id']}'"
    )


def test_asignar_sucursal_super_admin_usa_payload(client):
    """super_admin puede asignar productos a cualquier sucursal usando el payload."""
    mock_result = MagicMock()
    mock_result.modified_count = 2
    mock_result.matched_count = 2

    with patch("routes.productos.coleccion_productos") as mock_col:
        mock_col.update_many.return_value = mock_result
        resp = client.post(
            "/api/v1/productos/asignar-sucursal",
            json={
                "restaurante_id": "R2",  # super_admin apunta a R2 → válido
                "ids": [str(ObjectId()), str(ObjectId())],
            },
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200, resp.text
    call_args = mock_col.update_many.call_args
    set_doc = call_args[0][1]["$set"]
    assert set_doc["restaurante_id"] == "R2"


def test_asignar_sucursal_admin_sin_rid_jwt_devuelve_400(client):
    """Admin cuyo JWT no lleva restaurante_id (legacy) recibe 400."""
    from security import crear_token
    from tests.tok_helpers import insertar_usuario_test
    from bson import ObjectId as OID

    legacy_oid = OID("cccccccccccccccccccccccc")
    insertar_usuario_test(legacy_oid, "admin", restaurante_id=None)
    token = crear_token({"sub": str(legacy_oid), "correo": "legacy@test.com", "rol": "admin"})
    headers = {"Authorization": f"Bearer {token}"}

    resp = client.post(
        "/api/v1/productos/asignar-sucursal",
        json={"restaurante_id": "R1", "solo_huerfanos": True},
        headers=headers,
    )

    assert resp.status_code == 400
    assert "sucursal" in resp.json()["detail"].lower()


# ─── Tests de normalización en POST /productos ───────────────────────────────

def test_crear_producto_normaliza_ingredientes_a_esquema_minimo(client):
    """El frontend manda un objeto ingrediente completo con campos extra.
    Tras el POST, la BD debe almacenar solo {ingrediente_id, nombre, cantidad_receta}."""
    nuevo_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = nuevo_id

    payload_frontend = {
        "nombre": "Pizza Margarita",
        "descripcion": "Con tomate y mozzarella",
        "precio": 10.0,
        "categoria": "Pizzas",
        "ingredientes": [
            {
                "ingredienteId": str(ObjectId()),
                "nombre": "Mozzarella",
                "cantidadReceta": 2,
                # Campos extra que el frontend manda (deben descartarse):
                "cantidadActual": 50,
                "unidad": "kg",
                "stockMinimo": 5,
                "categoria": "Lacteos",
                "stockBajo": False,
            }
        ],
    }

    with patch("routes.productos.coleccion_productos") as mock_col:
        mock_col.find_one.return_value = None
        mock_col.insert_one.return_value = mock_insert

        resp = client.post("/api/v1/productos", json=payload_frontend, headers=_auth_admin())

    assert resp.status_code == 200, resp.text

    # Verificar lo que se insertó en BD
    doc_insertado = mock_col.insert_one.call_args[0][0]
    ings = doc_insertado["ingredientes"]
    assert len(ings) == 1

    ing_guardado = ings[0]
    # Solo debe tener las 3 claves del esquema mínimo
    assert "nombre" in ing_guardado
    assert "cantidad_receta" in ing_guardado
    assert ing_guardado["nombre"] == "Mozzarella"
    assert ing_guardado["cantidad_receta"] == 2.0
    # Campos del inventario NO deben estar
    assert "cantidadActual" not in ing_guardado
    assert "unidad" not in ing_guardado
    assert "stockMinimo" not in ing_guardado
    assert "stockBajo" not in ing_guardado
    assert "categoria" not in ing_guardado


def test_crear_producto_acepta_string_suelto_como_ingrediente_legacy(client):
    """Input con ingrediente como string suelto → normaliza a {nombre, cantidad_receta: 1.0}."""
    nuevo_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = nuevo_id

    payload = {
        "nombre": "Pollo al horno",
        "descripcion": "",
        "precio": 8.0,
        "categoria": "Carnes",
        "ingredientes": ["Pollo", "Sal"],
    }

    with patch("routes.productos.coleccion_productos") as mock_col:
        mock_col.find_one.return_value = None
        mock_col.insert_one.return_value = mock_insert

        resp = client.post("/api/v1/productos", json=payload, headers=_auth_admin())

    assert resp.status_code == 200, resp.text

    doc_insertado = mock_col.insert_one.call_args[0][0]
    ings = doc_insertado["ingredientes"]
    assert len(ings) == 2

    nombres = [i["nombre"] for i in ings]
    assert "Pollo" in nombres
    assert "Sal" in nombres

    for ing in ings:
        assert ing["cantidad_receta"] == 1.0
        # No debe haber id si el input era un string
        assert "ingrediente_id" not in ing


def test_actualizar_producto_normaliza_igual(client):
    """El PUT debe aplicar la misma normalización que el POST."""
    prod_id = ObjectId()
    prod_existente = {
        "_id": prod_id,
        "nombre": "Pizza Vieja",
        "descripcion": "",
        "precio": 9.0,
        "categoria": "Pizzas",
        "ingredientes": [],
        "restaurante_id": "R1",
    }

    payload = {
        "nombre": "Pizza Nueva",
        "descripcion": "",
        "precio": 9.0,
        "categoria": "Pizzas",
        "ingredientes": [
            {
                "id": str(ObjectId()),
                "nombre": "Queso",
                "cantidadReceta": 1.5,
                # Campos extra que deben descartarse
                "cantidadActual": 20,
                "unidad": "kg",
            }
        ],
    }

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.productos.coleccion_productos") as mock_col:
        # find_one: primera llamada verifica existencia; segunda devuelve el actualizado
        mock_col.find_one.side_effect = [prod_existente, {**prod_existente, "nombre": "Pizza Nueva"}]
        mock_col.update_one.return_value = mock_update

        resp = client.put(
            f"/api/v1/productos/{str(prod_id)}",
            json=payload,
            headers=_auth_admin(),
        )

    assert resp.status_code == 200, resp.text

    # Verificar el $set que se mandó a Mongo
    set_doc = mock_col.update_one.call_args[0][1]["$set"]
    ings = set_doc["ingredientes"]
    assert len(ings) == 1

    ing = ings[0]
    assert ing["nombre"] == "Queso"
    assert ing["cantidad_receta"] == 1.5
    assert "cantidadActual" not in ing
    assert "unidad" not in ing
