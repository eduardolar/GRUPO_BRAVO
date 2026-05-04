"""Endpoint tests for /api/v1/pedidos with mocked MongoDB."""
from unittest.mock import AsyncMock, MagicMock, patch
from bson import ObjectId


ITEM_VALIDO = {"producto_id": "507f1f77bcf86cd799439011", "nombre": "Pizza", "cantidad": 2, "precio": 12.50}
PEDIDO_VALIDO = {
    "userId": "507f1f77bcf86cd799439011",
    "items": [ITEM_VALIDO],
    "tipoEntrega": "local",
    "metodoPago": "efectivo",
}


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
        resp = client.get("/api/v1/pedidos")

    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["estado"] == "pendiente"
    assert data[0]["total"] == 25.0


def test_obtener_pedidos_por_usuario(client):
    user_id = "507f1f77bcf86cd799439011"

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.find.return_value = []
        resp = client.get(f"/api/v1/pedidos?userId={user_id}")

    assert resp.status_code == 200
    mock_pedidos.find.assert_called_once_with({"usuario_id": user_id})


# ── Actualizar estado ─────────────────────────────────────────────────────────

def test_actualizar_estado_valido(client):
    pedido_id = str(ObjectId())
    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(f"/api/v1/pedidos/{pedido_id}/estado", json={"estado": "preparando"})

    assert resp.status_code == 200
    assert resp.json()["estado"] == "preparando"


def test_actualizar_estado_invalido_devuelve_422(client):
    pedido_id = str(ObjectId())
    resp = client.patch(f"/api/v1/pedidos/{pedido_id}/estado", json={"estado": "volando"})
    assert resp.status_code == 422


def test_actualizar_estado_pedido_inexistente_devuelve_404(client):
    pedido_id = str(ObjectId())
    mock_result = MagicMock()
    mock_result.matched_count = 0

    with patch("routes.pedidos.coleccion_pedidos") as mock_pedidos:
        mock_pedidos.update_one.return_value = mock_result
        resp = client.patch(f"/api/v1/pedidos/{pedido_id}/estado", json={"estado": "listo"})

    assert resp.status_code == 404
