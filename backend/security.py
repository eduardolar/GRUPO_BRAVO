import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, Header
from jose import JWTError, jwt

logger = logging.getLogger("uvicorn.error")

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "CAMBIAR_EN_PRODUCCION_clave_muy_larga_y_aleatoria_32chars")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

# Roles canónicos del sistema
ROLES_CANONICOS = {"cliente", "camarero", "cocinero", "admin", "super_admin"}

# Alias admitidos en entrada → rol canónico.
# Cualquier separador no alfanumérico (espacio, guion) se elimina antes de
# buscar, así que "super admin", "super-admin" y "Super_Admin" caen todos
# en "superadmin" → super_admin.
_ALIAS_ROL = {
    "mesero": "camarero",
    "trabajador": "camarero",
    "empleado": "camarero",
    "administrador": "admin",
    "superadministrador": "super_admin",
    "superadmin": "super_admin",
    "super_admin": "super_admin",
    "admin": "admin",
    "cocinero": "cocinero",
    "camarero": "camarero",
    "cliente": "cliente",
}


def normalizar_rol(rol: str) -> str:
    """Devuelve el rol canónico. Acepta variantes con espacios, guiones,
    mayúsculas, y los alias legacy del proyecto."""
    if not isinstance(rol, str):
        return ""
    # Quitamos cualquier separador (`_`, `-`, espacios) y bajamos a minúsculas.
    r = rol.strip().lower().replace(" ", "").replace("-", "").replace("_", "")
    return _ALIAS_ROL.get(r, r)


def crear_token(data: dict) -> str:
    payload = data.copy()
    # Normaliza el rol antes de firmar: el JWT siempre lleva el rol canónico
    # ("admin" en lugar de "administrador", "super_admin" en lugar de
    # "superadministrador", etc.). Así no dependemos de qué hay en BD.
    rol = payload.get("rol")
    if isinstance(rol, str):
        payload["rol"] = normalizar_rol(rol)
    payload["exp"] = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def _decodificar_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")


def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Autenticación requerida")
    token = authorization.removeprefix("Bearer ").strip()
    return _decodificar_token(token)


def require_role(roles: list[str]):
    """Dependency factory: exige que el usuario tenga uno de los roles indicados.

    Normaliza tanto el rol del JWT como los roles esperados, así un token
    que (por la razón que sea) lleve el alias legacy `administrador` cumple
    igual el requisito de `admin`.
    """
    roles_canonicos = {normalizar_rol(r) for r in roles}

    def _check(current_user: dict = Depends(get_current_user)) -> dict:
        rol_jwt = current_user.get("rol", "")
        rol_norm = normalizar_rol(rol_jwt) if isinstance(rol_jwt, str) else ""
        if rol_norm not in roles_canonicos:
            # Log interno con detalle (qué rol llegó vs cuáles se esperaban)
            # para acelerar diagnóstico de 403. Al cliente sólo le devolvemos
            # un mensaje genérico, sin filtrar la lista de roles válidos.
            correo = current_user.get("correo", "?")
            logger.warning(
                "403 require_role: usuario=%s rol_jwt=%r rol_norm=%r esperados=%s",
                correo, rol_jwt, rol_norm, sorted(roles_canonicos),
            )
            raise HTTPException(
                status_code=403,
                detail="No tienes permiso para esta acción",
            )
        return current_user

    return _check
