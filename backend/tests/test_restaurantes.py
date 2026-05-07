"""Tests de endpoints de restaurantes: listado, soft-delete, hard-delete."""
from bson import ObjectId
from security import crear_token


# ── Helpers de tokens ─────────────────────────────────────────────────────────

def _tok_super() -> dict:
    token = crear_token({"sub": "super_id", "correo": "super@bravo.com", "rol": "super_admin"})
    return {"Authorization": f"Bearer {token}"}


def _tok_admin(rid: str = "R1") -> dict:
    token = crear_token({
        "sub": "admin_id",
        "correo": "admin@r1.com",
        "rol": "admin",
        "restaurante_id": rid,
    })
    return {"Authorization": f"Bearer {token}"}


# ── Helpers BD ────────────────────────────────────────────────────────────────

def _insertar_restaurante(nombre: str = "Bravo Test", activo: bool = True) -> str:
    from database import coleccion_restaurantes
    doc: dict = {
        "nombre": nombre,
        "direccion": "Calle Test 1",
        "codigo": "TST01",
        "activo": activo,
    }
    res = coleccion_restaurantes.insert_one(doc)
    return str(res.inserted_id)


def _insertar_restaurante_suspendido(nombre: str = "Bravo Suspendido") -> str:
    from database import coleccion_restaurantes
    from datetime import datetime, timezone
    res = coleccion_restaurantes.insert_one({
        "nombre": nombre,
        "direccion": "Calle Suspendida 2",
        "codigo": "SUS01",
        "activo": False,
        "suspendido_at": datetime.now(timezone.utc).isoformat(),
    })
    return str(res.inserted_id)


# ── Tests de listado con filtro ────────────────────────────────────────────────

def test_listar_restaurantes_incluye_suspendidos_por_defecto(client):
    """Por defecto (incluir_suspendidos=true) aparecen activos y suspendidos."""
    _insertar_restaurante("Activo")
    _insertar_restaurante_suspendido("Suspendido")

    resp = client.get("/api/v1/restaurantes")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2


def test_listar_incluir_suspendidos_false_filtra(client):
    """?incluir_suspendidos=false devuelve solo las sucursales activas."""
    _insertar_restaurante("Activo 1")
    _insertar_restaurante("Activo 2")
    _insertar_restaurante_suspendido("Suspendido")

    resp = client.get("/api/v1/restaurantes?incluir_suspendidos=false")
    assert resp.status_code == 200
    data = resp.json()
    # Solo las dos activas
    assert len(data) == 2
    for r in data:
        assert r.get("activo") is not False


def test_listar_restaurante_serializa_campos_nuevos(client):
    """La respuesta incluye activo y suspendido_at."""
    _insertar_restaurante("Bravo Con Campos")
    resp = client.get("/api/v1/restaurantes")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1
    for r in data:
        assert "activo" in r
        assert "suspendido_at" in r


# ── Tests de suspender ────────────────────────────────────────────────────────

