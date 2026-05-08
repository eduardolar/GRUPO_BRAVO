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
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "items": []},
                       headers=_auth_cliente())
    assert resp.status_code == 422


def test_crear_pedido_sin_token_devuelve_401(client):
    """POST /pedidos sin token debe devolver 401."""
    resp = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO)
    assert resp.status_code == 401


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

        resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "total": 0.01},
                           headers=_auth_cliente())

    assert resp.status_code == 200
    assert resp.json()["total"] == 25.0


def test_metodo_pago_invalido_devuelve_422(client):
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "metodoPago": "cripto"},
                       headers=_auth_cliente())
    assert resp.status_code == 422


def test_tipo_entrega_invalido_devuelve_422(client):
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "tipoEntrega": "volando"},
                       headers=_auth_cliente())
    assert resp.status_code == 422


def test_item_cantidad_cero_devuelve_422(client):
    item_malo = {**ITEM_VALIDO, "cantidad": 0}
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "items": [item_malo]},
                       headers=_auth_cliente())
    assert resp.status_code == 422


def test_item_precio_negativo_devuelve_422(client):
    item_malo = {**ITEM_VALIDO, "precio": -1}
    resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "items": [item_malo]},
                       headers=_auth_cliente())
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

        resp = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=_auth_cliente())

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

        resp = client.post("/api/v1/pedidos", json={**PEDIDO_VALIDO, "tipoEntrega": "mesa"},
                           headers=_auth_cliente())

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

        resp = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=_auth_cliente())

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

    pedido_doc = {"_id": ObjectId(pedido_id), "restaurante_id": "r1", "estado": "pendiente"}

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = pedido_doc
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

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = None  # pedido no existe
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


# ── GET /pedidos/resumen ──────────────────────────────────────────────────────

def _pedido_doc(
    total: float,
    fecha: str,
    metodo: str = "efectivo",
    tipo: str = "local",
    estado: str = "listo",
    items: list | None = None,
    restaurante_id: str = "r1",
) -> dict:
    """Factoría de documentos de pedido para los tests de resumen."""
    if items is None:
        items = [{"producto_id": "p1", "nombre": "Pizza", "cantidad": 1, "precio": total}]
    return {
        "_id": ObjectId(),
        "fecha": fecha,
        "total": total,
        "estado": estado,
        "metodo_pago": metodo,
        "tipo_entrega": tipo,
        "items": items,
        "restaurante_id": restaurante_id,
    }


def test_resumen_calcula_totales(client):
    """3 pedidos 'listo' → ingresos, pedidos y ticket_medio correctos."""
    docs = [
        _pedido_doc(10.0, "2025-05-01T10:00:00"),
        _pedido_doc(20.0, "2025-05-01T11:00:00"),
        _pedido_doc(30.0, "2025-05-02T09:00:00"),
    ]

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = docs
        resp = client.get("/api/v1/pedidos/resumen", headers=_auth_admin())

    assert resp.status_code == 200
    data = resp.json()
    assert data["totales"]["ingresos"] == 60.0
    assert data["totales"]["pedidos"] == 3
    assert data["totales"]["ticket_medio"] == 20.0


def test_resumen_agrupa_por_dia(client):
    """2 pedidos el día A y 1 el día B → 2 entradas en por_dia."""
    docs = [
        _pedido_doc(10.0, "2025-05-01T10:00:00"),
        _pedido_doc(10.0, "2025-05-01T15:00:00"),
        _pedido_doc(10.0, "2025-05-02T09:00:00"),
    ]

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = docs
        resp = client.get("/api/v1/pedidos/resumen", headers=_auth_admin())

    assert resp.status_code == 200
    por_dia = resp.json()["por_dia"]
    assert len(por_dia) == 2
    dias = {d["fecha"] for d in por_dia}
    assert "2025-05-01" in dias
    assert "2025-05-02" in dias
    dia_a = next(d for d in por_dia if d["fecha"] == "2025-05-01")
    assert dia_a["pedidos"] == 2
    assert dia_a["ingresos"] == 20.0


