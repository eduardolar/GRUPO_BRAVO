"""Endpoint tests for /api/v1/pedidos with mocked MongoDB."""
from unittest.mock import AsyncMock, MagicMock, patch
from bson import ObjectId

from security import crear_token


ITEM_VALIDO = {"producto_id": "507f1f77bcf86cd799439011", "nombre": "Pizza", "cantidad": 2, "precio": 12.50}
PEDIDO_VALIDO = {
    "userId": "507f1f77bcf86cd799439011",
    "items": [ITEM_VALIDO],
    "tipoEntrega": "local",
    "metodoPago": "efectivo",
}


def _auth_cocinero() -> dict:
    """Header Authorization con un token de cocinero válido para los tests
    de mutación de pedidos (cambiar estado, marcar items)."""
    token = crear_token({"sub": "u1", "correo": "cocinero@test.com", "rol": "cocinero", "restaurante_id": "r1"})
    return {"Authorization": f"Bearer {token}"}


def _auth_cliente(user_id: str = "u_cliente") -> dict:
    token = crear_token({"sub": user_id, "correo": "cliente@test.com", "rol": "cliente"})
    return {"Authorization": f"Bearer {token}"}


def _auth_camarero() -> dict:
    token = crear_token({"sub": "u2", "correo": "camarero@test.com", "rol": "camarero", "restaurante_id": "r1"})
    return {"Authorization": f"Bearer {token}"}


def _auth_admin() -> dict:
    token = crear_token({"sub": "u3", "correo": "admin@test.com", "rol": "admin", "restaurante_id": "r1"})
    return {"Authorization": f"Bearer {token}"}


def _auth_super_admin() -> dict:
    token = crear_token({"sub": "u4", "correo": "superadmin@test.com", "rol": "super_admin"})
    return {"Authorization": f"Bearer {token}"}


# ── Validación (sin BD) ───────────────────────────────────────────────────────

def test_items_vacios_devuelven_422(client):
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "items": []})
    assert resp.status_code == 422


def test_total_del_cliente_es_ignorado(client):
    """El campo total enviado por el cliente nunca debe persistirse — el backend lo calcula."""
    pedido_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = pedido_id

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos") as mock_pedidos, \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes"), \
         patch("routes.pedidos.coleccion_usuarios") as mock_usuarios, \
         patch("routes.pedidos._enviar_factura", new_callable=AsyncMock):

        mock_pedidos.insert_one.return_value = mock_insert
        mock_productos.find_one.return_value = {"precio": 12.50, "ingredientes": []}
        mock_usuarios.find_one.return_value = None
        mock_session = MagicMock()
        mock_cliente.start_session.return_value.__enter__.return_value = mock_session

        resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "total": 0.01})

    assert resp.status_code == 200
    assert resp.json()["total"] == 25.0


def test_metodo_pago_invalido_devuelve_422(client):
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "metodoPago": "cripto"})
    assert resp.status_code == 422


def test_tipo_entrega_invalido_devuelve_422(client):
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "tipoEntrega": "volando"})
    assert resp.status_code == 422


def test_item_cantidad_cero_devuelve_422(client):
    item_malo = {**ITEM_VALIDO, "cantidad": 0}
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "items": [item_malo]})
    assert resp.status_code == 422


def test_item_precio_negativo_devuelve_422(client):
    item_malo = {**ITEM_VALIDO, "precio": -1}
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "items": [item_malo]})
    assert resp.status_code == 422


# ── Happy path (BD mockeada) ──────────────────────────────────────────────────

def test_crear_pedido_ok(client):
    pedido_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = pedido_id

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos") as mock_pedidos, \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes"), \
         patch("routes.pedidos.coleccion_usuarios") as mock_usuarios, \
         patch("routes.pedidos._enviar_factura", new_callable=AsyncMock):

        mock_pedidos.insert_one.return_value = mock_insert
        mock_productos.find_one.return_value = {"precio": 12.50, "ingredientes": []}
        mock_usuarios.find_one.return_value = None  # evita envío de correo

        # MagicMock soporta context managers por defecto (__exit__ retorna False)
        mock_session = MagicMock()
        mock_cliente.start_session.return_value.__enter__.return_value = mock_session

        resp = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO)

    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == str(pedido_id)
    assert data["estado"] == "pendiente"
    assert data["total"] == 25.0  # 12.50 (DB price) × 2 (cantidad)


