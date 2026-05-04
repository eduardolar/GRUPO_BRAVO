"""Carga única y centralizada de variables de entorno.

Sustituye las múltiples llamadas dispersas a `load_dotenv()` que existían
en main.py, database.py y routes/auth.py. Importar este módulo una sola
vez (al iniciar la app) garantiza que todas las variables se hayan
cargado en `os.environ` antes de leerlas.

Orden de prioridad (gana la última cargada):
  1) backend/.env  (real, NO versionado)
  2) backend/env   (alias antiguo, NO versionado, opcional)
  3) variables ya presentes en el entorno del SO o en GitHub Secrets
"""
from __future__ import annotations

import os
from pathlib import Path
from dotenv import load_dotenv

_BACKEND_DIR = Path(__file__).resolve().parent
_PROJECT_ROOT = _BACKEND_DIR.parent

# 1) Fichero principal: backend/.env
_env_dot = _BACKEND_DIR / ".env"
if _env_dot.exists():
    load_dotenv(dotenv_path=_env_dot, override=False)

# 2) Alias antiguo: backend/env (sin punto). Se mantiene por compatibilidad.
_env_alias = _BACKEND_DIR / "env"
if _env_alias.exists():
    load_dotenv(dotenv_path=_env_alias, override=False)

# 3) Fichero del directorio raíz del proyecto (sólo si existe).
_env_root = _PROJECT_ROOT / ".env"
if _env_root.exists():
    load_dotenv(dotenv_path=_env_root, override=False)


def get(key: str, default: str | None = None) -> str | None:
    """Acceso conveniente a variables de entorno tras la carga."""
    return os.getenv(key, default)


# Constantes de uso frecuente (lectura única tras la carga)
MONGO_URI: str | None = os.getenv("MONGO_URI")
HOST: str = os.getenv("HOST", "127.0.0.1")
PORT: int = int(os.getenv("PORT", "8000"))
ALLOWED_ORIGINS: str = os.getenv("ALLOWED_ORIGINS", "")
JWT_SECRET_KEY: str | None = os.getenv("JWT_SECRET_KEY")
STRIPE_SECRET_KEY: str | None = os.getenv("STRIPE_SECRET_KEY")
STRIPE_WEBHOOK_SECRET: str | None = os.getenv("STRIPE_WEBHOOK_SECRET")