def test_resumen_filtra_por_metodo_pago(client):
    """Mezcla 'Efectivo'/'efectivo' + 'tarjeta' → backend agrupa case-insensitive
    y devuelve el label canónico ('Efectivo', 'Tarjeta')."""
    docs = [
        _pedido_doc(50.0, "2025-05-01T10:00:00", metodo="efectivo"),
        _pedido_doc(50.0, "2025-05-01T11:00:00", metodo="Efectivo"),
        _pedido_doc(100.0, "2025-05-01T12:00:00", metodo="tarjeta"),
    ]

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = docs
        resp = client.get("/api/v1/pedidos/resumen", headers=_auth_admin())

    assert resp.status_code == 200
    metodos = {m["metodo"]: m for m in resp.json()["por_metodo_pago"]}
    assert metodos["Efectivo"]["pedidos"] == 2
    assert metodos["Tarjeta"]["pedidos"] == 1
    # Los porcentajes deben sumar 100 (con tolerancia de redondeo)
    suma_pct = sum(m["porcentaje"] for m in resp.json()["por_metodo_pago"])
    assert abs(suma_pct - 100.0) < 0.2


def test_resumen_top_productos_ordena_desc(client):
    """3 productos con distintas unidades → orden descendente por unidades."""
    docs = [
        _pedido_doc(10.0, "2025-05-01T10:00:00", items=[
            {"producto_id": "pA", "nombre": "Paella", "cantidad": 5, "precio": 2.0},
        ]),
        _pedido_doc(10.0, "2025-05-01T11:00:00", items=[
            {"producto_id": "pB", "nombre": "Burger", "cantidad": 10, "precio": 1.0},
        ]),
        _pedido_doc(10.0, "2025-05-01T12:00:00", items=[
            {"producto_id": "pC", "nombre": "Wrap", "cantidad": 2, "precio": 5.0},
        ]),
    ]

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = docs
        resp = client.get("/api/v1/pedidos/resumen", headers=_auth_admin())

    assert resp.status_code == 200
    top = resp.json()["top_productos"]
    assert top[0]["nombre"] == "Burger"   # 10 unidades
    assert top[1]["nombre"] == "Paella"   # 5 unidades
    assert top[2]["nombre"] == "Wrap"     # 2 unidades


def test_resumen_top_productos_limita_a_10(client):
    """15 productos distintos → solo devuelve 10 en top_productos."""
    items_15 = [
        {"producto_id": f"p{i}", "nombre": f"Prod{i}", "cantidad": i + 1, "precio": 1.0}
        for i in range(15)
    ]
    doc = _pedido_doc(100.0, "2025-05-01T10:00:00", items=items_15)

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = [doc]
        resp = client.get("/api/v1/pedidos/resumen", headers=_auth_admin())

    assert resp.status_code == 200
    assert len(resp.json()["top_productos"]) == 10


def test_resumen_sin_token_devuelve_401(client):
    """Sin Authorization Bearer → 401."""
    resp = client.get("/api/v1/pedidos/resumen")
    assert resp.status_code == 401


def test_resumen_aislamiento_admin(client):
    """Admin de r1 con query restaurante_id=r2 → el filtro usa r1 (del JWT), no r2."""
    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos/resumen?restaurante_id=r2",
            headers=_auth_admin(),  # JWT lleva restaurante_id=r1
        )

    assert resp.status_code == 200
    filtro = mock_col.find.call_args[0][0]
    # El $or debe referenciar r1 (del JWT), nunca r2
    or_vals = [c.get("restaurante_id") for c in filtro.get("$or", [])]
    assert "r1" in or_vals, "Debe filtrar por el restaurante del JWT"
    assert "r2" not in or_vals, "No debe respetar el restaurante_id del query param en admin"


# ── GET /pedidos/exportar ─────────────────────────────────────────────────────

