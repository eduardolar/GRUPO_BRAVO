"""Tests de aislamiento por sucursal para /api/v1/cupones.

Cubre:
  - Admin crea cupón → se persiste con su restaurante_id del JWT.
  - Admin lista → ve los suyos + cupones globales, no los de otras sucursales.
  - Admin edita cupón ajeno → 403.
  - Admin edita cupón global → 403 (solo super_admin).
  - super_admin puede editar/eliminar cualquier cupón.
  - Endpoint /usar no está restringido por sucursal.
"""
from bson import ObjectId
from tests.tok_helpers import tok


# ─── Helpers de tokens ────────────────────────────────────────────────────────

def _tok_admin(rid: str = "R1") -> dict:
    return tok("admin", restaurante_id=rid)


def _tok_super() -> dict:
    return tok("super_admin")


def _tok_cliente() -> dict:
    return tok("cliente")


# ─── Helpers BD ───────────────────────────────────────────────────────────────

def _insertar_cupon(codigo: str, rid: str | None = None, activo: bool = True) -> str:
    from database import coleccion_cupones
    res = coleccion_cupones.insert_one({
        "codigo": codigo,
        "tipo": "porcentaje",
        "valor": 10.0,
        "descripcion": "Test",
        "activo": activo,
        "usos_maximos": None,
        "usos_actuales": 0,
        "restaurante_id": rid,
    })
    return str(res.inserted_id)


_CUPON_BODY = {
    "codigo": "PROMO10",
    "tipo": "porcentaje",
    "valor": 10.0,
    "descripcion": "10% off",
}


# ─── Tests de creación ────────────────────────────────────────────────────────

def test_admin_crea_cupon_con_su_restaurante_id(client):
    """Admin crea cupón → se persiste con restaurante_id del JWT, no del body."""
    body = {**_CUPON_BODY, "restaurante_id": "R_OTRO"}  # body con rid diferente
    resp = client.post("/api/v1/cupones", json=body, headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    # Debe tener el restaurante_id del JWT (R1), no el del body (R_OTRO)
    assert data["restaurante_id"] == "R1"


def test_super_admin_crea_cupon_global(client):
    """super_admin crea cupón sin restaurante_id → cupón global."""
    body = {**_CUPON_BODY, "codigo": "GLOBAL1"}
    resp = client.post("/api/v1/cupones", json=body, headers=_tok_super())
    assert resp.status_code == 200, resp.json()
    assert resp.json()["restaurante_id"] is None


def test_super_admin_crea_cupon_de_sucursal(client):
    """super_admin puede crear cupón asignado a una sucursal concreta."""
    body = {**_CUPON_BODY, "codigo": "R2PROMO", "restaurante_id": "R2"}
    resp = client.post("/api/v1/cupones", json=body, headers=_tok_super())
    assert resp.status_code == 200, resp.json()
    assert resp.json()["restaurante_id"] == "R2"


def test_sin_token_crear_cupon_401(client):
    resp = client.post("/api/v1/cupones", json=_CUPON_BODY)
    assert resp.status_code == 401


# ─── Tests de listado ─────────────────────────────────────────────────────────

def test_admin_lista_sus_cupones_y_globales(client):
    """Admin de R1 ve: sus cupones (R1) + globales (None). No ve los de R2."""
    _insertar_cupon("R1CODE", "R1")
    _insertar_cupon("R2CODE", "R2")
    _insertar_cupon("GLOBAL", None)

    resp = client.get("/api/v1/cupones", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    codigos = {c["codigo"] for c in resp.json()}

    assert "R1CODE" in codigos, "Debe ver sus propios cupones"
    assert "GLOBAL" in codigos, "Debe ver cupones globales"
    assert "R2CODE" not in codigos, "No debe ver cupones de otra sucursal"


def test_super_admin_lista_todos_los_cupones(client):
    """super_admin ve todos los cupones sin restricción."""
    _insertar_cupon("R1ONLY", "R1")
    _insertar_cupon("R2ONLY", "R2")
    _insertar_cupon("GLOBALX", None)

    resp = client.get("/api/v1/cupones", headers=_tok_super())
    assert resp.status_code == 200
    codigos = {c["codigo"] for c in resp.json()}
    assert {"R1ONLY", "R2ONLY", "GLOBALX"}.issubset(codigos)


# ─── Tests de edición ─────────────────────────────────────────────────────────

def test_admin_edita_su_propio_cupon(client):
    """Admin puede editar un cupón de su sucursal."""
    cid = _insertar_cupon("EDITABLE", "R1")
    resp = client.put(
        f"/api/v1/cupones/{cid}",
        json={"descripcion": "Actualizado"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    assert resp.json()["descripcion"] == "Actualizado"


def test_admin_no_puede_editar_cupon_de_otra_sucursal(client):
    """Admin de R1 no puede editar un cupón de R2 → 403."""
    cid = _insertar_cupon("R2EDIT", "R2")
    resp = client.put(
        f"/api/v1/cupones/{cid}",
        json={"descripcion": "Hack"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403, resp.json()


def test_admin_no_puede_editar_cupon_global(client):
    """Admin no puede editar cupones globales (sin restaurante_id) → 403."""
    cid = _insertar_cupon("GLOBALP", None)
    resp = client.put(
        f"/api/v1/cupones/{cid}",
        json={"descripcion": "Intentando editar global"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403, resp.json()


def test_super_admin_edita_cualquier_cupon(client):
    """super_admin puede editar cupones de cualquier sucursal."""
    cid = _insertar_cupon("SUPEREDITABLE", "R2")
    resp = client.put(
        f"/api/v1/cupones/{cid}",
        json={"descripcion": "Editado por super"},
        headers=_tok_super(),
    )
    assert resp.status_code == 200, resp.json()


# ─── Tests de eliminación ─────────────────────────────────────────────────────

def test_admin_elimina_su_propio_cupon(client):
    cid = _insertar_cupon("TODELETE", "R1")
    resp = client.delete(f"/api/v1/cupones/{cid}", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()


def test_admin_no_puede_eliminar_cupon_ajeno(client):
    cid = _insertar_cupon("NOTMINE", "R2")
    resp = client.delete(f"/api/v1/cupones/{cid}", headers=_tok_admin("R1"))
    assert resp.status_code == 403, resp.json()


# ─── Tests de /usar (sin restricción de sucursal) ────────────────────────────

def test_cliente_puede_usar_cupon_de_cualquier_sucursal(client):
    """El endpoint /usar no restringe por sucursal."""
    cid = _insertar_cupon("USABLE", "R2")
    resp = client.post(f"/api/v1/cupones/{cid}/usar", headers=_tok_cliente())
    assert resp.status_code == 200, resp.json()
    assert resp.json()["usos_actuales"] == 1


def test_usar_cupon_inactivo_400(client):
    cid = _insertar_cupon("INACTIVO", "R1", activo=False)
    resp = client.post(f"/api/v1/cupones/{cid}/usar", headers=_tok_cliente())
    assert resp.status_code == 400
