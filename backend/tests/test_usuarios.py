"""Tests de aislamiento y seguridad para /api/v1/usuarios.

Cubre:
  - Admin crea camarero en su sucursal → 201.
  - Admin intenta crear admin → 403.
  - Admin ignora silenciosamente restaurante_id ajeno → usa el del JWT.
  - Admin elimina usuario de su sucursal → 200 soft-delete (activo=false).
  - Admin intenta eliminar usuario de otra sucursal → 403.
  - super_admin elimina → 200 borrado físico.
  - Reactivar usuario suspendido → 200, activo=true.
  - Sin token → 401 en endpoints protegidos.
"""
from unittest.mock import AsyncMock, patch, MagicMock
from bson import ObjectId
from security import crear_token


# ─── Helpers de tokens ────────────────────────────────────────────────────────

def _tok_admin(rid: str = "R1") -> dict:
    token = crear_token({
        "sub": "admin_r1_id",
        "correo": "admin@r1.com",
        "rol": "admin",
        "restaurante_id": rid,
    })
    return {"Authorization": f"Bearer {token}"}


def _tok_admin_r2() -> dict:
    token = crear_token({
        "sub": "admin_r2_id",
        "correo": "admin@r2.com",
        "rol": "admin",
        "restaurante_id": "R2",
    })
    return {"Authorization": f"Bearer {token}"}


def _tok_super() -> dict:
    token = crear_token({
        "sub": "super_id",
        "correo": "super@bravo.com",
        "rol": "super_admin",
    })
    return {"Authorization": f"Bearer {token}"}


# ─── Datos de test reutilizables ──────────────────────────────────────────────

_CAMARERO_BODY = {
    "nombre": "Juan Camarero",
    "correo": "juan@camarero.com",
    "password": "Segura1!",
    "rol": "camarero",
    "restaurante_id": "R1",
}


# ─── Tarea 1.1 — Crear usuario ────────────────────────────────────────────────

def test_admin_crea_camarero_en_su_sucursal(client):
    """Admin puede crear camarero; el restaurante_id se fuerza al del JWT."""
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/usuarios/",
            json=_CAMARERO_BODY,
            headers=_tok_admin("R1"),
        )
    assert resp.status_code == 201 or resp.status_code == 200, resp.json()
    data = resp.json()
    assert "id" in data

    # Verificar que se persistió con la sucursal del JWT (R1), no la del body
    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"correo": "juan@camarero.com"})
    assert doc is not None
    assert doc["restaurante_id"] == "R1"
    assert doc["rol"] == "camarero"


def test_admin_no_puede_crear_admin(client):
    """Admin no puede asignar rol=admin a un nuevo usuario → 403."""
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/usuarios/",
            json={**_CAMARERO_BODY, "correo": "nuevo_admin@test.com", "rol": "admin"},
            headers=_tok_admin("R1"),
        )
    assert resp.status_code == 403, resp.json()


def test_admin_no_puede_crear_super_admin(client):
    """Admin no puede asignar rol=super_admin → 403."""
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/usuarios/",
            json={**_CAMARERO_BODY, "correo": "nuevo_super@test.com", "rol": "super_admin"},
            headers=_tok_admin("R1"),
        )
    assert resp.status_code == 403, resp.json()


def test_admin_crea_empleado_con_restaurante_ajeno_usa_jwt(client):
    """Si el admin manda restaurante_id='R99' en el body, se ignora y se usa R1 del JWT."""
    body = {**_CAMARERO_BODY, "correo": "forced@test.com", "restaurante_id": "R99"}
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/usuarios/",
            json=body,
            headers=_tok_admin("R1"),
        )
    assert resp.status_code in (200, 201), resp.json()
    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"correo": "forced@test.com"})
    assert doc is not None
    # Debe tener R1 (del JWT), no R99 (del body)
    assert doc["restaurante_id"] == "R1"


def test_super_admin_puede_crear_admin(client):
    """super_admin puede asignar rol=admin."""
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/usuarios/",
            json={**_CAMARERO_BODY, "correo": "nuevo_admin2@test.com", "rol": "admin"},
            headers=_tok_super(),
        )
    assert resp.status_code in (200, 201), resp.json()