def test_export_csv_content_type_y_disposition(client):
    """Exportar en CSV → Content-Type text/csv y Content-Disposition attachment."""
    doc = _pedido_doc(25.0, "2025-05-01T10:00:00")

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = [doc]
        resp = client.get(
            "/api/v1/pedidos/exportar?formato=csv&fecha_desde=2025-05-01&fecha_hasta=2025-05-01",
            headers=_auth_admin(),
        )

    assert resp.status_code == 200
    ct = resp.headers.get("content-type", "")
    assert "text/csv" in ct
    cd = resp.headers.get("content-disposition", "")
    assert "attachment" in cd
    assert ".csv" in cd
    # Verificar cabecera CSV (delimitador `;` para Excel en es-ES)
    texto = resp.content.decode("utf-8-sig")
    assert texto.startswith("fecha;id;total")


def test_export_pdf_si_disponible(client):
    """Si reportlab no está instalado → 501; si está → 200 con content-type pdf."""
    try:
        import reportlab  # noqa: F401
        reportlab_disponible = True
    except ImportError:
        reportlab_disponible = False

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find.return_value = []
        resp = client.get(
            "/api/v1/pedidos/exportar?formato=pdf",
            headers=_auth_admin(),
        )

    if reportlab_disponible:
        assert resp.status_code == 200
        assert "application/pdf" in resp.headers.get("content-type", "")
    else:
        assert resp.status_code == 501
        assert "reportlab" in resp.json()["detail"].lower()


def test_export_rango_excesivo_devuelve_400(client):
    """Un rango de más de 90 días → 422 (ValidacionError)."""
    resp = client.get(
        "/api/v1/pedidos/exportar?fecha_desde=2025-01-01&fecha_hasta=2025-04-20&formato=csv",
        headers=_auth_admin(),
    )
    # ValidacionError devuelve 422 según el handler del proyecto
    assert resp.status_code == 422
    assert "90" in resp.json()["detail"]


def test_export_formato_invalido_devuelve_422(client):
    """Un valor de ?formato distinto de 'csv' o 'pdf' → 422 por validación FastAPI."""
    resp = client.get(
        "/api/v1/pedidos/exportar?formato=excel",
        headers=_auth_admin(),
    )
    assert resp.status_code == 422


# ── Idempotency Key ───────────────────────────────────────────────────────────

def _make_pedido_mock(pedido_id=None):
    """Devuelve los mocks necesarios para crear un pedido con éxito."""
    if pedido_id is None:
        pedido_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = pedido_id
    return pedido_id, mock_insert


def test_doble_post_misma_idempotency_key_devuelve_mismo_id(client):
    """Dos POST con la misma Idempotency-Key y el mismo usuario devuelven el mismo pedido."""
    pedido_id = ObjectId()
    mock_insert = MagicMock()
    mock_insert.inserted_id = pedido_id

    # Primer pedido existente que devolverá find_one en la segunda llamada
    pedido_existente = {
        "_id": pedido_id,
        "usuario_id": "u_cliente",
        "fecha": "2025-01-01T10:00:00",
        "total": 25.0,
        "estado": "pendiente",
        "estado_pago": "pendiente",
        "items": [ITEM_VALIDO],
        "idempotency_key": "key-abc-123",
    }

    headers = {**_auth_cliente("u_cliente"), "Idempotency-Key": "key-abc-123"}

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos") as mock_pedidos, \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes"), \
         patch("routes.pedidos.coleccion_usuarios") as mock_usuarios, \
         patch("routes.pedidos._enviar_factura", new_callable=AsyncMock):

        mock_productos.find_one.return_value = {"precio": 12.50, "ingredientes": []}
        mock_usuarios.find_one.return_value = None
        mock_session = MagicMock()
        mock_cliente.start_session.return_value.__enter__.return_value = mock_session

        # Primera llamada: find_one → None (no existe), insert_one devuelve nuevo pedido
        mock_pedidos.find_one.return_value = None
        mock_pedidos.insert_one.return_value = mock_insert
        resp1 = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=headers)

        # Segunda llamada: find_one → devuelve el pedido existente (mismo id)
        mock_pedidos.find_one.return_value = pedido_existente
        resp2 = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=headers)

    assert resp1.status_code == 200, resp1.json()
    assert resp2.status_code == 200, resp2.json()
    # Ambas respuestas deben devolver el mismo id
    assert resp1.json()["id"] == str(pedido_id)
    assert resp2.json()["id"] == str(pedido_id)


