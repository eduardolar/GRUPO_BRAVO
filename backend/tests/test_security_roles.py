"""Tests para normalizar_rol y require_role.

Estos tests blindan el bug que se manifestaba como `403 Forbidden` cuando un
super admin (cuyo rol en MongoDB era `superadministrador`, `superadmin` o
incluso `Super Admin`) intentaba leer endpoints protegidos con
`require_role(["super_admin"])`.
"""
from fastapi import FastAPI, Depends, HTTPException
from fastapi.testclient import TestClient

from security import (
    normalizar_rol,
    require_role,
    crear_token,
    ROLES_CANONICOS,
)


class TestNormalizarRol:
    def test_canonicos_pasan_tal_cual(self):
        for r in ROLES_CANONICOS:
            assert normalizar_rol(r) == r

    def test_alias_legacy_a_canonicos(self):
        assert normalizar_rol("administrador") == "admin"
        assert normalizar_rol("superadministrador") == "super_admin"
        assert normalizar_rol("mesero") == "camarero"
        assert normalizar_rol("trabajador") == "camarero"
        assert normalizar_rol("empleado") == "camarero"

    def test_variantes_separadores(self):
        # Ningún separador rompe la normalización.
        assert normalizar_rol("super admin") == "super_admin"
        assert normalizar_rol("super-admin") == "super_admin"
        assert normalizar_rol("Super_Admin") == "super_admin"
        assert normalizar_rol("SUPER ADMIN") == "super_admin"
        assert normalizar_rol("superadmin") == "super_admin"

    def test_mayusculas_y_espacios(self):
        assert normalizar_rol("  ADMIN  ") == "admin"
        assert normalizar_rol("Cliente") == "cliente"

    def test_no_string_devuelve_vacio(self):
        # type: ignore[arg-type]
        assert normalizar_rol(None) == ""  # noqa
        assert normalizar_rol(123) == ""  # noqa


class TestRequireRoleConFastAPI:
    """Levanta una mini app FastAPI y comprueba que require_role acepta y
    rechaza tokens reales."""

    def setup_method(self):
        app = FastAPI()

        @app.get("/solo-admin")
        def solo_admin(_: dict = Depends(require_role(["admin", "super_admin"]))):
            return {"ok": True}

        # Convertimos los HTTPException 401/403 a respuestas JSON estándar.
        @app.exception_handler(HTTPException)
        async def http_handler(_, exc):  # type: ignore[no-untyped-def]
            from fastapi.responses import JSONResponse
            return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})

        self.client = TestClient(app)

    def _get(self, rol_en_token: str | None):
        if rol_en_token is None:
            return self.client.get("/solo-admin")
        token = crear_token({"sub": "u1", "correo": "x@x.com", "rol": rol_en_token})
        return self.client.get(
            "/solo-admin",
            headers={"Authorization": f"Bearer {token}"},
        )

    def test_sin_token_devuelve_401(self):
        r = self.client.get("/solo-admin")
        assert r.status_code == 401

    def test_token_invalido_devuelve_401(self):
        r = self.client.get(
            "/solo-admin", headers={"Authorization": "Bearer no-es-un-jwt"}
        )
        assert r.status_code == 401

    def test_admin_canonico_pasa(self):
        assert self._get("admin").status_code == 200

    def test_super_admin_canonico_pasa(self):
        assert self._get("super_admin").status_code == 200

    def test_administrador_legacy_pasa(self):
        assert self._get("administrador").status_code == 200

    def test_superadministrador_legacy_pasa(self):
        assert self._get("superadministrador").status_code == 200

    def test_superadmin_sin_separador_pasa(self):
        assert self._get("superadmin").status_code == 200

    def test_super_admin_con_espacio_pasa(self):
        assert self._get("Super Admin").status_code == 200

    def test_super_admin_con_guion_pasa(self):
        assert self._get("super-admin").status_code == 200

    def test_cliente_no_pasa(self):
        assert self._get("cliente").status_code == 403

    def test_camarero_no_pasa(self):
        assert self._get("camarero").status_code == 403

    def test_cocinero_no_pasa(self):
        assert self._get("cocinero").status_code == 403

    def test_rol_desconocido_no_pasa(self):
        assert self._get("super_duper_admin").status_code == 403


class TestCrearTokenNormalizaRol:
    """El JWT debe llevar el rol canónico, independientemente de lo que haya
    en la BD."""

    def test_administrador_se_firma_como_admin(self):
        from jose import jwt
        from security import SECRET_KEY, ALGORITHM

        token = crear_token({"sub": "u1", "rol": "administrador"})
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["rol"] == "admin"

    def test_superadmin_se_firma_como_super_admin(self):
        from jose import jwt
        from security import SECRET_KEY, ALGORITHM

        token = crear_token({"sub": "u1", "rol": "superadmin"})
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        assert payload["rol"] == "super_admin"