def test_tipo_entrega_mesa_normaliza_a_local(client):
    pedido_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = pedido_id

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos") as mock_pedidos, \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes"), \
         patch("routes.pedidos.coleccion_usuarios") as mock_usuarios, \
         patch("routes.pedidos._enviar_factura", new_callable=AsyncMock):

        mock_pedidos.insert_one.return_value = mock_insert
        mock_productos.find_one.return_value = {"precio": 12.50, "ingredientes": []}
        mock_usuarios.find_one.return_value = None

        resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "tipoEntrega": "mesa"})

    assert resp.status_code == 200


# ── Stock insuficiente → 409 ──────────────────────────────────────────────────

def test_stock_insuficiente_devuelve_409(client):
    mock_update = MagicMock()
    mock_update.matched_count = 0  # simula stock agotado

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos"), \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes") as mock_ing, \
         patch("routes.pedidos.coleccion_usuarios"):

        mock_productos.find_one.return_value = {
            "precio": 12.50,
            "ingredientes": [{"nombre": "harina", "cantidad_receta": 2}],
        }
        mock_ing.update_one.return_value = mock_update
        mock_session = MagicMock()
        mock_cliente.start_session.return_value.__enter__.return_value = mock_session

        resp = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO)

    assert resp.status_code == 409
    assert "harina" in resp.json()["detail"].lower() or "stock" in resp.json()["detail"].lower()


# ── Consultar pedidos ─────────────────────────────────────────────────────────

def test_obtener_pedidos_devuelve_lista(client):
    pedido_doc = {
        "_id": ObjectId(),
        "fecha": "2024-01-01T12:00:00",
        "total": 25.0,
        "estado": "pendiente",
        "estado_pago": "pendiente",
        "items": [ITEM_VALIDO],
        "tipo_entrega": "local",
        "metodo_pago": "efectivo",
    }

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = [pedido_doc]
        resp = client.get("/api/v1/pedidos", headers=_auth_cocinero())

    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["estado"] == "pendiente"
    assert data[0]["total"] == 25.0


def test_obtener_pedidos_por_usuario(client):
    """Cocinero con restaurante_id en JWT: el filtro incluye el $or por sucursal."""
    user_id = "507f1f77bcf86cd799439011"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(f"/api/v1/pedidos?userId={user_id}", headers=_auth_cocinero())

    assert resp.status_code == 200
    # El JWT del cocinero lleva restaurante_id=r1, así que el filtro incluye $or
    call_args = mock_pedidos.find.call_args[0][0]
    assert call_args["usuario_id"] == user_id
    assert "$or" in call_args


# ── Actualizar estado ─────────────────────────────────────────────────────────

def test_actualizar_estado_valido(client):
    pedido_id = str(ObjectId())
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "preparando"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["estado"] == "preparando"


def test_actualizar_estado_invalido_devuelve_422(client):
    pedido_id = str(ObjectId())
    resp = client.patch(
        f"/api/v1/pedidos/{pedido_id}/estado",
        json={"estado": "volando"},
        headers=_auth_cocinero(),
    )
    assert resp.status_code == 422


def test_actualizar_estado_pedido_inexistente_devuelve_404(client):
    pedido_id = str(ObjectId())
    mock_result = MagicMock()
    mock_result.matched_count = 0

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "listo"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 404


def test_actualizar_estado_sin_token_devuelve_401(client):
    """Sin Authorization Bearer, el endpoint de cocina debe rechazar."""
    pedido_id = str(ObjectId())
    resp = client.patch(f"/api/v1/pedidos/{pedido_id}/estado", json={"estado": "listo"})
    assert resp.status_code == 401