def test_sin_token_crea_usuario_401(client):
    resp = client.post("/api/v1/usuarios/", json=_CAMARERO_BODY)
    assert resp.status_code == 401


# ─── Tarea 1.2 — Delete / soft-delete ────────────────────────────────────────

def _insertar_usuario(correo: str, rol: str = "camarero", rid: str = "R1") -> str:
    """Inserta un usuario en la BD de test y devuelve su id string."""
    from database import coleccion_usuarios
    resultado = coleccion_usuarios.insert_one({
        "nombre": "Test User",
        "correo": correo,
        "password_hash": "x",
        "rol": rol,
        "restaurante_id": rid,
        "activo": True,
    })
    return str(resultado.inserted_id)


def test_admin_suspende_usuario_de_su_sucursal(client):
    """Admin elimina (soft-delete) usuario de su sucursal → 200, activo=false en BD."""
    uid = _insertar_usuario("camarero1@test.com", "camarero", "R1")
    resp = client.delete(f"/api/v1/usuarios/{uid}", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert "suspendido" in data["mensaje"].lower()
    assert data.get("activo") is False

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": __import__("bson").ObjectId(uid)})
    assert doc is not None  # No borrado físicamente
    assert doc.get("activo") is False
    assert doc.get("suspendido_at") is not None


def test_admin_no_puede_suspender_usuario_de_otra_sucursal(client):
    """Admin de R1 no puede suspender usuarios de R2 → 403."""
    uid = _insertar_usuario("camarero_r2@test.com", "camarero", "R2")
    resp = client.delete(f"/api/v1/usuarios/{uid}", headers=_tok_admin("R1"))
    assert resp.status_code == 403, resp.json()

    # El usuario no debe haber sido tocado
    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": __import__("bson").ObjectId(uid)})
    assert doc is not None
    assert doc.get("activo", True) is True


def test_super_admin_elimina_fisicamente(client):
    """super_admin realiza borrado físico del usuario."""
    uid = _insertar_usuario("camarero_del@test.com", "camarero", "R1")
    resp = client.delete(f"/api/v1/usuarios/{uid}", headers=_tok_super())
    assert resp.status_code == 200, resp.json()
    assert "eliminado" in resp.json()["mensaje"].lower()

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"_id": __import__("bson").ObjectId(uid)})
    assert doc is None  # Borrado físico


