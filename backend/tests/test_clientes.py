"""Tests del router /api/v1/clientes.

Cubre:
  Endpoints públicos:
    - POST /clientes/registro          — auto-registro forzando rol=cliente
    - POST /clientes/verificar-email   — verifica código de activación
    - POST /clientes/reenviar-codigo   — reenvía código de verificación
    - POST /clientes/recuperar-password — solicita código de recuperación
    - POST /clientes/restablecer-password — resetea contraseña con código
  Endpoints autenticados (/me):
    - GET  /clientes/me                — perfil propio
    - PUT  /clientes/me                — editar perfil (campos seguros)
    - PUT  /clientes/me/password       — cambiar contraseña
    - GET  /clientes/me/datos          — exportar RGPD con pedidos
    - DELETE /clientes/me              — baja RGPD anonimización
  Seguridad:
    - No-cliente no puede usar endpoints /me
    - Sin token → 401
"""
import bcrypt
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch

import pytest
from bson import ObjectId
from security import crear_token
from tests.tok_helpers import tok


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    """Resetea el storage del rate limiter antes de cada test para evitar
    que el límite acumulado de tests previos bloquee tests posteriores."""
    from limiter import limiter
    limiter.reset()
    yield


# ── Helpers de tokens ─────────────────────────────────────────────────────────

def _tok_cliente(user_id: str | None = None) -> dict:
    """Token de cliente.

    Si `user_id` es un ObjectId string válido (devuelto por _insertar_cliente),
    se usa directamente como sub. El usuario ya existe en BD con activo=True.
    Si no se indica, usa el OID fijo del conftest.
    """
    if user_id is not None:
        # user_id es un ObjectId string real insertado por _insertar_cliente.
        # El usuario ya existe en BD así que no necesitamos insertar de nuevo.
        token = crear_token({
            "sub": user_id,
            "correo": "cliente@test.com",
            "rol": "cliente",
        })
        return {"Authorization": f"Bearer {token}"}
    return tok("cliente")


def _tok_admin() -> dict:
    return tok("admin", restaurante_id="R1")


def _tok_camarero() -> dict:
    return tok("camarero", restaurante_id="R1")


# ── Helpers de fixtures ───────────────────────────────────────────────────────

def _insertar_cliente(correo: str, verificado: bool = True, activo: bool = True,
                      password: str = "Segura1!") -> str:
    from database import coleccion_usuarios
    hash_pw = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    resultado = coleccion_usuarios.insert_one({
        "nombre": "Cliente Test",
        "correo": correo,
        "password_hash": hash_pw,
        "rol": "cliente",
        "restaurante_id": None,
        "is_verified": verificado,
        "activo": activo,
        "telefono": "600000000",
        "direccion": "Calle Test 1",
        "latitud": None,
        "longitud": None,
    })
    return str(resultado.inserted_id)


def _insertar_pedido(usuario_id: str, total: float = 10.0) -> str:
    from database import coleccion_pedidos
    resultado = coleccion_pedidos.insert_one({
        "usuario_id": usuario_id,
        "total": total,
        "estado": "listo",
        "fecha": datetime.now(timezone.utc).isoformat(),
        "items": [{"nombre": "Pizza", "cantidad": 1, "precio": total}],
        "tipo_entrega": "local",
        "metodo_pago": "efectivo",
        "notas": "",
    })
    return str(resultado.inserted_id)


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTRO
# ═══════════════════════════════════════════════════════════════════════════════

_REGISTRO_BODY = {
    "nombre": "Ana Cliente",
    "correo": "ana@cliente.com",
    "password": "Segura1!",
    "telefono": "600000001",
    "direccion": "Calle Real 1",
    "consentimiento_rgpd": True,
}


def test_registro_cliente_ok(client):
    """Registro exitoso → 200, rol forzado a 'cliente'."""
    with patch("routes.clientes.enviar_correo_verificacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/registro", json=_REGISTRO_BODY)
    assert resp.status_code == 200, resp.json()
    assert "correo" in resp.json()

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"correo": "ana@cliente.com"})
    assert doc is not None
    assert doc["rol"] == "cliente"


def test_registro_ignora_rol_admin(client):
    """Aunque el body envíe rol=admin, siempre se guarda como cliente."""
    body = {**_REGISTRO_BODY, "correo": "atacante@test.com", "rol": "admin"}
    with patch("routes.clientes.enviar_correo_verificacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/registro", json=body)
    assert resp.status_code == 200, resp.json()

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"correo": "atacante@test.com"})
    assert doc["rol"] == "cliente"


