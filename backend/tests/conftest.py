"""Configuración compartida de los tests.

Aísla por completo la base de datos: sustituye `pymongo.MongoClient` por
`mongomock.MongoClient` ANTES de importar `database.py`. Así, aunque
`MONGO_URI` apunte a Atlas, los tests nunca tocan datos reales.
"""
import os
import sys
from pathlib import Path

import pytest

# 1) Añade backend/ al sys.path (los tests viven en backend/tests/)
_BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

# 2) Variables de entorno seguras y deterministas para los tests
os.environ.setdefault("MONGO_URI", "mongodb://localhost:27017/test")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-do-not-use-in-prod")
os.environ.setdefault("STRIPE_SECRET_KEY", "")
os.environ.setdefault("STRIPE_WEBHOOK_SECRET", "")
os.environ.setdefault("ALLOWED_ORIGINS", "")
os.environ.setdefault("MAIL_USERNAME", "test@example.com")
os.environ.setdefault("MAIL_PASSWORD", "x")
os.environ.setdefault("MAIL_FROM", "test@example.com")
os.environ.setdefault("MAIL_PORT", "587")
os.environ.setdefault("MAIL_SERVER", "localhost")

# 3) Sustituye MongoClient por mongomock antes de importar database
try:
    import mongomock
    import pymongo
    pymongo.MongoClient = mongomock.MongoClient  # type: ignore[assignment]
except ImportError:
    # mongomock no instalado: fallar de manera explícita en lugar de tocar la BD real
    raise RuntimeError(
        "mongomock es obligatorio en los tests para no tocar MongoDB real. "
        "Instala con: pip install mongomock"
    )

# 4) Stub de cloudinary para entornos sin la lib instalada.
# Tiene que instalarse antes que cualquier test importe `routes.uploads`
# (el TestClient lo carga vía main.app). Sin esto, los tests fuera de
# test_uploads.py revientan con AttributeError al cargar uploads.py.
import types
from unittest.mock import MagicMock

if "cloudinary" not in sys.modules:
    cloudinary_mod = types.ModuleType("cloudinary")
    cloudinary_mod.config = MagicMock()  # cloudinary_client.py llama a esto
    uploader_mod = types.ModuleType("cloudinary.uploader")
    uploader_mod.upload = MagicMock()
    uploader_mod.destroy = MagicMock()
    cloudinary_mod.uploader = uploader_mod
    sys.modules["cloudinary"] = cloudinary_mod
    sys.modules["cloudinary.uploader"] = uploader_mod


@pytest.fixture(scope="session")
def client():
    """TestClient compartido a nivel de sesión."""
    from fastapi.testclient import TestClient
    from main import app
    with TestClient(app) as c:
        yield c


@pytest.fixture(autouse=True)
def _limpiar_colecciones():
    """Después de cada test, vacía todas las colecciones para evitar
    contaminación entre tests."""
    yield
    from database import db
    for nombre in db.list_collection_names():
        db[nombre].delete_many({})


# ── Re-export de helpers de tokens ───────────────────────────────────────────
# Los helpers de tokens viven en tok_helpers.py para que los test files
# puedan importarlos directamente sin depender del conftest (que no es
# importable como módulo normal desde dentro de los tests).
from tests.tok_helpers import (  # noqa: F401  (re-export para compatibilidad)
    tok,
    insertar_usuario_test,
    TEST_OID_SUPER,
    TEST_OID_ADMIN,
    TEST_OID_CAMARERO,
    TEST_OID_COCINERO,
    TEST_OID_CLIENTE,
)
