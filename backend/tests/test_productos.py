"""Tests de normalización del array `ingredientes` en los endpoints de productos.

Cubre el Bug 3: _normalizar_payload debe reducir cada item del array al esquema
mínimo {ingrediente_id?, nombre, cantidad_receta} descartando campos congelados
como cantidadActual, unidad, stockMinimo, categoria, etc.
"""
from unittest.mock import MagicMock, patch
from bson import ObjectId

from security import crear_token


# ─── Helpers de autenticación ────────────────────────────────────────────────

def _auth_admin() -> dict:
    token = crear_token({
        "sub": "u_admin",
        "correo": "admin@test.com",
        "rol": "admin",
        "restaurante_id": "R1",
    })
    return {"Authorization": f"Bearer {token}"}


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
