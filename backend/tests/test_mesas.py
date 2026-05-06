"""Tests para PUT /api/v1/mesas/{mesa_id} — editar datos de una mesa."""
from unittest.mock import MagicMock, patch
from bson import ObjectId

from security import crear_token


# ─── Helpers de autenticación ────────────────────────────────────────────────

def _auth_admin(rid: str = "R1") -> dict:
    token = crear_token({"sub": "u_admin", "correo": "admin@test.com", "rol": "admin", "restaurante_id": rid})
    return {"Authorization": f"Bearer {token}"}


def _auth_super_admin() -> dict:
    token = crear_token({"sub": "u_super", "correo": "super@test.com", "rol": "super_admin"})
    return {"Authorization": f"Bearer {token}"}


def _auth_cliente() -> dict:
    token = crear_token({"sub": "u_cliente", "correo": "cliente@test.com", "rol": "cliente"})
    return {"Authorization": f"Bearer {token}"}


# ─── Datos de prueba ─────────────────────────────────────────────────────────

def _mesa_r1(numero: int = 5, qr: str = "QR-R1-05") -> dict:
    return {
        "_id": ObjectId(),
        "numero": numero,
        "capacidad": 4,
        "ubicacion": "interior",
        "codigoQr": qr,
        "estado": "libre",
        "restaurante_id": "R1",
    }


def _mesa_r2(numero: int = 5, qr: str = "QR-R2-05") -> dict:
    return {
        "_id": ObjectId(),
        "numero": numero,
        "capacidad": 4,
        "ubicacion": "terraza",
        "codigoQr": qr,
        "estado": "libre",
        "restaurante_id": "R2",
    }


# ─── Test 1: happy path — actualiza los 4 campos ─────────────────────────────

def test_editar_mesa_actualiza_numero_capacidad_ubicacion_qr(client):
    """Admin envía los 4 campos; respuesta 200 con el doc serializado actualizado."""
    mesa = _mesa_r1()
    mesa_id = str(mesa["_id"])
    mesa_actualizada = {
        **mesa,
        "numero": 13,
        "capacidad": 6,
        "ubicacion": "terraza",
        "codigoQr": "M13-69de62-A3F4",
    }

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        # find_one: primera → devuelve la mesa original; segunda → la actualizada
        mock_col.find_one.side_effect = [mesa, None, None, mesa_actualizada]
        mock_col.update_one.return_value = MagicMock()

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"numero": 13, "capacidad": 6, "ubicacion": "terraza", "codigoQr": "M13-69de62-A3F4"},
            headers=_auth_admin(),
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["numero"] == 13
    assert data["capacidad"] == 6
    assert data["ubicacion"] == "terraza"
    assert data["codigoQr"] == "M13-69de62-A3F4"
    assert data["id"] == mesa_id


# ─── Test 2: solo un campo — update_one se llama solo con ese campo ───────────

def test_editar_mesa_solo_capacidad_no_toca_otros_campos(client):
    """Solo se envía capacidad; $set solo contiene ese campo."""
    mesa = _mesa_r1()
    mesa_id = str(mesa["_id"])
    mesa_actualizada = {**mesa, "capacidad": 8}

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.side_effect = [mesa, mesa_actualizada]
        mock_col.update_one.return_value = MagicMock()

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"capacidad": 8},
            headers=_auth_admin(),
        )

    assert resp.status_code == 200, resp.text
    # Verificar que update_one recibió solo capacidad en $set
    set_doc = mock_col.update_one.call_args[0][1]["$set"]
    assert set_doc == {"capacidad": 8}


# ─── Test 3: mesa inexistente → 404 ──────────────────────────────────────────

def test_editar_mesa_inexistente_devuelve_404(client):
    mesa_id = str(ObjectId())

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = None

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"capacidad": 4},
            headers=_auth_admin(),
        )

    assert resp.status_code == 404


# ─── Test 4: numero duplicado en la misma sucursal → 409 ─────────────────────