def test_suspender_sucursal_marca_inactiva(client):
    """PATCH /super-admin/restaurantes/{id}/suspender pone activo=false."""
    rid = _insertar_restaurante("Bravo Activo")

    resp = client.patch(
        f"/api/v1/super-admin/restaurantes/{rid}/suspender",
        json={"motivo": "Test de suspensión"},
        headers=_tok_super(),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert "suspendido_at" in data
    assert data["restaurante_id"] == rid

    # Verificar en BD
    from database import coleccion_restaurantes
    doc = coleccion_restaurantes.find_one({"_id": ObjectId(rid)})
    assert doc["activo"] is False
    assert "suspendido_at" in doc


def test_suspender_sucursal_ya_suspendida_409(client):
    """Intentar suspender una sucursal ya suspendida devuelve 409."""
    rid = _insertar_restaurante_suspendido("Ya Suspendida")

    resp = client.patch(
        f"/api/v1/super-admin/restaurantes/{rid}/suspender",
        json={},
        headers=_tok_super(),
    )
    assert resp.status_code == 409, resp.json()


def test_suspender_sucursal_inexistente_404(client):
    """Suspender un ID inexistente devuelve 404."""
    rid_fake = "507f1f77bcf86cd799439011"
    resp = client.patch(
        f"/api/v1/super-admin/restaurantes/{rid_fake}/suspender",
        json={},
        headers=_tok_super(),
    )
    assert resp.status_code == 404


def test_admin_no_puede_suspender_403(client):
    """Un admin no puede suspender sucursales (403)."""
    rid = _insertar_restaurante("Bravo Protegida")

    resp = client.patch(
        f"/api/v1/super-admin/restaurantes/{rid}/suspender",
        json={"motivo": "Intento de admin"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403


def test_suspender_sin_token_401(client):
    rid = _insertar_restaurante("Bravo Sin Auth")
    resp = client.patch(
        f"/api/v1/super-admin/restaurantes/{rid}/suspender",
        json={},
    )
    assert resp.status_code == 401


# ── Tests de reactivar ────────────────────────────────────────────────────────

def test_reactivar_sucursal_revierte(client):
    """POST /super-admin/restaurantes/{id}/reactivar restaura activo=true."""
    rid = _insertar_restaurante_suspendido("Bravo Reactivar")

    resp = client.post(
        f"/api/v1/super-admin/restaurantes/{rid}/reactivar",
        headers=_tok_super(),
    )
    assert resp.status_code == 200, resp.json()
    assert resp.json()["restaurante_id"] == rid

    # Verificar en BD
    from database import coleccion_restaurantes
    doc = coleccion_restaurantes.find_one({"_id": ObjectId(rid)})
    assert doc["activo"] is True
    assert "suspendido_at" not in doc


def test_reactivar_sucursal_activa_409(client):
    """Reactivar una sucursal que ya está activa devuelve 409."""
    rid = _insertar_restaurante("Ya Activa")

    resp = client.post(
        f"/api/v1/super-admin/restaurantes/{rid}/reactivar",
        headers=_tok_super(),
    )
    assert resp.status_code == 409, resp.json()


def test_reactivar_sucursal_inexistente_404(client):
    rid_fake = "507f1f77bcf86cd799439011"
    resp = client.post(
        f"/api/v1/super-admin/restaurantes/{rid_fake}/reactivar",
        headers=_tok_super(),
    )
    assert resp.status_code == 404


def test_admin_no_puede_reactivar_403(client):
    """Un admin no puede reactivar sucursales (403)."""
    rid = _insertar_restaurante_suspendido("Bravo Para Reactivar")

    resp = client.post(
        f"/api/v1/super-admin/restaurantes/{rid}/reactivar",
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403


# ── Tests de hard-delete ──────────────────────────────────────────────────────

def test_hard_delete_solo_super_admin(client):
    """Solo super_admin puede hacer hard-delete de una sucursal."""
    rid = _insertar_restaurante("Bravo Para Borrar")

    resp = client.delete(f"/api/v1/restaurantes/{rid}", headers=_tok_super())
    assert resp.status_code == 200, resp.json()

    from database import coleccion_restaurantes
    assert coleccion_restaurantes.find_one({"_id": ObjectId(rid)}) is None


def test_hard_delete_admin_403(client):
    """Un admin recibe 403 al intentar hard-delete."""
    rid = _insertar_restaurante("Bravo Protegida Hard")
    resp = client.delete(f"/api/v1/restaurantes/{rid}", headers=_tok_admin("R1"))
    assert resp.status_code == 403


def test_hard_delete_sin_token_401(client):
    rid = _insertar_restaurante("Bravo Sin Auth Hard")
    resp = client.delete(f"/api/v1/restaurantes/{rid}")
    assert resp.status_code == 401


def test_hard_delete_inexistente_404(client):
    rid_fake = "507f1f77bcf86cd799439011"
    resp = client.delete(f"/api/v1/restaurantes/{rid_fake}", headers=_tok_super())
    assert resp.status_code == 404


# ── Tests de ciclo completo suspender→reactivar ────────────────────────────────

def test_ciclo_suspender_y_reactivar(client):
    """Suspender y luego reactivar deja el doc con activo=True y sin suspendido_at."""
    rid = _insertar_restaurante("Bravo Ciclo")

    # Suspender
    r1 = client.patch(
        f"/api/v1/super-admin/restaurantes/{rid}/suspender",
        json={"motivo": "Prueba de ciclo completo"},
        headers=_tok_super(),
    )
    assert r1.status_code == 200, r1.json()

    # Reactivar
    r2 = client.post(
        f"/api/v1/super-admin/restaurantes/{rid}/reactivar",
        headers=_tok_super(),
    )
    assert r2.status_code == 200, r2.json()

    from database import coleccion_restaurantes
    doc = coleccion_restaurantes.find_one({"_id": ObjectId(rid)})
    assert doc["activo"] is True
    assert "suspendido_at" not in doc


# ── Tests F8 — PUT /restaurantes/{id} campos extendidos ──────────────────────

def test_actualizar_restaurante_campos_nuevos(client):
    """PUT con cif, horarios_dia y metodos_pago → 200 y datos persistidos en BD."""
    rid = _insertar_restaurante("Bravo Campos Nuevos")

    horarios = {
        "lunes": {"apertura": "09:00", "cierre": "23:00", "abierto": True},
        "martes": {"apertura": "09:00", "cierre": "23:00", "abierto": True},
    }
    body = {
        "cif": "B12345678",
        "razon_social": "Bravo SL",
        "horarios_dia": horarios,
        "metodos_pago": ["efectivo", "tarjeta"],
    }
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_super())
    assert resp.status_code == 200, resp.json()

    # Verificar persistencia en BD
    from database import coleccion_restaurantes
    doc = coleccion_restaurantes.find_one({"_id": ObjectId(rid)})
    assert doc["cif"] == "B12345678"
    assert doc["razon_social"] == "Bravo SL"
    assert doc["metodos_pago"] == ["efectivo", "tarjeta"]
    assert doc["horarios_dia"]["lunes"]["apertura"] == "09:00"
    assert doc["horarios_dia"]["lunes"]["abierto"] is True


def test_actualizar_metodos_pago_invalido_422(client):
    """Lista con método no reconocido ('bitcoin') → 422."""
    rid = _insertar_restaurante("Bravo Metodos")
    body = {"metodos_pago": ["efectivo", "bitcoin"]}
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_super())
    assert resp.status_code == 422, resp.json()
    assert "bitcoin" in resp.json()["detail"]


def test_actualizar_horarios_dia_dia_invalido_422(client):
    """Clave no reconocida en horarios_dia ('lunes_loco') → 422."""
    rid = _insertar_restaurante("Bravo Dias")
    body = {
        "horarios_dia": {
            "lunes_loco": {"apertura": "09:00", "cierre": "22:00"}
        }
    }
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_super())
    assert resp.status_code == 422, resp.json()
    assert "lunes_loco" in resp.json()["detail"]


def test_actualizar_horarios_dia_hora_mal_formada_422(client):
    """Apertura '9am' (sin formato HH:MM) → 422."""
    rid = _insertar_restaurante("Bravo Horas")
    body = {
        "horarios_dia": {
            "lunes": {"apertura": "9am", "cierre": "22:00"}
        }
    }
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_super())
    assert resp.status_code == 422, resp.json()


