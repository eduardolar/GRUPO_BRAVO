"""Helpers de tokens para tests.

Centraliza la creación de tokens JWT con ObjectIds reales e inserción
del usuario en mongomock, requeridos desde el Fix 3 de get_current_user
(revalidación de activo y rol en BD por cada request autenticado).

Uso típico en un test file:
    from tests.tok_helpers import tok, insertar_usuario_test, TEST_OID_ADMIN
"""
from bson import ObjectId

# ── IDs fijos por rol ──────────────────────────────────────────────────────────
# Cada rol tiene un ObjectId predefinido que se reutiliza en todos los tests.
# Los tests que necesiten múltiples usuarios del mismo rol deben crear OIDs propios
# y llamar directamente a insertar_usuario_test().

TEST_OID_SUPER    = ObjectId("aaaaaaaaaaaaaaaaaaaaaaaa")
TEST_OID_ADMIN    = ObjectId("bbbbbbbbbbbbbbbbbbbbbbbb")
TEST_OID_CAMARERO = ObjectId("dddddddddddddddddddddddd")
TEST_OID_COCINERO = ObjectId("eeeeeeeeeeeeeeeeeeeeeeee")
TEST_OID_CLIENTE  = ObjectId("ffffffffffffffffffffffff")


def insertar_usuario_test(
    oid: ObjectId,
    rol: str,
    restaurante_id: str | None = None,
) -> None:
    """Inserta (o reemplaza) un usuario activo en mongomock.

    Llamar antes de cualquier request que pase por get_current_user,
    ya que el Fix 3 valida activo y rol contra la BD en cada request.
    """
    from database import coleccion_usuarios
    from security import normalizar_rol
    doc: dict = {
        "_id": oid,
        "correo": f"{normalizar_rol(rol)}@test.com",
        "rol": normalizar_rol(rol),
        "activo": True,
    }
    if restaurante_id is not None:
        doc["restaurante_id"] = restaurante_id
    coleccion_usuarios.replace_one({"_id": oid}, doc, upsert=True)


def tok(
    rol: str,
    oid: ObjectId | None = None,
    restaurante_id: str | None = None,
    correo: str | None = None,
) -> dict:
    """Crea un token JWT e inserta el usuario en mongomock.

    Devuelve ``{"Authorization": "Bearer <token>"}`` listo para
    pasar como ``headers=`` en el TestClient.

    Parámetros:
        rol: rol canónico o alias legacy (se normaliza antes de firmar y de insertar).
        oid: ObjectId a usar como sub. Si None, elige el fijo según el rol.
        restaurante_id: si se indica, se persiste en el documento de usuario.
        correo: correo del usuario; si None se genera uno genérico.
    """
    from security import crear_token, normalizar_rol

    _ROL_A_OID = {
        "super_admin": TEST_OID_SUPER,
        "admin":       TEST_OID_ADMIN,
        "camarero":    TEST_OID_CAMARERO,
        "cocinero":    TEST_OID_COCINERO,
        "cliente":     TEST_OID_CLIENTE,
    }
    rol_canonico = normalizar_rol(rol)
    if oid is None:
        oid = _ROL_A_OID.get(rol_canonico, ObjectId())

    correo = correo or f"{rol_canonico}@test.com"
    insertar_usuario_test(oid, rol_canonico, restaurante_id)

    payload: dict = {"sub": str(oid), "correo": correo, "rol": rol}
    if restaurante_id is not None:
        payload["restaurante_id"] = restaurante_id

    token = crear_token(payload)
    return {"Authorization": f"Bearer {token}"}