def test_editar_mesa_numero_duplicado_misma_sucursal_devuelve_409(client):
    """Otra mesa con el mismo número existe en R1 → 409."""
    mesa = _mesa_r1(numero=5)
    mesa_id = str(mesa["_id"])
    otra_mesa = _mesa_r1(numero=13)  # ya existe el 13 en R1

    def find_one_side(filtro, *args, **kwargs):
        # Primera llamada: devuelve la mesa a editar
        # Segunda llamada (unicidad numero): devuelve otra_mesa → colisión
        if filtro.get("_id") == mesa["_id"]:
            return mesa
        if "numero" in filtro:
            return otra_mesa
        return None

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.side_effect = find_one_side

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"numero": 13},
            headers=_auth_admin(),
        )

    assert resp.status_code == 409
    assert "número" in resp.json()["detail"]


# ─── Test 5: QR duplicado → 409 ──────────────────────────────────────────────

def test_editar_mesa_qr_duplicado_devuelve_409(client):
    """Otro documento ya usa ese QR → 409."""
    mesa = _mesa_r1(qr="QR-VIEJO")
    mesa_id = str(mesa["_id"])
    otra_mesa = _mesa_r2(qr="QR-NUEVO")  # en R2 pero el QR es global-único

    def find_one_side(filtro, *args, **kwargs):
        if filtro.get("_id") == mesa["_id"]:
            return mesa
        # Llamada de unicidad QR (contiene $or)
        if "$or" in filtro:
            return otra_mesa
        return None

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.side_effect = find_one_side

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"codigoQr": "QR-NUEVO"},
            headers=_auth_admin(),
        )

    assert resp.status_code == 409
    assert "QR" in resp.json()["detail"] or "uso" in resp.json()["detail"]


# ─── Test 6: ubicacion inválida → 422 ────────────────────────────────────────

def test_editar_mesa_ubicacion_invalida_devuelve_422(client):
    mesa_id = str(ObjectId())

    resp = client.put(
        f"/api/v1/mesas/{mesa_id}",
        json={"ubicacion": "azotea"},
        headers=_auth_admin(),
    )

    assert resp.status_code == 422


# ─── Test 7: sin token → 401 ─────────────────────────────────────────────────

def test_editar_mesa_sin_token_devuelve_401(client):
    mesa_id = str(ObjectId())
    resp = client.put(f"/api/v1/mesas/{mesa_id}", json={"capacidad": 4})
    assert resp.status_code == 401


# ─── Test 8: rol cliente → 403 ───────────────────────────────────────────────

def test_editar_mesa_rol_cliente_devuelve_403(client):
    mesa_id = str(ObjectId())
    resp = client.put(
        f"/api/v1/mesas/{mesa_id}",
        json={"capacidad": 4},
        headers=_auth_cliente(),
    )
    assert resp.status_code == 403


# ─── Test 9: admin de otra sucursal → 403 ────────────────────────────────────

def test_editar_mesa_admin_otra_sucursal_devuelve_403(client):
    """Admin de R1 intenta editar una mesa de R2 → 403."""
    mesa_r2 = _mesa_r2()
    mesa_id = str(mesa_r2["_id"])

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = mesa_r2

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"capacidad": 6},
            headers=_auth_admin(rid="R1"),  # admin de R1, mesa es de R2
        )

    assert resp.status_code == 403


# ─── Test 10: super_admin puede editar cualquier sucursal ────────────────────

def test_editar_mesa_super_admin_puede_editar_cualquier_sucursal(client):
    """super_admin edita una mesa de R2 sin recibir 403."""
    mesa_r2 = _mesa_r2()
    mesa_id = str(mesa_r2["_id"])
    mesa_actualizada = {**mesa_r2, "capacidad": 10}

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.side_effect = [mesa_r2, mesa_actualizada]
        mock_col.update_one.return_value = MagicMock()

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={"capacidad": 10},
            headers=_auth_super_admin(),
        )

    assert resp.status_code == 200, resp.text
    assert resp.json()["capacidad"] == 10


# ─── Test 11: body vacío → 400 ───────────────────────────────────────────────

def test_editar_mesa_body_vacio_devuelve_400(client):
    """Body sin campos útiles → 400 'Sin campos para actualizar'."""
    mesa = _mesa_r1()
    mesa_id = str(mesa["_id"])

    with patch("routes.mesas.coleccion_mesas") as mock_col:
        mock_col.find_one.return_value = mesa

        resp = client.put(
            f"/api/v1/mesas/{mesa_id}",
            json={},
            headers=_auth_admin(),
        )

    assert resp.status_code == 400
    assert "Sin campos" in resp.json()["detail"]
