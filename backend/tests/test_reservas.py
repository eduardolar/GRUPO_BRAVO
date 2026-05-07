"""Tests de autenticación y aislamiento por sucursal para /api/v1/reservas.

Cubre:
  - Sin token → 401 en endpoints protegidos.
  - Cliente solo ve sus propias reservas aunque pase otro usuarioId.
  - Admin lista /reservas/admin → solo de su sucursal.
  - Admin cambia estado de reserva → 200.
  - Admin cambia estado de reserva ajena → 403.
  - Admin asigna mesa de su sucursal → 200.
  - Admin asigna mesa de otra sucursal → 400/403.
"""
from unittest.mock import MagicMock, patch
from bson import ObjectId
from security import crear_token


# ─── Helpers de tokens ────────────────────────────────────────────────────────

def _tok_cliente(sub: str = "cliente_id_1") -> dict:
    token = crear_token({"sub": sub, "correo": "cliente@test.com", "rol": "cliente"})
    return {"Authorization": f"Bearer {token}"}


def _tok_admin(rid: str = "R1") -> dict:
    token = crear_token({
        "sub": "admin_id",
        "correo": "admin@r1.com",
        "rol": "admin",
        "restaurante_id": rid,
    })
    return {"Authorization": f"Bearer {token}"}


def _tok_super() -> dict:
    token = crear_token({"sub": "super_id", "correo": "super@bravo.com", "rol": "super_admin"})
    return {"Authorization": f"Bearer {token}"}


def _tok_camarero(rid: str = "R1") -> dict:
    token = crear_token({
        "sub": "camarero_id",
        "correo": "camarero@r1.com",
        "rol": "camarero",
        "restaurante_id": rid,
    })
    return {"Authorization": f"Bearer {token}"}


# ─── Helpers BD de test ───────────────────────────────────────────────────────

def _insertar_reserva(usuario_id: str, rid: str = "R1", estado: str = "Confirmada") -> str:
    from database import coleccion_reservas
    res = coleccion_reservas.insert_one({
        "usuario_id": usuario_id,
        "nombre_completo": "Test User",
        "fecha": "2026-12-01",
        "hora": "13:00",
        "comensales": 2,
        "turno": "comida",
        "estado": estado,
        "mesa_id": None,
        "numero_mesa": None,
        "restaurante_id": rid,
    })
    return str(res.inserted_id)


def _insertar_mesa(rid: str = "R1", numero: int = 5) -> str:
    from database import coleccion_mesas
    res = coleccion_mesas.insert_one({
        "numero": numero,
        "capacidad": 4,
        "restaurante_id": rid,
    })
    return str(res.inserted_id)


# ─── Tests de autenticación ────────────────────────────────────────────────────

def test_get_reservas_sin_token_401(client):
    resp = client.get("/api/v1/reservas?usuarioId=x")
    assert resp.status_code == 401


def test_get_reservas_admin_sin_token_401(client):
    resp = client.get("/api/v1/reservas/admin")
    assert resp.status_code == 401


def test_post_reserva_sin_token_401(client):
    resp = client.post("/api/v1/reservas", json={})
    assert resp.status_code == 401


# ─── Tests de cliente (aislamiento) ──────────────────────────────────────────