def test_doble_post_sin_idempotency_key_crea_dos_pedidos(client):
    """Dos POST sin Idempotency-Key deben crear dos pedidos distintos (compatibilidad)."""
    id1 = ObjectId()
    id2 = ObjectId()
    mock_insert1 = MagicMock()
    mock_insert1.inserted_id = id1
    mock_insert2 = MagicMock()
    mock_insert2.inserted_id = id2

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos") as mock_pedidos, \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes"), \
         patch("routes.pedidos.coleccion_usuarios") as mock_usuarios, \
         patch("routes.pedidos._enviar_factura", new_callable=AsyncMock):

        mock_productos.find_one.return_value = {"precio": 12.50, "ingredientes": []}
        mock_usuarios.find_one.return_value = None
        mock_session = MagicMock()
        mock_cliente.start_session.return_value.__enter__.return_value = mock_session

        # Sin header Idempotency-Key: find_one no debe ser llamado para idempotencia
        mock_pedidos.insert_one.return_value = mock_insert1
        resp1 = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=_auth_cliente("u_cliente"))

        mock_pedidos.insert_one.return_value = mock_insert2
        resp2 = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=_auth_cliente("u_cliente"))

    assert resp1.status_code == 200, resp1.json()
    assert resp2.status_code == 200, resp2.json()
    # Deben ser pedidos distintos
    assert resp1.json()["id"] != resp2.json()["id"]
    assert resp1.json()["id"] == str(id1)
    assert resp2.json()["id"] == str(id2)


def test_misma_idempotency_key_usuario_distinto_crea_pedido_nuevo(client):
    """Misma Idempotency-Key con distinto usuario_id crea pedidos independientes."""
    id_u1 = ObjectId()
    id_u2 = ObjectId()
    mock_insert_u1 = MagicMock()
    mock_insert_u1.inserted_id = id_u1
    mock_insert_u2 = MagicMock()
    mock_insert_u2.inserted_id = id_u2

    same_key = "shared-key-xyz"

    with patch("routes.pedidos.cliente") as mock_cliente, \
         patch("routes.pedidos.coleccion_pedidos") as mock_pedidos, \
         patch("routes.pedidos.coleccion_productos") as mock_productos, \
         patch("routes.pedidos.coleccion_ingredientes"), \
         patch("routes.pedidos.coleccion_usuarios") as mock_usuarios, \
         patch("routes.pedidos._enviar_factura", new_callable=AsyncMock):

        mock_productos.find_one.return_value = {"precio": 12.50, "ingredientes": []}
        mock_usuarios.find_one.return_value = None
        mock_session = MagicMock()
        mock_cliente.start_session.return_value.__enter__.return_value = mock_session

        # Usuario 1: find_one → None, crea pedido nuevo
        mock_pedidos.find_one.return_value = None
        mock_pedidos.insert_one.return_value = mock_insert_u1
        headers_u1 = {**_auth_cliente("u_user1"), "Idempotency-Key": same_key}
        resp1 = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=headers_u1)

        # Usuario 2: find_one → None (clave misma pero usuario distinto, no existe),
        # crea también su pedido nuevo
        mock_pedidos.find_one.return_value = None
        mock_pedidos.insert_one.return_value = mock_insert_u2
        headers_u2 = {**_auth_cliente("u_user2"), "Idempotency-Key": same_key}
        resp2 = client.post("/api/v1/pedidos", json=PEDIDO_VALIDO, headers=headers_u2)

    assert resp1.status_code == 200, resp1.json()
    assert resp2.status_code == 200, resp2.json()
    # Usuarios distintos → pedidos distintos aunque la key sea la misma
    assert resp1.json()["id"] == str(id_u1)
    assert resp2.json()["id"] == str(id_u2)
    assert resp1.json()["id"] != resp2.json()["id"]