def test_registro_sin_consentimiento_devuelve_422(client):
    body = {**_REGISTRO_BODY, "correo": "sin_rgpd@test.com", "consentimiento_rgpd": False}
    with patch("routes.clientes.enviar_correo_verificacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/registro", json=body)
    assert resp.status_code == 422, resp.json()


def test_registro_correo_duplicado_devuelve_409(client):
    """Inserta el correo directamente en BD y verifica que el segundo registro devuelve 409."""
    from database import coleccion_usuarios
    correo_dup = "duplicado_409@test.com"
    coleccion_usuarios.insert_one({"correo": correo_dup, "rol": "cliente"})
    body_dup = {**_REGISTRO_BODY, "correo": correo_dup}
    with patch("routes.clientes.enviar_correo_verificacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/registro", json=body_dup)
    assert resp.status_code == 409, resp.json()


# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICAR EMAIL
# ═══════════════════════════════════════════════════════════════════════════════

def test_verificar_email_codigo_correcto(client):
    """Verifica que un código válido activa la cuenta."""
    from database import coleccion_usuarios
    from utils.auth_helpers import hash_otp, expiry_iso

    correo = "verificar@test.com"
    codigo = "123456"
    coleccion_usuarios.insert_one({
        "nombre": "Test",
        "correo": correo,
        "password_hash": "x",
        "rol": "cliente",
        "is_verified": False,
        "verification_code": hash_otp(codigo),
        "verification_code_expiry": expiry_iso(15),
    })

    resp = client.post("/api/v1/clientes/verificar-email",
                       json={"correo": correo, "codigo": codigo})
    assert resp.status_code == 200, resp.json()
    assert "verificada" in resp.json()["mensaje"].lower()

    doc = coleccion_usuarios.find_one({"correo": correo})
    assert doc["is_verified"] is True


def test_verificar_email_codigo_incorrecto(client):
    from database import coleccion_usuarios
    from utils.auth_helpers import hash_otp, expiry_iso

    correo = "verificar_mal@test.com"
    coleccion_usuarios.insert_one({
        "nombre": "Test",
        "correo": correo,
        "password_hash": "x",
        "rol": "cliente",
        "is_verified": False,
        "verification_code": hash_otp("999999"),
        "verification_code_expiry": expiry_iso(15),
    })

    resp = client.post("/api/v1/clientes/verificar-email",
                       json={"correo": correo, "codigo": "000000"})
    assert resp.status_code == 401, resp.json()


# ═══════════════════════════════════════════════════════════════════════════════
# REENVIAR CÓDIGO
# ═══════════════════════════════════════════════════════════════════════════════

def test_reenviar_codigo_no_verificado(client):
    uid = _insertar_cliente("reenviar@test.com", verificado=False)
    with patch("routes.clientes.enviar_correo_verificacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/reenviar-codigo",
                           json={"correo": "reenviar@test.com"})
    assert resp.status_code == 200, resp.json()


def test_reenviar_codigo_ya_verificado(client):
    _insertar_cliente("ya_verificado@test.com", verificado=True)
    with patch("routes.clientes.enviar_correo_verificacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/reenviar-codigo",
                           json={"correo": "ya_verificado@test.com"})
    assert resp.status_code == 409, resp.json()


def test_reenviar_codigo_usuario_no_existe(client):
    resp = client.post("/api/v1/clientes/reenviar-codigo",
                       json={"correo": "noexiste@test.com"})
    assert resp.status_code == 404, resp.json()


# ═══════════════════════════════════════════════════════════════════════════════
# RECUPERAR Y RESTABLECER CONTRASEÑA
# ═══════════════════════════════════════════════════════════════════════════════

def test_recuperar_password_usuario_existente(client):
    _insertar_cliente("recuperar@test.com")
    with patch("routes.clientes.enviar_correo_recuperacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/clientes/recuperar-password",
                           json={"correo": "recuperar@test.com"})
    assert resp.status_code == 200, resp.json()


def test_recuperar_password_usuario_no_existe(client):
    resp = client.post("/api/v1/clientes/recuperar-password",
                       json={"correo": "noexiste@test.com"})
    assert resp.status_code == 404, resp.json()


