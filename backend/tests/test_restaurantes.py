"""Tests de endpoints de restaurantes: listado, soft-delete, hard-delete."""
from bson import ObjectId
from tests.tok_helpers import tok


# ── Helpers de tokens ─────────────────────────────────────────────────────────

def _tok_super() -> dict:
    return tok("super_admin")


def _tok_admin(rid: str = "R1") -> dict:
    return tok("admin", restaurante_id=rid)


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

    resp = client.get("/api/v1/restaurantes", headers=_tok_super())
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2


def test_listar_incluir_suspendidos_false_filtra(client):
    """?incluir_suspendidos=false devuelve solo las sucursales activas."""
    _insertar_restaurante("Activo 1")
    _insertar_restaurante("Activo 2")
    _insertar_restaurante_suspendido("Suspendido")

    resp = client.get(
        "/api/v1/restaurantes?incluir_suspendidos=false",
        headers=_tok_super(),
    )
    assert resp.status_code == 200
    data = resp.json()
    # Solo las dos activas
    assert len(data) == 2
    for r in data:
        assert r.get("activo") is not False


def test_listar_restaurante_serializa_campos_nuevos(client):
    """La respuesta incluye activo y suspendido_at."""
    _insertar_restaurante("Bravo Con Campos")
    resp = client.get("/api/v1/restaurantes", headers=_tok_super())
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1
    for r in data:
        assert "activo" in r
        assert "suspendido_at" in r


# ── Tests Fix bonus — GET /restaurantes y GET /restaurantes/{id} exigen auth ──

def test_listar_restaurantes_sin_token_401(client):
    """Fix bonus: GET /restaurantes ahora exige autenticación."""
    resp = client.get("/api/v1/restaurantes")
    assert resp.status_code == 401


def test_obtener_restaurante_sin_token_401(client):
    """Fix bonus: GET /restaurantes/{id} ahora exige autenticación."""
    rid = _insertar_restaurante("Bravo Auth Guard")
    resp = client.get(f"/api/v1/restaurantes/{rid}")
    assert resp.status_code == 401


def test_listar_restaurantes_cualquier_rol_200(client):
    """Cualquier rol autenticado (admin, camarero, cliente) puede listar sucursales."""
    _insertar_restaurante("Bravo Visible")
    for rol in ("admin", "camarero", "cliente"):
        resp = client.get("/api/v1/restaurantes", headers=_tok_rol(rol))
        assert resp.status_code == 200, f"Fallo para rol={rol}: {resp.json()}"


def test_obtener_restaurante_cualquier_rol_200(client):
    """Cualquier rol autenticado puede obtener el detalle de una sucursal."""
    rid = _insertar_restaurante("Bravo Detalle")
    for rol in ("admin", "camarero", "cliente"):
        resp = client.get(f"/api/v1/restaurantes/{rid}", headers=_tok_rol(rol))
        assert resp.status_code == 200, f"Fallo para rol={rol}: {resp.json()}"


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


def test_actualizar_admin_otra_sucursal_403(client):
    """Admin con restaurante_id distinto al del recurso → 403."""
    rid = _insertar_restaurante("Bravo Solo Super")
    body = {"nombre": "Intentando cambiar"}
    # _tok_admin("R1") tiene restaurante_id="R1", que no coincide con rid (ObjectId real)
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


# ── Tests F8-bis — admin puede editar su propia sucursal ─────────────────────

def _tok_admin_rid(rid: str) -> dict:
    """Token de admin cuyo restaurante_id coincide exactamente con rid."""
    return tok("admin", restaurante_id=rid)


def _tok_rol(rol: str) -> dict:
    """Token genérico para un rol dado, sin restaurante_id."""
    return tok(rol)


def test_admin_puede_editar_su_propia_sucursal_200(client):
    """Admin con restaurante_id == id del recurso → 200."""
    rid = _insertar_restaurante("Bravo Admin Own")
    body = {"nombre": "Nombre Actualizado por Admin"}
    resp = client.put(
        f"/api/v1/restaurantes/{rid}",
        json=body,
        headers=_tok_admin_rid(rid),
    )
    assert resp.status_code == 200, resp.json()

    from database import coleccion_restaurantes
    doc = coleccion_restaurantes.find_one({"_id": ObjectId(rid)})
    assert doc["nombre"] == "Nombre Actualizado por Admin"


