import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, Header
from jose import JWTError, jwt

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "CAMBIAR_EN_PRODUCCION_clave_muy_larga_y_aleatoria_32chars")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

# Roles canónicos del sistema
ROLES_CANONICOS = {"cliente", "camarero", "cocinero", "admin", "super_admin"}

# Alias admitidos en entrada → rol canónico
_ALIAS_ROL = {
    "mesero": "camarero",
    "trabajador": "camarero",
    "administrador": "admin",
    "superadministrador": "super_admin",
}


def normalizar_rol(rol: str) -> str:
    r = rol.strip().lower()
    return _ALIAS_ROL.get(r, r)


def crear_token(data: dict) -> str:
    payload = data.copy()
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
    """Dependency factory: exige que el usuario tenga uno de los roles indicados."""
    def _check(current_user: dict = Depends(get_current_user)) -> dict:
        if current_user.get("rol") not in roles:
            raise HTTPException(status_code=403, detail="No tienes permiso para esta acción")
        return current_user
    return _check