def test_cliente_solo_ve_sus_reservas(client):
    """Cliente que pasa usuarioId=otro_usuario solo recibe sus propias reservas."""
    _insertar_reserva("cliente_id_1", "R1")
    _insertar_reserva("cliente_id_2", "R1")

    # Pasa usuarioId ajeno en la query; debe ignorarse y devolver solo las suyas
    resp = client.get(
        "/api/v1/reservas?usuarioId=cliente_id_2",
        headers=_tok_cliente("cliente_id_1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    # Solo ve las reservas del cliente_id_1 (sub del JWT)
    for r in data:
        assert r["usuarioId"] == "cliente_id_1", f"Vio reserva ajena: {r['usuarioId']}"


# ─── Tests de panel admin ─────────────────────────────────────────────────────

def test_admin_lista_reservas_solo_su_sucursal(client):
    """Admin de R1 solo ve reservas de R1, no de R2."""
    _insertar_reserva("u1", "R1")
    _insertar_reserva("u2", "R2")

    resp = client.get("/api/v1/reservas/admin", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    for r in data:
        assert r.get("restauranteId") == "R1", f"Vio reserva de otra sucursal: {r}"


def test_admin_lista_reservas_con_filtro_fecha(client):
    """El filtro ?fecha= funciona y devuelve solo las de esa fecha."""
    _insertar_reserva("u1", "R1")  # fecha 2026-12-01
    from database import coleccion_reservas
    coleccion_reservas.insert_one({
        "usuario_id": "u1",
        "nombre_completo": "T",
        "fecha": "2026-11-15",
        "hora": "14:00",
        "comensales": 2,
        "turno": "comida",
        "estado": "Confirmada",
        "restaurante_id": "R1",
    })

    resp = client.get("/api/v1/reservas/admin?fecha=2026-12-01", headers=_tok_admin("R1"))
    assert resp.status_code == 200
    data = resp.json()
    for r in data:
        assert r["fecha"] == "2026-12-01"


def test_admin_lista_reservas_con_filtro_estado(client):
    """El filtro ?estado=Cancelada funciona."""
    _insertar_reserva("u1", "R1", "Confirmada")
    _insertar_reserva("u2", "R1", "Cancelada")

    resp = client.get("/api/v1/reservas/admin?estado=Cancelada", headers=_tok_admin("R1"))
    assert resp.status_code == 200
    data = resp.json()
    for r in data:
        assert r["estado"] == "Cancelada"


def test_admin_lista_reservas_estado_invalido_400(client):
    resp = client.get("/api/v1/reservas/admin?estado=Fantasma", headers=_tok_admin("R1"))
    assert resp.status_code == 400


# ─── Tests de cambio de estado ────────────────────────────────────────────────

def test_admin_cambia_estado_reserva_propia_sucursal(client):
    rid = _insertar_reserva("u1", "R1")
    resp = client.patch(
        f"/api/v1/reservas/{rid}/estado",
        json={"estado": "Cancelada"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    assert resp.json()["estado"] == "Cancelada"


def test_admin_no_puede_cambiar_estado_reserva_otra_sucursal(client):
    rid = _insertar_reserva("u1", "R2")
    resp = client.patch(
        f"/api/v1/reservas/{rid}/estado",
        json={"estado": "Cancelada"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403, resp.json()


def test_cambiar_estado_invalido_400(client):
    rid = _insertar_reserva("u1", "R1")
    resp = client.patch(
        f"/api/v1/reservas/{rid}/estado",
        json={"estado": "Fantasma"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 400


def test_cambiar_estado_sin_token_401(client):
    resp = client.patch(
        "/api/v1/reservas/123456789012345678901234/estado",
        json={"estado": "Cancelada"},
    )
    assert resp.status_code == 401


# ─── Tests de asignar mesa ────────────────────────────────────────────────────

def test_admin_asigna_mesa_su_sucursal(client):
    """Admin de R1 puede asignar una mesa de R1 a una reserva de R1."""
    rid = _insertar_reserva("u1", "R1")
    mid = _insertar_mesa("R1", 7)

    resp = client.patch(
        f"/api/v1/reservas/{rid}/asignar-mesa",
        json={"mesaId": mid},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["mesaId"] == mid
    assert data["numeroMesa"] == 7

    from database import coleccion_reservas
    doc = coleccion_reservas.find_one({"_id": ObjectId(rid)})
    assert doc["mesa_id"] == mid
    assert doc["numero_mesa"] == 7


def test_admin_no_puede_asignar_mesa_otra_sucursal(client):
    """Admin de R1 no puede asignar una mesa de R2 a una reserva de R1."""
    rid = _insertar_reserva("u1", "R1")
    mid_r2 = _insertar_mesa("R2", 10)

    resp = client.patch(
        f"/api/v1/reservas/{rid}/asignar-mesa",
        json={"mesaId": mid_r2},
        headers=_tok_admin("R1"),
    )
    # La mesa es de R2 pero la reserva es de R1 → error de sucursal
    assert resp.status_code in (400, 403), resp.json()


def test_admin_no_puede_gestionar_reserva_otra_sucursal(client):
    """Admin de R1 no puede asignar mesa a reserva de R2."""
    rid = _insertar_reserva("u1", "R2")
    mid = _insertar_mesa("R1", 3)

    resp = client.patch(
        f"/api/v1/reservas/{rid}/asignar-mesa",
        json={"mesaId": mid},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403, resp.json()


def test_asignar_mesa_inexistente_404(client):
    rid = _insertar_reserva("u1", "R1")
    resp = client.patch(
        f"/api/v1/reservas/{rid}/asignar-mesa",
        json={"mesaId": "507f1f77bcf86cd799439011"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 404


def test_asignar_mesa_sin_token_401(client):
    resp = client.patch(
        "/api/v1/reservas/123456789012345678901234/asignar-mesa",
        json={"mesaId": "507f1f77bcf86cd799439011"},
    )
    assert resp.status_code == 401


# ─── Tests super_admin ────────────────────────────────────────────────────────

def test_super_admin_puede_cambiar_estado_cualquier_sucursal(client):
    """super_admin no está limitado por sucursal."""
    rid = _insertar_reserva("u1", "R99")
    resp = client.patch(
        f"/api/v1/reservas/{rid}/estado",
        json={"estado": "NoShow"},
        headers=_tok_super(),
    )
    assert resp.status_code == 200, resp.json()


def test_super_admin_ve_todas_las_reservas_sin_restaurante_id(client):
    """super_admin sin ?restaurante_id ve reservas de todas las sucursales."""
    _insertar_reserva("u1", "R1")
    _insertar_reserva("u2", "R2")
    _insertar_reserva("u3", "R3")

    resp = client.get("/api/v1/reservas/admin", headers=_tok_super())
    assert resp.status_code == 200, resp.json()
    data = resp.json()

    sucursales_vistas = {r.get("restauranteId") for r in data}
    assert "R1" in sucursales_vistas
    assert "R2" in sucursales_vistas
    assert "R3" in sucursales_vistas


def test_super_admin_filtra_por_restaurante_id(client):
    """super_admin con ?restaurante_id= solo ve reservas de esa sucursal."""
    _insertar_reserva("u1", "R1")
    _insertar_reserva("u2", "R2")

    resp = client.get(
        "/api/v1/reservas/admin?restaurante_id=R1",
        headers=_tok_super(),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()

    assert len(data) >= 1, "Debe haber al menos una reserva de R1"
    for r in data:
        assert r.get("restauranteId") == "R1", (
            f"super_admin filtró por R1 pero recibió reserva de {r.get('restauranteId')}"
        )


def test_admin_no_ve_reservas_de_otra_sucursal_con_restaurante_id(client):
    """Admin no puede usar ?restaurante_id para ver otra sucursal: siempre usa el del JWT."""
    _insertar_reserva("u1", "R1")
    _insertar_reserva("u2", "R2")

    # Admin de R1 pasa restaurante_id=R2 en la query; debe seguir viendo solo R1
    resp = client.get(
        "/api/v1/reservas/admin?restaurante_id=R2",
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    for r in resp.json():
        assert r.get("restauranteId") == "R1", (
            f"Admin de R1 vio reserva de otra sucursal: {r.get('restauranteId')}"
        )