def test_admin_elimina_fisicamente_si_target_ya_suspendido(client):
    """Segundo DELETE del admin sobre un usuario ya suspendido = hard-delete.
    Permite limpiar cuentas dadas de baja sin necesitar al super_admin."""
    from database import coleccion_usuarios
    from datetime import datetime, timezone
    uid = _insertar_usuario("ya_suspendido@test.com", "camarero", "R1")
    # Lo dejamos como ya suspendido
    coleccion_usuarios.update_one(
        {"_id": __import__("bson").ObjectId(uid)},
        {"$set": {"activo": False, "suspendido_at": datetime.now(timezone.utc).isoformat()}},
    )

    resp = client.delete(f"/api/v1/usuarios/{uid}", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    assert "eliminado" in resp.json()["mensaje"].lower()

    # Borrado físico real (ya no existe en BD)
    doc = coleccion_usuarios.find_one({"_id": __import__("bson").ObjectId(uid)})
    assert doc is None


def test_admin_no_puede_borrar_fisicamente_usuario_de_otra_sucursal_aunque_suspendido(client):
    """El permiso ampliado solo aplica a usuarios de la sucursal del admin:
    aislamiento por sucursal sigue mandando aunque ya esté suspendido."""
    from database import coleccion_usuarios
    from datetime import datetime, timezone
    uid = _insertar_usuario("ajeno_suspendido@test.com", "camarero", "R2")
    coleccion_usuarios.update_one(
        {"_id": __import__("bson").ObjectId(uid)},
        {"$set": {"activo": False, "suspendido_at": datetime.now(timezone.utc).isoformat()}},
    )

    # Admin de R1 intenta borrar a uno suspendido de R2
    resp = client.delete(f"/api/v1/usuarios/{uid}", headers=_tok_admin("R1"))
    assert resp.status_code == 403, resp.json()

    # Sigue existiendo en BD
    doc = coleccion_usuarios.find_one({"_id": __import__("bson").ObjectId(uid)})
    assert doc is not None


# ─── Tarea 1.3 — Reactivar usuario ────────────────────────────────────────────

def test_reactivar_usuario_suspendido(client):
    """Reactivar un usuario suspendido → 200, activo=true en BD."""
    from database import coleccion_usuarios
    from datetime import datetime, timezone
    uid = _insertar_usuario("suspendido@test.com", "camarero", "R1")
    # Suspender manualmente
    coleccion_usuarios.update_one(
        {"_id": __import__("bson").ObjectId(uid)},
        {"$set": {"activo": False, "suspendido_at": datetime.now(timezone.utc).isoformat()}},
    )

    resp = client.post(f"/api/v1/usuarios/{uid}/reactivar", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data.get("activo") is True

    doc = coleccion_usuarios.find_one({"_id": __import__("bson").ObjectId(uid)})
    assert doc["activo"] is True
    assert "suspendido_at" not in doc


def test_reactivar_usuario_otra_sucursal_403(client):
    """Admin de R1 no puede reactivar un usuario de R2 → 403."""
    from database import coleccion_usuarios
    from datetime import datetime, timezone
    uid = _insertar_usuario("suspendido_r2@test.com", "camarero", "R2")
    coleccion_usuarios.update_one(
        {"_id": __import__("bson").ObjectId(uid)},
        {"$set": {"activo": False, "suspendido_at": datetime.now(timezone.utc).isoformat()}},
    )

    resp = client.post(f"/api/v1/usuarios/{uid}/reactivar", headers=_tok_admin("R1"))
    assert resp.status_code == 403, resp.json()


def test_sin_token_reactivar_401(client):
    resp = client.post("/api/v1/usuarios/123456789012345678901234/reactivar")
    assert resp.status_code == 401


# ─── Tarea F6 — super_admin crea usuarios ────────────────────────────────────

def _insertar_restaurante(rid_str: str | None = None) -> str:
    """Inserta una sucursal de prueba y devuelve su id (ObjectId como string)."""
    from database import coleccion_restaurantes
    from bson import ObjectId
    doc = {
        "nombre": "Sucursal Test",
        "direccion": "Calle Test 1",
        "codigo": "TSTXX",
        "activo": True,
    }
    if rid_str:
        # Forzar un ObjectId concreto para facilitar los asserts
        doc["_id"] = ObjectId(rid_str)
    resultado = coleccion_restaurantes.insert_one(doc)
    return str(resultado.inserted_id)


def test_super_admin_puede_crear_admin(client):
    """super_admin puede asignar rol=admin en cualquier sucursal → 201/200."""
    rid = _insertar_restaurante()
    body = {
        "nombre": "Admin Nuevo",
        "correo": "nuevo_admin_f6@test.com",
        "password": "Segura1!",
        "rol": "admin",
        "restaurante_id": rid,
    }
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/usuarios/", json=body, headers=_tok_super())
    assert resp.status_code in (200, 201), resp.json()
    data = resp.json()
    assert "id" in data


def test_super_admin_no_puede_crear_super_admin(client):
    """super_admin no puede asignar rol=super_admin → 403."""
    rid = _insertar_restaurante()
    body = {
        "nombre": "Nuevo Super",
        "correo": "nuevo_super_f6@test.com",
        "password": "Segura1!",
        "rol": "super_admin",
        "restaurante_id": rid,
    }
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/usuarios/", json=body, headers=_tok_super())
    assert resp.status_code == 403, resp.json()


def test_super_admin_crea_en_sucursal_ajena(client):
    """super_admin puede crear empleado en sucursal distinta a la suya; el restaurante_id del body se respeta."""
    rid = _insertar_restaurante()
    body = {
        "nombre": "Camarero Ajena",
        "correo": "camarero_ajena_f6@test.com",
        "password": "Segura1!",
        "rol": "camarero",
        "restaurante_id": rid,
    }
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/usuarios/", json=body, headers=_tok_super())
    assert resp.status_code in (200, 201), resp.json()

    from database import coleccion_usuarios
    doc = coleccion_usuarios.find_one({"correo": "camarero_ajena_f6@test.com"})
    assert doc is not None
    # El super_admin no tiene restaurante_id en su token, pero el body debe respetarse
    assert doc["restaurante_id"] == rid


def test_super_admin_sin_restaurante_id_devuelve_422(client):
    """Si el super_admin no manda restaurante_id (o lo manda vacío) → 422."""
    body = {
        "nombre": "Sin Sucursal",
        "correo": "sin_sucursal_f6@test.com",
        "password": "Segura1!",
        "rol": "camarero",
        "restaurante_id": "",   # vacío equivale a ausente para nuestra validación
    }
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/usuarios/", json=body, headers=_tok_super())
    assert resp.status_code == 422, resp.json()


def test_super_admin_restaurante_inexistente_devuelve_404(client):
    """Si el super_admin manda un restaurante_id que no existe en BD → 404."""
    from bson import ObjectId
    rid_falso = str(ObjectId())  # ObjectId válido pero inexistente en BD
    body = {
        "nombre": "En Ningún Sitio",
        "correo": "inexistente_f6@test.com",
        "password": "Segura1!",
        "rol": "camarero",
        "restaurante_id": rid_falso,
    }
    with patch("routes.usuarios._enviar_correo_activacion", new_callable=AsyncMock):
        resp = client.post("/api/v1/usuarios/", json=body, headers=_tok_super())
    assert resp.status_code == 404, resp.json()


# ─── Login de usuarios suspendidos ────────────────────────────────────────────
# El soft-delete del admin debe bloquear el inicio de sesión: si activo=false
# el endpoint /login responde 403 sin consultar la contraseña.

import bcrypt


def _usuario_db(activo: bool, password: str = "Segura1!") -> dict:
    """Construye un doc de usuario con hash de password listo para login."""
    return {
        "_id": ObjectId(),
        "correo": "suspendido@test.com",
        "nombre": "Empleado Suspendido",
        "password_hash": bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode(),
        "rol": "camarero",
        "restaurante_id": "R1",
        "is_verified": True,
        "activo": activo,
    }


def test_login_usuario_suspendido_devuelve_403(client):
    suspendido = _usuario_db(activo=False)
    with patch("routes.auth.coleccion_usuarios") as mock_col:
        mock_col.find_one.return_value = suspendido
        resp = client.post(
            "/api/v1/login",
            json={"correo": "suspendido@test.com", "password": "Segura1!"},
        )
    assert resp.status_code == 403, resp.json()
    assert "suspendida" in resp.json()["detail"].lower()


def test_login_usuario_activo_funciona_con_credenciales_correctas(client):
    # Garantía de que el chequeo de `activo` no rompe el flujo normal:
    # un usuario sin el campo o con activo=true sigue pudiendo iniciar sesión.
    activo = _usuario_db(activo=True)
    with patch("routes.auth.coleccion_usuarios") as mock_col:
        mock_col.find_one.return_value = activo
        resp = client.post(
            "/api/v1/login",
            json={"correo": "suspendido@test.com", "password": "Segura1!"},
        )
    # 200 con access_token (no probamos la firma del token, solo que llega bien)
    assert resp.status_code == 200, resp.json()
    assert "access_token" in resp.json()


def test_login_usuario_legacy_sin_campo_activo_no_bloquea(client):
    # Usuarios creados antes del soft-delete no tienen el campo `activo`.
    # Por defecto se tratan como activos (no nos pueden bloquear todos los
    # usuarios viejos al introducir el chequeo).
    legacy = _usuario_db(activo=True)
    legacy.pop("activo")
    with patch("routes.auth.coleccion_usuarios") as mock_col:
        mock_col.find_one.return_value = legacy
        resp = client.post(
            "/api/v1/login",
            json={"correo": "suspendido@test.com", "password": "Segura1!"},
        )
    assert resp.status_code == 200, resp.json()