# ═══════════════════════════════════════════════════════════════════════════
# Bloqueantes de seguridad — auditoría rol cocinero
# ═══════════════════════════════════════════════════════════════════════════

def _make_pedido_doc(
    pedido_id,
    restaurante_id: str = "r1",
    usuario_id: str = "u_cliente",
) -> dict:
    """Documento mínimo de pedido para mockear coleccion_pedidos.find_one."""
    return {
        "_id": ObjectId(pedido_id) if isinstance(pedido_id, str) else pedido_id,
        "restaurante_id": restaurante_id,
        "usuario_id": usuario_id,
        "items": [],
        "total": 10.0,
        "estado": "pendiente",
        "estado_pago": "pendiente",
        "fecha": "2025-01-01T12:00:00",
    }


def _auth_cocinero_r2() -> dict:
    """Cocinero de la sucursal r2 (distinta a r1)."""
    token = crear_token({
        "sub": "u_cocinero_r2", "correo": "cocinero2@test.com",
        "rol": "cocinero", "restaurante_id": "r2",
    })
    return {"Authorization": f"Bearer {token}"}


def _auth_camarero_r2() -> dict:
    """Camarero de la sucursal r2 (distinta a r1)."""
    token = crear_token({
        "sub": "u_camarero_r2", "correo": "camarero2@test.com",
        "rol": "camarero", "restaurante_id": "r2",
    })
    return {"Authorization": f"Bearer {token}"}


# ── Bloqueante 1: GET /pedidos/{id} ──────────────────────────────────────────

def test_obtener_pedido_sin_token_devuelve_401(client):
    """GET /pedidos/{id} sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.get(f"/api/v1/pedidos/{pedido_id}")
    assert resp.status_code == 401


def test_obtener_pedido_cliente_pedido_ajeno_devuelve_403(client):
    """Cliente con usuario_id distinto al del pedido → 403."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1", usuario_id="u_otro")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.get(
            f"/api/v1/pedidos/{pedido_id}",
            headers=_auth_cliente("u_cliente"),  # sub != u_otro
        )

    assert resp.status_code == 403


def test_obtener_pedido_cliente_pedido_propio_devuelve_200(client):
    """Cliente cuyo sub coincide con usuario_id del pedido → 200."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1", usuario_id="u_cliente")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.get(
            f"/api/v1/pedidos/{pedido_id}",
            headers=_auth_cliente("u_cliente"),
        )

    assert resp.status_code == 200


def test_obtener_pedido_cocinero_otra_sucursal_devuelve_403(client):
    """Cocinero de sucursal r2 accede a pedido de r1 → 403."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.get(
            f"/api/v1/pedidos/{pedido_id}",
            headers=_auth_cocinero_r2(),
        )

    assert resp.status_code == 403


def test_obtener_pedido_cocinero_misma_sucursal_devuelve_200(client):
    """Cocinero de sucursal r1 accede a pedido de r1 → 200."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.get(
            f"/api/v1/pedidos/{pedido_id}",
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200


def test_obtener_pedido_super_admin_devuelve_200(client):
    """super_admin puede leer cualquier pedido sin restricción de sucursal."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="cualquier_sucursal")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.get(
            f"/api/v1/pedidos/{pedido_id}",
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200


# ── Bloqueante 2: PATCH /pedidos/{id} y /pedidos/{id}/items ──────────────────

