# ============================================================================
# backend/config.py
# ----------------------------------------------------------------------------
# Carga ÚNICA y centralizada de variables de entorno.
#
# ¿Por qué centralizar?
#   Antes había varios `load_dotenv()` repartidos en main.py, database.py y
#   routes/auth.py. Eso es frágil: si un módulo se importa antes que otro,
#   alguien puede leer una variable que todavía no se ha cargado.
#   Importando `config` UNA vez al arrancar (lo hace main.py), garantizamos
#   que `os.environ` ya contiene todo cuando el resto del código lo lee.
#
# Orden de prioridad (gana la ÚLTIMA fuente cargada con `override=False` no
# pisa lo ya existente; aquí cada `load_dotenv` respeta lo previo):
#   1) backend/.env             (real, NO versionado, prioridad máxima)
#   2) backend/env              (alias antiguo sin punto, compatibilidad)
#   3) .env en la raíz del proyecto
#   4) Variables ya existentes en el entorno (SO, Docker, GitHub Secrets)
#
# Para inspirarte sobre qué variables existen, mira `.env.example`.
# ============================================================================
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

# Path(__file__) → ruta a este archivo. .resolve() lo vuelve absoluto.
# .parent sube un nivel → backend/. Otra vez .parent → raíz del proyecto.
_BACKEND_DIR = Path(__file__).resolve().parent
_PROJECT_ROOT = _BACKEND_DIR.parent

# 1) Fichero principal: backend/.env (es el que usa el desarrollador local).
_env_dot = _BACKEND_DIR / ".env"
if _env_dot.exists():
    # override=False = no pisar variables ya definidas en el SO.
    # Útil en producción: las vars del entorno del contenedor mandan.
    load_dotenv(dotenv_path=_env_dot, override=False)

# 2) Alias antiguo: backend/env (sin punto). Se mantiene por compatibilidad
# con instalaciones viejas; no es lo recomendado para nuevos entornos.
_env_alias = _BACKEND_DIR / "env"
if _env_alias.exists():
    load_dotenv(dotenv_path=_env_alias, override=False)

# 3) Fichero del directorio raíz del proyecto (sólo si existe).
# Útil cuando alguien arranca el backend desde la raíz con docker-compose.
_env_root = _PROJECT_ROOT / ".env"
if _env_root.exists():
    load_dotenv(dotenv_path=_env_root, override=False)


def get(key: str, default: str | None = None) -> str | None:
    """Atajo sobre `os.getenv` para leer variables tras la carga.

    Útil si en algún sitio quieres una API explícita en vez de tocar
    `os.environ` directamente, pero NO es obligatorio: las constantes de
    abajo cubren los casos más usados.
    """
    return os.getenv(key, default)


# --- Constantes "calientes" -------------------------------------------------
# Se leen una sola vez aquí, justo después de los load_dotenv. A partir de
# ese momento son inmutables (hasta que se reinicia la app). Cualquier otro
# módulo hace `from config import MONGO_URI` y obtiene el mismo valor.
#
# OJO: si una variable falta (vale None), el código que la usa debe lanzar
# error claro al arrancar. Por eso preferimos `os.getenv()` (devuelve None)
# en lugar de `os.environ[...]` (lanza KeyError tarde y críptico).

MONGO_URI: str | None = os.getenv("MONGO_URI")              # cadena de conexión a Mongo Atlas / local
HOST: str = os.getenv("HOST", "127.0.0.1")                  # host donde escucha uvicorn
PORT: int = int(os.getenv("PORT", "8000"))                  # puerto del servidor
ALLOWED_ORIGINS: str = os.getenv("ALLOWED_ORIGINS", "")     # CSV de orígenes CORS permitidos
JWT_SECRET_KEY: str | None = os.getenv("JWT_SECRET_KEY")    # secreto HMAC para firmar JWT
STRIPE_SECRET_KEY: str | None = os.getenv("STRIPE_SECRET_KEY")        # `sk_test_...` o `sk_live_...`
STRIPE_WEBHOOK_SECRET: str | None = os.getenv("STRIPE_WEBHOOK_SECRET")  # `whsec_...` para verificar la firma

# Entorno de ejecución. En "development"/"dev"/"test" se relajan algunas
# validaciones (p. ej. permitir TLDs reservados como .test/.localhost en
# emails). Default = "production" para que la app despliegue SEGURA por
# defecto si la variable no se define explícitamente. Esto evita el bug
# clásico de "olvidé poner ENV en producción y arranca como dev".
ENV: str = os.getenv("ENV", "production").lower()
IS_PRODUCTION: bool = ENV in {"production", "prod"}
