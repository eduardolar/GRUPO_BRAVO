"""Tests de los 4 cambios de deuda técnica:
  C1 - POST /ingredientes/{id}/poner-a-cero (camarero)
  C2 - /avisos-falta (CRUD)
  C3 - version en PATCH /pedidos/{id}
  C4 - Idempotency-Key en PATCH /mesas/{id}
"""
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch
from bson import ObjectId

from security import crear_token


# ─── Helpers de autenticación ────────────────────────────────────────────────

def _tok(rol: str, rid: str = "R1", sub: str = None) -> dict:
    payload = {
        "sub": sub or f"u_{rol}",
        "correo": f"{rol}@test.com",
        "rol": rol,
    }
    if rid:
        payload["restaurante_id"] = rid
    token = crear_token(payload)
    return {"Authorization": f"Bearer {token}"}


def _camarero_r1() -> dict:
    return _tok("camarero", "R1")


def _camarero_r2() -> dict:
    return _tok("camarero", "R2")


def _admin_r1() -> dict:
    return _tok("admin", "R1")


def _super_admin() -> dict:
    return _tok("super_admin", rid=None)


def _cliente() -> dict:
    return _tok("cliente", rid=None)


def _cocinero_r1() -> dict:
    return _tok("cocinero", "R1")


# ═══════════════════════════════════════════════════════════════════════════════
# C1 — POST /ingredientes/{id}/poner-a-cero
# ═══════════════════════════════════════════════════════════════════════════════

def _ing(rid: str = "R1") -> dict:
    return {
        "_id": ObjectId(),
        "nombre": "Harina",
        "cantidad_actual": 10,
        "unidad": "kg",
        "stock_minimo": 2,
        "categoria": "Cereales",
        "restaurante_id": rid,
    }