def test_admin_no_puede_editar_otra_sucursal_403(client):
    """Admin cuyo restaurante_id no coincide con el id de la URL → 403."""
    rid = _insertar_restaurante("Bravo Ajena")
    rid_otro = str(ObjectId())  # id diferente al del token
    body = {"nombre": "Hackeo"}
    resp = client.put(
        f"/api/v1/restaurantes/{rid}",
        json=body,
        headers=_tok_admin_rid(rid_otro),
    )
    assert resp.status_code == 403, resp.json()


def test_camarero_no_puede_editar_restaurante_403(client):
    """Camarero → 403 en PUT /restaurantes/{id}."""
    rid = _insertar_restaurante("Bravo Camarero Guard")
    body = {"nombre": "Intruso"}
    resp = client.put(
        f"/api/v1/restaurantes/{rid}",
        json=body,
        headers=_tok_rol("camarero"),
    )
    assert resp.status_code == 403, resp.json()


def test_cocinero_no_puede_editar_restaurante_403(client):
    """Cocinero → 403 en PUT /restaurantes/{id}."""
    rid = _insertar_restaurante("Bravo Cocinero Guard")
    body = {"nombre": "Intruso"}
    resp = client.put(
        f"/api/v1/restaurantes/{rid}",
        json=body,
        headers=_tok_rol("cocinero"),
    )
    assert resp.status_code == 403, resp.json()


def test_cliente_no_puede_editar_restaurante_403(client):
    """Cliente → 403 en PUT /restaurantes/{id}."""
    rid = _insertar_restaurante("Bravo Cliente Guard")
    body = {"nombre": "Intruso"}
    resp = client.put(
        f"/api/v1/restaurantes/{rid}",
        json=body,
        headers=_tok_rol("cliente"),
    )
    assert resp.status_code == 403, resp.json()


def test_put_restaurante_sin_token_401(client):
    """Sin token → 401 en PUT /restaurantes/{id}."""
    rid = _insertar_restaurante("Bravo Sin Token")
    resp = client.put(f"/api/v1/restaurantes/{rid}", json={"nombre": "X"})
    assert resp.status_code == 401, resp.json()


# ── Tests de PATCH /{id}/activo (toggle activo) ───────────────────────────────

def test_toggle_activo_super_admin_200(client):
    """super_admin puede cambiar el flag activo."""
    rid = _insertar_restaurante("Bravo Toggle")
    resp = client.patch(
        f"/api/v1/restaurantes/{rid}/activo",
        json={"activo": False},
        headers=_tok_super(),
    )
    assert resp.status_code == 200, resp.json()


def test_toggle_activo_admin_403(client):
    """admin (incluso de la misma sucursal) NO puede tocar el flag activo."""
    rid = _insertar_restaurante("Bravo Toggle Admin")
    resp = client.patch(
        f"/api/v1/restaurantes/{rid}/activo",
        json={"activo": False},
        headers=_tok_admin(rid),
    )
    assert resp.status_code == 403, resp.json()


def test_toggle_activo_otros_roles_403(client):
    """camarero/cocinero/cliente → 403."""
    rid = _insertar_restaurante("Bravo Toggle Otros")
    for rol in ("camarero", "cocinero", "cliente"):
        resp = client.patch(
            f"/api/v1/restaurantes/{rid}/activo",
            json={"activo": False},
            headers=_tok_rol(rol),
        )
        assert resp.status_code == 403, (rol, resp.json())


def test_toggle_activo_sin_token_401(client):
    """Sin token → 401."""
    rid = _insertar_restaurante("Bravo Toggle Sin Token")
    resp = client.patch(
        f"/api/v1/restaurantes/{rid}/activo",
        json={"activo": False},
    )
    assert resp.status_code == 401, resp.json()