def test_actualizar_solo_super_admin_403(client):
    """Un admin no puede usar PUT /restaurantes/{id} → 403."""
    rid = _insertar_restaurante("Bravo Solo Super")
    body = {"nombre": "Intentando cambiar"}
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_admin("R1"))
    assert resp.status_code == 403, resp.json()


def test_actualizar_restaurante_inexistente_404(client):
    """PUT sobre un id que no existe → 404."""
    rid_fake = str(ObjectId())
    body = {"nombre": "No existe"}
    resp = client.put(f"/api/v1/restaurantes/{rid_fake}", json=body, headers=_tok_super())
    assert resp.status_code == 404, resp.json()


def test_actualizar_cif_invalido_422(client):
    """CIF de longitud fuera de rango (< 8 chars) → 422."""
    rid = _insertar_restaurante("Bravo CIF")
    body = {"cif": "A1"}  # solo 2 caracteres
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_super())
    assert resp.status_code == 422, resp.json()


def test_actualizar_codigo_postal_no_digitos_422(client):
    """codigo_postal con letras → 422."""
    rid = _insertar_restaurante("Bravo CP")
    body = {"codigo_postal": "2800A"}
    resp = client.put(f"/api/v1/restaurantes/{rid}", json=body, headers=_tok_super())
    assert resp.status_code == 422, resp.json()