def test_restablecer_password_flujo_completo(client):
    """Solicita código → se almacena hash → restablece con código correcto."""
    from database import coleccion_usuarios
    from utils.auth_helpers import hash_otp, expiry_iso

    correo = "reset@test.com"
    _insertar_cliente(correo)

    codigo = "654321"
    coleccion_usuarios.update_one(
        {"correo": correo},
        {"$set": {"reset_code": hash_otp(codigo), "reset_code_expiry": expiry_iso(15)}},
    )

    resp = client.post("/api/v1/clientes/restablecer-password", json={
        "correo": correo,
        "codigo": codigo,
        "nueva_password": "NuevaClave2!",
    })
    assert resp.status_code == 200, resp.json()

    # La cuenta queda verificada
    doc = coleccion_usuarios.find_one({"correo": correo})
    assert doc["is_verified"] is True
    # El reset_code se limpia
    assert doc.get("reset_code") is None


def test_restablecer_password_codigo_incorrecto(client):
    from database import coleccion_usuarios
    from utils.auth_helpers import hash_otp, expiry_iso

    correo = "reset_mal@test.com"
    _insertar_cliente(correo)
    coleccion_usuarios.update_one(
        {"correo": correo},
        {"$set": {"reset_code": hash_otp("111111"), "reset_code_expiry": expiry_iso(15)}},
    )

    resp = client.post("/api/v1/clientes/restablecer-password", json={
        "correo": correo,
        "codigo": "000000",
        "nueva_password": "NuevaClave2!",
    })
    assert resp.status_code == 401, resp.json()


# ═══════════════════════════════════════════════════════════════════════════════
# GET /clientes/me
# ═══════════════════════════════════════════════════════════════════════════════

def test_me_sin_token_devuelve_401(client):
    resp = client.get("/api/v1/clientes/me")
    assert resp.status_code == 401


def test_me_con_token_cliente_devuelve_perfil(client):
    uid = _insertar_cliente("me_ok@test.com")
    tok = _tok_cliente(user_id=uid)
    resp = client.get("/api/v1/clientes/me", headers=tok)
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["correo"] == "me_ok@test.com"
    assert data["rol"] == "cliente"


def test_me_con_token_admin_devuelve_403(client):
    """Admins no pueden usar /clientes/me."""
    resp = client.get("/api/v1/clientes/me", headers=_tok_admin())
    assert resp.status_code == 403, resp.json()


def test_me_con_token_camarero_devuelve_403(client):
    resp = client.get("/api/v1/clientes/me", headers=_tok_camarero())
    assert resp.status_code == 403, resp.json()


# ═══════════════════════════════════════════════════════════════════════════════
# PUT /clientes/me
# ═══════════════════════════════════════════════════════════════════════════════

def test_actualizar_me_campos_seguros(client):
    uid = _insertar_cliente("actualizar@test.com")
    tok = _tok_cliente(user_id=uid)
    resp = client.put("/api/v1/clientes/me",
                      json={"nombre": "Nuevo Nombre", "telefono": "611222333"},
                      headers=tok)
    assert resp.status_code == 200, resp.json()

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": ObjectId(uid)})
    assert doc["nombre"] == "Nuevo Nombre"
    assert doc["telefono"] == "611222333"


def test_actualizar_me_sin_token_devuelve_401(client):
    resp = client.put("/api/v1/clientes/me", json={"nombre": "Test"})
    assert resp.status_code == 401


def test_actualizar_me_no_puede_cambiar_rol_ni_activo(client):
    """El modelo PerfilClienteActualizar no acepta 'rol' ni 'activo'."""
    uid = _insertar_cliente("no_rol@test.com")
    tok = _tok_cliente(user_id=uid)
    # Mandamos campos que no están en el modelo → se ignoran por Pydantic
    resp = client.put("/api/v1/clientes/me",
                      json={"nombre": "Ok", "activo": False, "rol": "admin"},
                      headers=tok)
    # La petición es válida (nombre se actualiza), los campos extra se ignoran
    assert resp.status_code == 200, resp.json()
    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": ObjectId(uid)})
    assert doc.get("activo", True) is not False
    assert doc.get("rol") == "cliente"


# ═══════════════════════════════════════════════════════════════════════════════
# PUT /clientes/me/password
# ═══════════════════════════════════════════════════════════════════════════════