def test_patch_pedido_sin_token_devuelve_401(client):
    """PATCH /pedidos/{id} sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.patch(f"/api/v1/pedidos/{pedido_id}", json={"estado": "listo"})
    assert resp.status_code == 401


def test_patch_pedido_cliente_devuelve_403(client):
    """Cliente no puede hacer PATCH /pedidos/{id} (solo camarero/admin/super_admin)."""
    pedido_id = str(ObjectId())
    resp = client.patch(
        f"/api/v1/pedidos/{pedido_id}",
        json={"estado": "listo"},
        headers=_auth_cliente(),
    )
    assert resp.status_code == 403


def test_patch_pedido_cocinero_devuelve_403(client):
    """Cocinero no puede modificar items completos ni total (no es su rol)."""
    pedido_id = str(ObjectId())
    resp = client.patch(
        f"/api/v1/pedidos/{pedido_id}",
        json={"estado": "listo"},
        headers=_auth_cocinero(),
    )
    assert resp.status_code == 403


def test_patch_pedido_camarero_misma_sucursal_devuelve_200(client):
    """Camarero de la misma sucursal puede hacer PATCH /pedidos/{id} → 200."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}",
            json={"estado": "listo"},
            headers=_auth_camarero(),
        )

    assert resp.status_code == 200


def test_patch_pedido_camarero_otra_sucursal_devuelve_403(client):
    """Camarero de sucursal r2 no puede modificar pedido de r1 → 403."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}",
            json={"estado": "listo"},
            headers=_auth_camarero_r2(),
        )

    assert resp.status_code == 403


def test_patch_items_sin_token_devuelve_401(client):
    """PATCH /pedidos/{id}/items sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.patch(
        f"/api/v1/pedidos/{pedido_id}/items",
        json={"items": [], "total": 0},
    )
    assert resp.status_code == 401


def test_patch_items_camarero_otra_sucursal_devuelve_403(client):
    """Camarero de otra sucursal no puede modificar items del pedido → 403."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items",
            json={"items": [], "total": 0},
            headers=_auth_camarero_r2(),
        )

    assert resp.status_code == 403


def test_patch_items_camarero_misma_sucursal_devuelve_200(client):
    """Camarero de la misma sucursal puede modificar items → 200."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        mock_pedidos.update_one.return_value = MagicMock()
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items",
            json={"items": [], "total": 0},
            headers=_auth_camarero(),
        )

    assert resp.status_code == 200


# ── Bloqueante 3: PATCH /pedidos/actualizar-estado-pago ──────────────────────

def test_actualizar_estado_pago_sin_token_devuelve_401(client):
    """Sin token → 401."""
    resp = client.patch(
        "/api/v1/pedidos/actualizar-estado-pago",
        json={"referenciaPago": "ref_123", "estadoPago": "pagado"},
    )
    assert resp.status_code == 401


def test_actualizar_estado_pago_cliente_propio_devuelve_200(client):
    """Cliente puede actualizar el pago de su propio pedido (referencia suya) → 200."""
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            "/api/v1/pedidos/actualizar-estado-pago",
            json={"referenciaPago": "ref_123", "estadoPago": "pagado"},
            headers=_auth_cliente("u_cliente"),
        )

    assert resp.status_code == 200
    # El filtro debe incluir usuario_id del cliente
    filtro = mock_pedidos.update_one.call_args[0][0]
    assert filtro["usuario_id"] == "u_cliente"
    assert filtro["referencia_pago"] == "ref_123"


def test_actualizar_estado_pago_cocinero_devuelve_403(client):
    """Cocinero no tiene permiso para marcar pagos → 403."""
    resp = client.patch(
        "/api/v1/pedidos/actualizar-estado-pago",
        json={"referenciaPago": "ref_123", "estadoPago": "pagado"},
        headers=_auth_cocinero(),
    )
    assert resp.status_code == 403