def test_c1_camarero_pone_stock_a_cero_propio_restaurante(client):
    """Camarero de R1 puede poner a 0 un ingrediente de R1 → 200."""
    ing = _ing("R1")
    ing_id = str(ing["_id"])

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find_one.return_value = ing
        mock_col.update_one.return_value = MagicMock()

        resp = client.post(
            f"/api/v1/ingredientes/{ing_id}/poner-a-cero",
            headers=_camarero_r1(),
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["ingrediente_id"] == ing_id
    # Verificar que se llamó a update_one con $set cantidad_actual: 0
    call_args = mock_col.update_one.call_args[0]
    assert call_args[1]["$set"]["cantidad_actual"] == 0


def test_c1_camarero_r1_no_puede_poner_a_cero_ingrediente_r2(client):
    """Camarero de R1 no puede poner a 0 un ingrediente de R2 → 403."""
    ing_r2 = _ing("R2")
    ing_id = str(ing_r2["_id"])

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find_one.return_value = ing_r2

        resp = client.post(
            f"/api/v1/ingredientes/{ing_id}/poner-a-cero",
            headers=_camarero_r1(),
        )

    assert resp.status_code == 403


def test_c1_cliente_no_puede_poner_a_cero(client):
    """Cliente no tiene acceso a poner-a-cero → 403."""
    ing_id = str(ObjectId())
    resp = client.post(
        f"/api/v1/ingredientes/{ing_id}/poner-a-cero",
        headers=_cliente(),
    )
    assert resp.status_code == 403


def test_c1_ingrediente_inexistente_devuelve_404(client):
    """Si el ingrediente no existe → 404."""
    ing_id = str(ObjectId())

    with patch("routes.ingredientes.coleccion_ingredientes") as mock_col:
        mock_col.find_one.return_value = None

        resp = client.post(
            f"/api/v1/ingredientes/{ing_id}/poner-a-cero",
            headers=_camarero_r1(),
        )

    assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════════════
# C2 — /avisos-falta
# ═══════════════════════════════════════════════════════════════════════════════

def test_c2_camarero_crea_aviso_persiste_restaurante_id(client):
    """Camarero de R1 crea un aviso → 200 con id, doc incluye restaurante_id=R1."""
    nuevo_id = ObjectId()
    mock_result = MagicMock()
    mock_result.inserted_id = nuevo_id

    with patch("routes.avisos_falta.coleccion_avisos_falta") as mock_col:
        mock_col.insert_one.return_value = mock_result

        resp = client.post(
            "/api/v1/avisos-falta",
            json={"ingredienteNombre": "Sal", "notas": "Se acabó en la mañana"},
            headers=_camarero_r1(),
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "id" in data

    # Verificar que el documento insertado tiene restaurante_id de R1 y sub
    doc_insertado = mock_col.insert_one.call_args[0][0]
    assert doc_insertado["restaurante_id"] == "R1"
    assert doc_insertado["creado_por_sub"] == "u_camarero"
    assert doc_insertado["estado"] == "pendiente"
    assert doc_insertado["ingrediente_nombre"] == "Sal"


def test_c2_admin_lista_solo_avisos_de_su_restaurante(client):
    """Admin de R1 lista avisos: solo ve los de R1."""
    aviso_r1 = {
        "_id": ObjectId(),
        "restaurante_id": "R1",
        "ingrediente_nombre": "Aceite",
        "estado": "pendiente",
        "creado_at": datetime.now(timezone.utc).isoformat(),
    }

    with patch("routes.avisos_falta.coleccion_avisos_falta") as mock_col:
        mock_cursor = MagicMock()
        mock_cursor.sort.return_value = [aviso_r1]
        mock_col.find.return_value = mock_cursor

        resp = client.get("/api/v1/avisos-falta", headers=_admin_r1())

    assert resp.status_code == 200, resp.text
    # El filtro aplicado debe incluir restaurante_id=R1
    filtro = mock_col.find.call_args[0][0]
    assert filtro.get("restaurante_id") == "R1"
    data = resp.json()
    assert isinstance(data, list)


def test_c2_admin_marca_aviso_como_atendido(client):
    """Admin de R1 puede marcar aviso de R1 como atendido → 200 con estado atendido."""
    aviso_id = ObjectId()
    aviso = {
        "_id": aviso_id,
        "restaurante_id": "R1",
        "ingrediente_nombre": "Sal",
        "estado": "pendiente",
        "creado_at": datetime.now(timezone.utc).isoformat(),
    }
    aviso_atendido = {**aviso, "estado": "atendido", "atendido_por_sub": "u_admin", "atendido_at": "2026-01-01T00:00:00"}

    with patch("routes.avisos_falta.coleccion_avisos_falta") as mock_col:
        mock_col.find_one.side_effect = [aviso, aviso_atendido]
        mock_col.update_one.return_value = MagicMock()

        resp = client.patch(
            f"/api/v1/avisos-falta/{str(aviso_id)}",
            json={"estado": "atendido", "notas_admin": "Reabastecido"},
            headers=_admin_r1(),
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["estado"] == "atendido"


def test_c2_cliente_no_puede_crear_aviso(client):
    """Cliente no tiene acceso a crear avisos → 403."""
    resp = client.post(
        "/api/v1/avisos-falta",
        json={"ingredienteNombre": "Sal"},
        headers=_cliente(),
    )
    assert resp.status_code == 403


def test_c2_cocinero_no_puede_crear_aviso(client):
    """Cocinero no tiene acceso a crear avisos → 403."""
    resp = client.post(
        "/api/v1/avisos-falta",
        json={"ingredienteNombre": "Sal"},
        headers=_cocinero_r1(),
    )
    assert resp.status_code == 403


def test_c2_admin_r1_no_puede_atender_aviso_r2(client):
    """Admin de R1 no puede marcar como atendido un aviso de R2 → 403."""
    aviso_id = ObjectId()
    aviso_r2 = {
        "_id": aviso_id,
        "restaurante_id": "R2",
        "ingrediente_nombre": "Pimienta",
        "estado": "pendiente",
        "creado_at": datetime.now(timezone.utc).isoformat(),
    }

    with patch("routes.avisos_falta.coleccion_avisos_falta") as mock_col:
        mock_col.find_one.return_value = aviso_r2

        resp = client.patch(
            f"/api/v1/avisos-falta/{str(aviso_id)}",
            json={"estado": "atendido"},
            headers=_admin_r1(),
        )

    assert resp.status_code == 403


# ═══════════════════════════════════════════════════════════════════════════════
# C3 — version en PATCH /pedidos/{id}
# ═══════════════════════════════════════════════════════════════════════════════

def _pedido_base(version: int = 1, rid: str = "R1") -> dict:
    return {
        "_id": ObjectId(),
        "usuario_id": "u2",
        "restaurante_id": rid,
        "estado": "pendiente",
        "estado_pago": "pendiente",
        "items": [{"producto_id": "p1", "nombre": "Pizza", "cantidad": 1, "precio": 10.0}],
        "total": 10.0,
        "fecha": datetime.now(timezone.utc).isoformat(),
        "version": version,
    }


def test_c3_patch_items_con_version_correcta_incrementa_version(client):
    """PATCH /pedidos/{id} con version correcta → 200 y version se incrementa."""
    pedido = _pedido_base(version=3)
    pedido_id = str(pedido["_id"])

    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido
        mock_col.update_one.return_value = mock_result

        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}",
            json={"items": [{"producto_id": "p1", "nombre": "Pizza", "cantidad": 2, "precio": 10.0}], "version": 3},
            headers=_camarero_r1(),
        )

    assert resp.status_code == 200, resp.text
    assert resp.json()["updated"] is True
    # Verificar que el filtro incluyó version=3
    filtro_usado = mock_col.update_one.call_args[0][0]
    assert filtro_usado.get("version") == 3
    # Verificar que se seteó version=4
    set_doc = mock_col.update_one.call_args[0][1]["$set"]
    assert set_doc.get("version") == 4


def test_c3_patch_items_con_version_desfasada_devuelve_409(client):
    """PATCH /pedidos/{id} con version desfasada → 409 conflicto."""
    pedido = _pedido_base(version=5)
    pedido_id = str(pedido["_id"])

    mock_result = MagicMock()
    mock_result.matched_count = 0  # simula que la version no coincide
    mock_result.modified_count = 0

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido
        mock_col.update_one.return_value = mock_result

        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}",
            json={"items": [], "version": 3},  # version incorrecta (debería ser 5)
            headers=_camarero_r1(),
        )

    assert resp.status_code == 409, resp.text
    assert "versión" in resp.json()["detail"].lower() or "version" in resp.json()["detail"].lower()