def test_cambiar_password_propia_ok(client):
    uid = _insertar_cliente("pwd_ok@test.com", password="Segura1!")
    tok = _tok_cliente(user_id=uid)
    resp = client.put("/api/v1/clientes/me/password",
                      json={"password_actual": "Segura1!", "nueva_password": "NuevaClave2!"},
                      headers=tok)
    assert resp.status_code == 200, resp.json()

    # Verificar que el hash cambió
    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": ObjectId(uid)})
    assert bcrypt.checkpw(b"NuevaClave2!", doc["password_hash"].encode())


def test_cambiar_password_propia_incorrecta_devuelve_401(client):
    uid = _insertar_cliente("pwd_mal@test.com", password="Segura1!")
    tok = _tok_cliente(user_id=uid)
    resp = client.put("/api/v1/clientes/me/password",
                      json={"password_actual": "Incorrecta1!", "nueva_password": "Nueva2!XY"},
                      headers=tok)
    assert resp.status_code == 401, resp.json()


def test_cambiar_password_sin_token_devuelve_401(client):
    resp = client.put("/api/v1/clientes/me/password",
                      json={"password_actual": "x", "nueva_password": "y"})
    assert resp.status_code == 401


# ═══════════════════════════════════════════════════════════════════════════════
# GET /clientes/me/datos (RGPD)
# ═══════════════════════════════════════════════════════════════════════════════

def test_mis_datos_incluye_pedidos(client):
    uid = _insertar_cliente("datos_pedidos@test.com")
    _insertar_pedido(uid, total=20.0)
    _insertar_pedido(uid, total=35.0)

    tok = _tok_cliente(user_id=uid)
    resp = client.get("/api/v1/clientes/me/datos", headers=tok)
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert "pedidos" in data
    assert len(data["pedidos"]) == 2
    for p in data["pedidos"]:
        assert "id" in p
        assert "total" in p
        assert "productos" in p


def test_mis_datos_sin_pedidos_devuelve_lista_vacia(client):
    uid = _insertar_cliente("datos_sinpedidos@test.com")
    tok = _tok_cliente(user_id=uid)
    resp = client.get("/api/v1/clientes/me/datos", headers=tok)
    assert resp.status_code == 200, resp.json()
    assert resp.json()["pedidos"] == []


def test_mis_datos_no_incluye_pedidos_de_otro(client):
    uid1 = _insertar_cliente("datos_yo@test.com")
    uid2 = _insertar_cliente("datos_otro@test.com")
    _insertar_pedido(uid1, total=10.0)
    _insertar_pedido(uid2, total=99.0)

    tok = _tok_cliente(user_id=uid1)
    resp = client.get("/api/v1/clientes/me/datos", headers=tok)
    assert resp.status_code == 200, resp.json()
    assert len(resp.json()["pedidos"]) == 1
    assert resp.json()["pedidos"][0]["total"] == 10.0


def test_mis_datos_sin_token_devuelve_401(client):
    resp = client.get("/api/v1/clientes/me/datos")
    assert resp.status_code == 401


def test_mis_datos_admin_devuelve_403(client):
    resp = client.get("/api/v1/clientes/me/datos", headers=_tok_admin())
    assert resp.status_code == 403, resp.json()


# ═══════════════════════════════════════════════════════════════════════════════
# DELETE /clientes/me (baja RGPD)
# ═══════════════════════════════════════════════════════════════════════════════

def test_baja_rgpd_anonimiza_datos(client):
    uid = _insertar_cliente("baja@test.com")
    tok = _tok_cliente(user_id=uid)
    resp = client.delete("/api/v1/clientes/me", headers=tok)
    assert resp.status_code == 200, resp.json()
    assert "anonimizados" in resp.json()["mensaje"].lower()

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": ObjectId(uid)})
    assert doc is not None  # no borrado físico
    assert doc["nombre"] == "Usuario eliminado"
    assert "baja_" in doc["correo"]
    assert doc.get("rgpd_baja") is True
    assert doc.get("activo") is False
    assert doc.get("password_hash") == ""


def test_baja_rgpd_sin_token_devuelve_401(client):
    resp = client.delete("/api/v1/clientes/me")
    assert resp.status_code == 401


def test_baja_rgpd_admin_devuelve_403(client):
    resp = client.delete("/api/v1/clientes/me", headers=_tok_admin())
    assert resp.status_code == 403, resp.json()

def test_coordenada_fuera_de_rango_422(client):
    from tests.tok_helpers import tok
    resp = client.put("/api/v1/clientes/me",
                       headers=tok("cliente"),
                       json={"latitud": 999, "longitud": 0})
    assert resp.status_code == 422, resp.text