def test_actualizar_estado_pago_camarero_sin_restriccion_usuario(client):
    """Camarero puede actualizar el pago sin restricción de usuario_id."""
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            "/api/v1/pedidos/actualizar-estado-pago",
            json={"referenciaPago": "ref_456", "estadoPago": "pagado"},
            headers=_auth_camarero(),
        )

    assert resp.status_code == 200
    filtro = mock_pedidos.update_one.call_args[0][0]
    # Camarero no filtra por usuario_id
    assert "usuario_id" not in filtro


# ── Bloqueante 4: PATCH /pedidos/{id}/estado y /items/{idx}/hecho ────────────

def test_actualizar_estado_cocinero_otra_sucursal_devuelve_403(client):
    """Cocinero de otra sucursal no puede cambiar estado de pedido ajeno → 403."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "preparando"},
            headers=_auth_cocinero_r2(),
        )

    assert resp.status_code == 403


def test_marcar_item_hecho_cocinero_otra_sucursal_devuelve_403(client):
    """Cocinero de otra sucursal no puede marcar item como hecho → 403."""
    pedido_id = str(ObjectId())
    item_id = "item-uuid-r2-test"
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["items"] = [{"nombre": "Pizza", "hecho": False, "item_id": item_id}]

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items/{item_id}/hecho",
            json={"hecho": True},
            headers=_auth_cocinero_r2(),
        )

    assert resp.status_code == 403


def test_marcar_item_hecho_cocinero_misma_sucursal_devuelve_200(client):
    """Cocinero de la misma sucursal puede marcar item como hecho → 200 (endpoint por item_id)."""
    pedido_id = str(ObjectId())
    item_id = "item-uuid-1234"
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["items"] = [{"nombre": "Pizza", "hecho": False, "item_id": item_id}]
    doc["estado"] = "preparando"
    doc_actualizado = {**doc, "items": [{"nombre": "Pizza", "hecho": True, "item_id": item_id}]}
    doc_actualizado["estado"] = "preparando"

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.side_effect = [doc, doc_actualizado]
        mock_pedidos.update_one.return_value = mock_update
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items/{item_id}/hecho",
            json={"hecho": True},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["hecho"] is True


# ═══════════════════════════════════════════════════════════════════════════
# Nuevos tests — importantes cerrados (rol cocinero)
# ═══════════════════════════════════════════════════════════════════════════

# ── Importante 1: Máquina de estados ─────────────────────────────────────────

def test_estado_entregado_a_pendiente_devuelve_409(client):
    """Transición terminal entregado → pendiente debe devolver 409 Conflict."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "entregado"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "pendiente"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 409
    assert "entregado" in resp.json()["detail"].lower() or "terminal" in resp.json()["detail"].lower()


def test_estado_cancelado_a_listo_devuelve_409(client):
    """Transición terminal cancelado → listo debe devolver 409 Conflict."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "cancelado"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "listo"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 409


def test_estado_pendiente_a_preparando_devuelve_200(client):
    """Transición válida pendiente → preparando debe devolver 200."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "pendiente"
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "preparando"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["estado"] == "preparando"


def test_estado_listo_a_entregado_devuelve_200(client):
    """Transición válida listo → entregado debe devolver 200."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "listo"
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "entregado"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["estado"] == "entregado"


def test_estado_noop_devuelve_200_sin_cambio(client):
    """Transición no-op (mismo estado) debe devolver 200 con updated=False."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "preparando"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "preparando"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["updated"] is False


def test_estado_salto_invalido_pendiente_a_listo_devuelve_409(client):
    """No se puede saltar directamente de pendiente a listo (sin pasar por preparando)."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "pendiente"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "listo"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 409


def test_estado_pendiente_a_cancelado_devuelve_200(client):
    """pendiente → cancelado es una transición válida."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "pendiente"
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/estado",
            json={"estado": "cancelado"},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200


# ── Importante 2: extra="forbid" en modelos ───────────────────────────────────

def test_actualizar_estado_con_campo_extra_devuelve_422(client):
    """ActualizarEstado con campo extra → 422 (extra='forbid')."""
    pedido_id = str(ObjectId())
    resp = client.patch(
        f"/api/v1/pedidos/{pedido_id}/estado",
        json={"estado": "preparando", "campo_inventado": "x"},
        headers=_auth_cocinero(),
    )
    assert resp.status_code == 422


