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
from tests.tok_helpers import tok, insertar_usuario_test, TEST_OID_CLIENTE, TEST_OID_CAMARERO
from security import crear_token


# OIDs fijos para clientes de prueba en reservas
_OID_CLIENTE_1 = TEST_OID_CLIENTE
_OID_CLIENTE_2 = ObjectId("111111111111111111111111")
_OID_CLIENTE_PROPIO = ObjectId("222222222222222222222222")


# ─── Helpers de tokens ────────────────────────────────────────────────────────

def _tok_cliente(oid: ObjectId = _OID_CLIENTE_1) -> dict:
    """Token de cliente. Acepta ObjectId o string-OID como identificador."""
    if isinstance(oid, str):
        # Compatibilidad: si se pasa un string que no sea OID, usar el OID_CLIENTE_1
        try:
            oid = ObjectId(oid)
        except Exception:
            oid = _OID_CLIENTE_1
    insertar_usuario_test(oid, "cliente")
    token = crear_token({"sub": str(oid), "correo": "cliente@test.com", "rol": "cliente"})
    return {"Authorization": f"Bearer {token}"}


def _tok_admin(rid: str = "R1") -> dict:
    return tok("admin", restaurante_id=rid)


def _tok_super() -> dict:
    return tok("super_admin")


def _tok_camarero(rid: str = "R1") -> dict:
    return tok("camarero", restaurante_id=rid)


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
    _insertar_reserva(str(_OID_CLIENTE_1), "R1")
    _insertar_reserva(str(_OID_CLIENTE_2), "R1")

    # Pasa usuarioId ajeno en la query; debe ignorarse y devolver solo las suyas
    resp = client.get(
        f"/api/v1/reservas?usuarioId={_OID_CLIENTE_2}",
        headers=_tok_cliente(_OID_CLIENTE_1),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    # Solo ve las reservas del _OID_CLIENTE_1 (sub del JWT)
    for r in data:
        assert r["usuarioId"] == str(_OID_CLIENTE_1), f"Vio reserva ajena: {r['usuarioId']}"


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


# ─── Tests horarios_dia — validación al crear reserva ────────────────────────

def _insertar_restaurante_con_horarios(horarios_dia: dict) -> str:
    """Inserta un restaurante en BD con horarios_dia y devuelve su id como str."""
    from database import coleccion_restaurantes
    res = coleccion_restaurantes.insert_one({
        "nombre": "Bravo Horarios",
        "direccion": "Calle Test 1",
        "codigo": "HOR01",
        "activo": True,
        "horarios_dia": horarios_dia,
    })
    return str(res.inserted_id)


def _insertar_mesa_para_restaurante(rid: str, numero: int = 1, capacidad: int = 4) -> str:
    from database import coleccion_mesas
    res = coleccion_mesas.insert_one({
        "numero": numero,
        "capacidad": capacidad,
        "restaurante_id": rid,
    })
    return str(res.inserted_id)


def _payload_reserva(restaurante_id: str, fecha: str = "2026-12-01", hora: str = "13:00") -> dict:
    """Payload mínimo para POST /reservas.
    2026-12-01 es martes (weekday=1, clave 'martes').
    """
    return {
        "usuarioId": "u_test",
        "nombreCompleto": "Test User",
        "fecha": fecha,
        "hora": hora,
        "comensales": 2,
        "turno": "comida",
        "restauranteId": restaurante_id,
    }


def test_reserva_dia_abierto_acepta_hora_en_rango(client):
    """POST /reservas con restaurante que tiene 'martes' abierto y hora en rango → 200/201."""
    horarios = {
        "martes": {"apertura": "09:00", "cierre": "23:00", "abierto": True},
    }
    rid = _insertar_restaurante_con_horarios(horarios)
    _insertar_mesa_para_restaurante(rid)

    resp = client.post(
        "/api/v1/reservas",
        json=_payload_reserva(rid, fecha="2026-12-01", hora="13:00"),
        headers=_tok_cliente(_OID_CLIENTE_1),
    )
    assert resp.status_code in (200, 201), resp.json()
    data = resp.json()
    assert data["fecha"] == "2026-12-01"


def test_reserva_dia_cerrado_devuelve_400(client):
    """POST /reservas con restaurante que tiene 'martes' cerrado (abierto=false) → 400."""
    horarios = {
        "martes": {"apertura": "09:00", "cierre": "23:00", "abierto": False},
    }
    rid = _insertar_restaurante_con_horarios(horarios)
    _insertar_mesa_para_restaurante(rid)

    resp = client.post(
        "/api/v1/reservas",
        json=_payload_reserva(rid, fecha="2026-12-01", hora="13:00"),
        headers=_tok_cliente(_OID_CLIENTE_1),
    )
    assert resp.status_code == 400, resp.json()
    assert "cerrado" in resp.json()["detail"].lower()


# ═══════════════════════════════════════════════════════════════════════════
# Pendiente 3 — Reservas con datos del cliente real (camarero/admin como actor)
# ═══════════════════════════════════════════════════════════════════════════

def test_camarero_crea_reserva_con_datos_cliente_real(client):
    """Camarero crea reserva con nombreCompleto, telefonoCliente, correoCliente.
    El documento persistido debe tener esos datos y creado_por_actor.sub == sub_camarero."""
    rid = "R1"
    mesa_id = _insertar_mesa(rid, numero=10)

    payload = {
        "usuarioId": "u_cliente_real",
        "nombreCompleto": "Juan Perez",
        "fecha": "2026-12-15",
        "hora": "14:00",
        "comensales": 2,
        "turno": "comida",
        "restauranteId": rid,
        "mesaId": mesa_id,
        "telefonoCliente": "600123456",
        "correoCliente": "juan@example.com",
    }

    resp = client.post(
        "/api/v1/reservas",
        json=payload,
        headers=_tok_camarero(rid),
    )
    assert resp.status_code in (200, 201), resp.json()

    # Verificar que el documento en BD tiene los datos del cliente real y la auditoría del actor
    from database import coleccion_reservas
    from bson import ObjectId as BsonOid
    reserva_id = resp.json()["id"]
    doc = coleccion_reservas.find_one({"_id": BsonOid(reserva_id)})
    assert doc is not None
    assert doc.get("telefono_cliente") == "600123456", (
        f"telefono_cliente esperado '600123456', obtenido '{doc.get('telefono_cliente')}'"
    )
    assert doc.get("correo_cliente") == "juan@example.com"
    assert doc.get("creado_por_actor") is not None, "creado_por_actor debe estar presente"
    assert doc["creado_por_actor"]["sub"] == str(TEST_OID_CAMARERO), (
        f"sub esperado '{TEST_OID_CAMARERO}', obtenido '{doc['creado_por_actor'].get('sub')}'"
    )
    assert doc["creado_por_actor"]["rol"] == "camarero"


def test_cliente_crea_reserva_ignora_telefono_correo_cliente(client):
    """Un cliente no puede inyectar telefonoCliente/correoCliente — esos campos
    no deben persistirse cuando el actor es cliente."""
    rid = "R1"
    mesa_id = _insertar_mesa(rid, numero=11)

    payload = {
        "usuarioId": "u_propio",
        "nombreCompleto": "Ana Lopez",
        "fecha": "2026-12-16",
        "hora": "14:00",
        "comensales": 1,
        "turno": "comida",
        "restauranteId": rid,
        "mesaId": mesa_id,
        "telefonoCliente": "700000000",   # debe ser ignorado
        "correoCliente": "hacker@evil.com",  # debe ser ignorado
    }

    resp = client.post(
        "/api/v1/reservas",
        json=payload,
        headers=_tok_cliente(_OID_CLIENTE_PROPIO),
    )
    assert resp.status_code in (200, 201), resp.json()

    from database import coleccion_reservas
    from bson import ObjectId as BsonOid
    reserva_id = resp.json()["id"]
    doc = coleccion_reservas.find_one({"_id": BsonOid(reserva_id)})
    assert doc is not None
    # Para clientes, estos campos no deben haberse persistido
    assert doc.get("telefono_cliente") is None, "telefono_cliente no debe persistirse para clientes"
    assert doc.get("correo_cliente") is None, "correo_cliente no debe persistirse para clientes"
    assert doc.get("creado_por_actor") is None, "creado_por_actor no debe existir cuando el actor es cliente"