def test_actualizar_estado_con_rol_cliente_devuelve_403(client):
    """Un cliente no debe poder mover su propio pedido a 'listo' saltándose
    a la cocina."""
    pedido_id = str(ObjectId())
    token = crear_token({"sub": "u2", "correo": "c@x.com", "rol": "cliente"})
    resp = client.patch(
        f"/api/v1/pedidos/{pedido_id}/estado",
        json={"estado": "listo"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403


# ── GET /pedidos: autenticación ───────────────────────────────────────────────

def test_obtener_pedidos_sin_token_devuelve_401(client):
    """El endpoint GET /pedidos debe exigir token; sin él → 401."""
    resp = client.get("/api/v1/pedidos")
    assert resp.status_code == 401


# ── GET /pedidos: multi-estado ────────────────────────────────────────────────

def test_obtener_pedidos_estados_csv_usa_in(client):
    """?estados=pendiente,preparando genera {"estado": {"$in": [...]}} en Mongo."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?estados=pendiente,preparando",
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert filtro["estado"] == {"$in": ["pendiente", "preparando"]}


def test_obtener_pedidos_estado_unico_retrocompat(client):
    """?estado=listo (parámetro individual) sigue funcionando → filtro directo."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?estado=listo",
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert filtro["estado"] == "listo"


def test_obtener_pedidos_estados_invalido_devuelve_422(client):
    """Un estado desconocido en ?estados= debe devolver 422."""
    resp = client.get(
        "/api/v1/pedidos?estados=pendiente,volando",
        headers=_auth_super_admin(),
    )
    assert resp.status_code == 422


def test_obtener_pedidos_estado_individual_invalido_devuelve_422(client):
    """?estado=fantasma también debe devolver 422."""
    resp = client.get(
        "/api/v1/pedidos?estado=fantasma",
        headers=_auth_super_admin(),
    )
    assert resp.status_code == 422


def test_obtener_pedidos_estados_prioriza_sobre_estado(client):
    """Cuando se envían ?estados= y ?estado= a la vez, ?estados= tiene prioridad."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?estados=pendiente,listo&estado=entregado",
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    # estados= prioriza → $in con los dos valores, nunca "entregado"
    assert filtro["estado"] == {"$in": ["pendiente", "listo"]}


# ── GET /pedidos: aislamiento por rol ─────────────────────────────────────────

def test_cliente_solo_ve_sus_pedidos(client):
    """Un cliente no puede ver pedidos ajenos pasando userId de otro usuario."""
    propio_id = "u_cliente"
    ajeno_id = "u_otro"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            f"/api/v1/pedidos?userId={ajeno_id}",
            headers=_auth_cliente(propio_id),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    # Debe usar el sub del JWT, no el userId de la query
    assert filtro["usuario_id"] == propio_id
    assert filtro["usuario_id"] != ajeno_id


def test_cocinero_puede_filtrar_por_estados(client):
    """Personal (cocinero) puede usar ?estados= sin que se sobreescriba userId."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?estados=pendiente,preparando,listo",
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert filtro["estado"] == {"$in": ["pendiente", "preparando", "listo"]}
    # El cocinero no debe tener usuario_id forzado
    assert "usuario_id" not in filtro


def test_camarero_puede_filtrar_pedidos(client):
    """Camarero autenticado puede listar pedidos sin que se modifique el userId."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get("/api/v1/pedidos", headers=_auth_camarero())

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert "usuario_id" not in filtro


def test_admin_puede_filtrar_pedidos(client):
    """Admin autenticado puede listar pedidos sin que se modifique el userId."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get("/api/v1/pedidos", headers=_auth_admin())

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert "usuario_id" not in filtro


# ── Bug 1 fix: descuento por ingrediente_id ───────────────────────────────────

def test_descuento_por_ingrediente_id_no_se_confunde_con_homonimos(client):
    """Dos ingredientes con el mismo nombre en la misma sucursal pero distinto id.
    El producto referencia el id del primero. Solo el primero debe ser descontado."""
    from unittest.mock import call
    from bson import ObjectId
    from routes.pedidos import _descontar_stock

    id_correcto = ObjectId()
    id_otro = ObjectId()

    ing_correcto = {
        "_id": id_correcto,
        "nombre": "Pollo",
        "cantidad_actual": 10,
        "restaurante_id": "R1",
    }
    ing_otro = {
        "_id": id_otro,
        "nombre": "Pollo",
        "cantidad_actual": 10,
        "restaurante_id": "R1",
    }

    producto_doc = {
        "_id": ObjectId(),
        "restaurante_id": "R1",
        "ingredientes": [
            {"ingrediente_id": str(id_correcto), "nombre": "Pollo", "cantidad_receta": 1},
        ],
    }

    actualizado_correcto = {"_id": id_correcto, "cantidad_actual": 8, "restaurante_id": "R1"}
    actualizado_otro = {"_id": id_otro, "cantidad_actual": 10, "restaurante_id": "R1"}

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.pedidos.coleccion_productos") as mock_prod, \
         patch("routes.pedidos.coleccion_ingredientes") as mock_ing:

        mock_prod.find_one.return_value = producto_doc
        mock_ing.update_one.return_value = mock_update

        _descontar_stock(
            [{"producto_id": str(producto_doc["_id"]), "cantidad": 2}],
            restaurante_id="R1",
        )

    # El filtro del update_one debe usar _id, no nombre regex
    call_filtro = mock_ing.update_one.call_args[0][0]
    assert call_filtro["_id"] == id_correcto, "Debe filtrar por el id concreto, no por nombre"
    assert "nombre" not in call_filtro, "No debe haber filtro por nombre cuando hay id"


def test_descuento_respeta_cantidad_receta_camelcase(client):
    """cantidadReceta=3 en el item del producto; cantidad pedida=2 → descuenta 6."""
    from routes.pedidos import _descontar_stock

    prod_id = ObjectId()
    producto_doc = {
        "_id": prod_id,
        "restaurante_id": "R1",
        "ingredientes": [
            {"nombre": "Harina", "cantidadReceta": 3},
        ],
    }

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.pedidos.coleccion_productos") as mock_prod, \
         patch("routes.pedidos.coleccion_ingredientes") as mock_ing:

        mock_prod.find_one.return_value = producto_doc
        mock_ing.update_one.return_value = mock_update

        _descontar_stock(
            [{"producto_id": str(prod_id), "cantidad": 2}],
            restaurante_id="R1",
        )

    # El $inc debe ser -6 (2 pedidos × 3 de receta)
    inc_valor = mock_ing.update_one.call_args[0][1]["$inc"]["cantidad_actual"]
    assert inc_valor == -6, f"Se esperaba -6 pero se obtuvo {inc_valor}"


def test_descuento_respeta_cantidad_receta_snake_case(client):
    """cantidad_receta=3 (snake_case) en el item del producto; cantidad pedida=2 → descuenta 6."""
    from routes.pedidos import _descontar_stock

    prod_id = ObjectId()
    producto_doc = {
        "_id": prod_id,
        "restaurante_id": "R1",
        "ingredientes": [
            {"nombre": "Harina", "cantidad_receta": 3},
        ],
    }

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.pedidos.coleccion_productos") as mock_prod, \
         patch("routes.pedidos.coleccion_ingredientes") as mock_ing:

        mock_prod.find_one.return_value = producto_doc
        mock_ing.update_one.return_value = mock_update

        _descontar_stock(
            [{"producto_id": str(prod_id), "cantidad": 2}],
            restaurante_id="R1",
        )

    inc_valor = mock_ing.update_one.call_args[0][1]["$inc"]["cantidad_actual"]
    assert inc_valor == -6, f"Se esperaba -6 pero se obtuvo {inc_valor}"


# ── GET /pedidos: filtros temporales ─────────────────────────────────────────

def _auth_admin_r1() -> dict:
    """Header Authorization con un token de admin de la sucursal r1."""
    token = crear_token({"sub": "u3", "correo": "admin@test.com", "rol": "admin", "restaurante_id": "r1"})
    return {"Authorization": f"Bearer {token}"}


def test_obtener_pedidos_filtra_por_fecha_desde(client):
    """?fecha_desde=2025-01-15 añade $gte con la hora normalizada al inicio del día."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?fecha_desde=2025-01-15",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert "fecha" in filtro
    assert filtro["fecha"]["$gte"] == "2025-01-15T00:00:00"
    assert "$lte" not in filtro["fecha"]


def test_obtener_pedidos_filtra_por_fecha_hasta(client):
    """?fecha_hasta=2025-01-31 añade $lte extendido al fin del día (T23:59:59)."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?fecha_hasta=2025-01-31",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert "fecha" in filtro
    assert filtro["fecha"]["$lte"] == "2025-01-31T23:59:59"
    assert "$gte" not in filtro["fecha"]


def test_obtener_pedidos_filtra_por_rango_fechas(client):
    """?fecha_desde y ?fecha_hasta juntos generan $gte y $lte en el mismo campo."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos?fecha_desde=2025-01-01&fecha_hasta=2025-01-31",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.find.call_args[0][0]
    assert filtro["fecha"]["$gte"] == "2025-01-01T00:00:00"
    assert filtro["fecha"]["$lte"] == "2025-01-31T23:59:59"


def test_obtener_pedidos_fecha_invalida_devuelve_422(client):
    """Una fecha con formato inválido debe devolver 422 sin consultar la BD."""
    resp = client.get(
        "/api/v1/pedidos?fecha_desde=ma%C3%B1ana",
        headers=_auth_admin_r1(),
    )
    assert resp.status_code == 422


def test_obtener_pedidos_limit_aplica_sort_desc(client):
    """?limit=50 debe llamar a .sort('fecha', -1).limit(50) en el cursor."""
    mock_cursor = MagicMock()
    mock_cursor.sort.return_value.limit.return_value = []

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = mock_cursor
        resp = client.get(
            "/api/v1/pedidos?limit=50",
            headers=_auth_admin_r1(),
        )

    assert resp.status_code == 200
    # Verificar que se encadenó .sort("fecha", -1).limit(50)
    mock_cursor.sort.assert_called_once_with("fecha", -1)
    mock_cursor.sort.return_value.limit.assert_called_once_with(50)


def test_obtener_pedidos_limit_fuera_de_rango_devuelve_422(client):
    """?limit=2000 excede el máximo de 1000 y debe devolver 422 vía validación FastAPI."""
    resp = client.get(
        "/api/v1/pedidos?limit=2000",
        headers=_auth_admin_r1(),
    )
    assert resp.status_code == 422


# ─────────────────────────────────────────────────────────────────────────────

def test_descuento_legacy_solo_nombre_sigue_funcionando(client):
    """Producto sin ingrediente_id en los items; el descuento cae al matching por nombre."""
    from routes.pedidos import _descontar_stock

    prod_id = ObjectId()
    producto_doc = {
        "_id": prod_id,
        "restaurante_id": "R1",
        "ingredientes": [
            # Sin ninguna clave de id: solo nombre
            {"nombre": "Tomate", "cantidad_receta": 1},
        ],
    }

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.pedidos.coleccion_productos") as mock_prod, \
         patch("routes.pedidos.coleccion_ingredientes") as mock_ing:

        mock_prod.find_one.return_value = producto_doc
        mock_ing.update_one.return_value = mock_update

        _descontar_stock(
            [{"producto_id": str(prod_id), "cantidad": 1}],
            restaurante_id="R1",
        )

    # El filtro debe usar regex de nombre, NO _id
    call_filtro = mock_ing.update_one.call_args[0][0]
    assert "nombre" in call_filtro, "Sin ingrediente_id debe filtrar por nombre"
    assert "_id" not in call_filtro, "No debe haber _id en filtro legacy"