def test_item_pedido_campo_extra_devuelve_422(client):
    """POST /pedidos con item que tiene campo extra → 422."""
    item_con_extra = {**ITEM_VALIDO, "campo_secreto": "hack"}
    resp = client.post(
        "/api/v1/pedidos",
        json={**PEDIDO_VALIDO, "items": [item_con_extra]},
        headers=_auth_cliente(),
    )
    assert resp.status_code == 422


# ── Importante 3 y 4: marcar_item_hecho con item_id ──────────────────────────

def test_marcar_item_hecho_item_id_valido_devuelve_200(client):
    """Marcar item como hecho con item_id válido → 200."""
    pedido_id = str(ObjectId())
    item_id = "uuid-item-valido-001"
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "preparando"
    doc["items"] = [
        {"nombre": "Burger", "hecho": False, "item_id": item_id},
        {"nombre": "Fries", "hecho": True, "item_id": "uuid-item-002"},
    ]
    doc_actualizado = {**doc, "items": [
        {"nombre": "Burger", "hecho": True, "item_id": item_id},
        {"nombre": "Fries", "hecho": True, "item_id": "uuid-item-002"},
    ]}

    mock_update = MagicMock()
    mock_update.matched_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.side_effect = [doc, doc_actualizado]
        mock_pedidos.update_one.return_value = mock_update
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items/{item_id}/hecho",
            json={"hecho": True},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["hecho"] is True
    assert resp.json()["todosHechos"] is True


def test_marcar_item_hecho_item_id_invalido_devuelve_404(client):
    """Marcar item con item_id inexistente → 404."""
    pedido_id = str(ObjectId())
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "preparando"
    doc["items"] = [{"nombre": "Pizza", "hecho": False, "item_id": "uuid-correcto"}]

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items/uuid-inexistente/hecho",
            json={"hecho": True},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 404


def test_marcar_item_hecho_pedido_entregado_devuelve_409(client):
    """Marcar item en pedido entregado (estado terminal) → 409."""
    pedido_id = str(ObjectId())
    item_id = "uuid-item-terminal"
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "entregado"
    doc["items"] = [{"nombre": "Pizza", "hecho": True, "item_id": item_id}]

    # matched_count=0 simula que el update_one no matcheó (estado terminal)
    mock_update = MagicMock()
    mock_update.matched_count = 0

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.return_value = doc
        mock_pedidos.update_one.return_value = mock_update
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items/{item_id}/hecho",
            json={"hecho": True},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 409


def test_marcar_item_todos_hechos_transiciona_a_listo(client):
    """Cuando todos los items quedan hechos, el pedido transiciona automáticamente a listo."""
    pedido_id = str(ObjectId())
    item_id = "uuid-unico"
    doc = _make_pedido_doc(pedido_id, restaurante_id="r1")
    doc["estado"] = "preparando"
    doc["items"] = [{"nombre": "Pizza", "hecho": False, "item_id": item_id}]
    doc_actualizado = {**doc, "items": [{"nombre": "Pizza", "hecho": True, "item_id": item_id}]}
    doc_actualizado["estado"] = "preparando"  # el estado no ha cambiado aún

    mock_update = MagicMock()
    mock_update.matched_count = 1
    mock_update_listo = MagicMock()
    mock_update_listo.matched_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find_one.side_effect = [doc, doc_actualizado]
        mock_pedidos.update_one.return_value = mock_update
        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}/items/{item_id}/hecho",
            json={"hecho": True},
            headers=_auth_cocinero(),
        )

    assert resp.status_code == 200
    assert resp.json()["todosHechos"] is True
    # Debe haberse llamado update_one al menos 2 veces: marcar hecho + transición a listo
    assert mock_pedidos.update_one.call_count >= 2