def test_c3_patch_items_sin_version_aplica_cambio_compat(client):
    """PATCH /pedidos/{id} sin version → 200 (comportamiento legacy, sin filtro de version)."""
    pedido = _pedido_base(version=2)
    pedido_id = str(pedido["_id"])

    mock_result = MagicMock()
    mock_result.matched_count = 1
    mock_result.modified_count = 1

    with patch("routes.pedidos.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido
        mock_col.update_one.return_value = mock_result

        resp = client.patch(
            f"/api/v1/pedidos/{pedido_id}",
            json={"items": [{"producto_id": "p1", "nombre": "Pizza", "cantidad": 3, "precio": 10.0}]},
            headers=_camarero_r1(),
        )

    assert resp.status_code == 200, resp.text
    # Sin version en payload → filtro NO incluye "version"
    filtro_usado = mock_col.update_one.call_args[0][0]
    assert "version" not in filtro_usado


# ═══════════════════════════════════════════════════════════════════════════════
# C4 — Idempotency-Key en PATCH /mesas/{id}
# ═══════════════════════════════════════════════════════════════════════════════

def _mesa_r1(con_ik: bool = False, hace_segundos: int = 10) -> dict:
    m: dict = {
        "_id": ObjectId(),
        "numero": 3,
        "capacidad": 4,
        "ubicacion": "interior",
        "codigoQr": "QR-R1-03",
        "estado": "libre",
        "restaurante_id": "R1",
    }
    if con_ik:
        ts = (datetime.now(timezone.utc) - timedelta(seconds=hace_segundos)).isoformat()
        m["ultima_idempotency_key"] = "IK-DUPLICADA"
        m["ultima_idempotency_at"] = ts
    return m


def test_c4_idempotency_key_duplicada_dentro_30s_devuelve_estado_sin_cambiar(client):
    """Misma Idempotency-Key en < 30 s → devuelve estado actual sin modificar."""
    mesa = _mesa_r1(con_ik=True, hace_segundos=5)  # clave puesta hace 5 s
    mesa_id = str(mesa["_id"])

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = mesa

        resp = client.patch(
            f"/api/v1/mesas/{mesa_id}",
            json={"disponible": False},  # intenta cambiar a ocupada
            headers={**_camarero_r1(), "Idempotency-Key": "IK-DUPLICADA"},
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    # El estado debe ser el original (libre), no el que se intentó cambiar
    assert data["estado"] == "libre"
    assert data.get("idempotent") is True
    # update_one NO debe haberse llamado
    mock_col.update_one.assert_not_called()


def test_c4_idempotency_key_duplicada_despues_30s_aplica_cambio(client):
    """Misma clave pero > 30 s → el cambio se aplica normalmente."""
    mesa = _mesa_r1(con_ik=True, hace_segundos=35)  # hace 35 s: expirado
    mesa_id = str(mesa["_id"])

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = mesa
        mock_col.update_one.return_value = MagicMock()

        resp = client.patch(
            f"/api/v1/mesas/{mesa_id}",
            json={"disponible": False},
            headers={**_camarero_r1(), "Idempotency-Key": "IK-DUPLICADA"},
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["estado"] == "ocupada"
    mock_col.update_one.assert_called_once()


def test_c4_sin_idempotency_key_comportamiento_normal(client):
    """Sin header Idempotency-Key → comportamiento original."""
    mesa = _mesa_r1()
    mesa_id = str(mesa["_id"])

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = mesa
        mock_col.update_one.return_value = MagicMock()

        resp = client.patch(
            f"/api/v1/mesas/{mesa_id}",
            json={"disponible": False},
            headers=_camarero_r1(),
        )

    assert resp.status_code == 200, resp.text
    assert resp.json()["estado"] == "ocupada"
    mock_col.update_one.assert_called_once()
    # $set no debe incluir idempotency_key porque no se mandó
    set_fields = mock_col.update_one.call_args[0][1]["$set"]
    assert "ultima_idempotency_key" not in set_fields


def test_c4_idempotency_key_nueva_persiste_en_mesa(client):
    """Clave nueva → se persiste ultima_idempotency_key en el documento."""
    mesa = _mesa_r1()  # sin clave previa
    mesa_id = str(mesa["_id"])

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = mesa
        mock_col.update_one.return_value = MagicMock()

        resp = client.patch(
            f"/api/v1/mesas/{mesa_id}",
            json={"disponible": True},
            headers={**_camarero_r1(), "Idempotency-Key": "IK-NUEVA-XYZ"},
        )

    assert resp.status_code == 200, resp.text
    set_fields = mock_col.update_one.call_args[0][1]["$set"]
    assert set_fields.get("ultima_idempotency_key") == "IK-NUEVA-XYZ"
    assert "ultima_idempotency_at" in set_fields
