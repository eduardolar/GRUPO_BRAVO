# ============================================================================
# backend/security.py
# ----------------------------------------------------------------------------
# Capa de seguridad: emisión y verificación de JWT + control de roles.
#
# Conceptos clave:
#   - JWT (JSON Web Token): cadena firmada que el cliente envía en cada
#     petición protegida (header `Authorization: Bearer <token>`). El
#     servidor verifica la firma con `SECRET_KEY` y confía en el contenido
#     SIN tocar la base de datos (excepto el lookup ligero que hacemos
#     aquí por seguridad extra: suspensiones, cambios de rol).
#   - "Roles canónicos": nombres internos para los roles. El sistema
#     evolucionó y aún hay alias antiguos en BD ("administrador", "mesero").
#     Aquí los normalizamos a {cliente, camarero, cocinero, admin, super_admin}.
#
# Flujo de autenticación:
#   1) POST /api/v1/auth/login → crear_token(...) devuelve el JWT.
#   2) El frontend lo guarda y lo envía en `Authorization: Bearer ...`.
#   3) Cualquier endpoint protegido usa `Depends(get_current_user)`.
#   4) Si el endpoint requiere un rol, usa `Depends(require_role(["admin"]))`.
# ============================================================================
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

from bson import ObjectId
from bson.errors import InvalidId
from fastapi import Depends, HTTPException, Header
from jose import JWTError, jwt

logger = logging.getLogger("uvicorn.error")

# SECRET_KEY firma todos los JWT. Si se filtra, cualquiera puede generar
# tokens válidos (incluso de admin). En producción DEBE venir de .env y ser
# suficientemente larga y aleatoria (>= 32 bytes random). El default visible
# aquí es un placeholder explícito para que no arranque accidentalmente
# en producción sin definirla bien.
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "CAMBIAR_EN_PRODUCCION_clave_muy_larga_y_aleatoria_32chars")
ALGORITHM = "HS256"  # HMAC-SHA256: simétrico, mismo secreto firma y verifica.
# Duración del access token. Si pones un valor pequeño (15 min), exiges
# implementar un refresh-token. 60 min es un compromiso razonable en MVP.
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

# Roles canónicos del sistema (los únicos que el resto del código entiende).
ROLES_CANONICOS = {"cliente", "camarero", "cocinero", "admin", "super_admin"}

# Alias admitidos en entrada → rol canónico.
# Cualquier separador no alfanumérico (espacio, guion, guion bajo) se
# elimina antes de buscar, así "super admin", "super-admin" y "Super_Admin"
# caen todos en "superadmin" → super_admin.
#
# Por qué existe este mapa: el proyecto arrastra históricos donde se llamaba
# "administrador", "mesero", "trabajador" a los roles. Normalizar evita
# tener que migrar la BD de golpe y aceptar las dos formas en /login.
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
    """Devuelve el rol canónico.

    Acepta variantes con espacios, guiones, mayúsculas y los alias legacy
    del proyecto. Si el rol no se reconoce, devuelve el original limpio
    (en minúsculas, sin separadores) para que el log de require_role
    revele qué llegó exactamente.
    """
    if not isinstance(rol, str):
        return ""
    # Quitamos cualquier separador (`_`, `-`, espacios) y bajamos a minúsculas
    # para que el mapa _ALIAS_ROL pueda matchear con una única clave.
    r = rol.strip().lower().replace(" ", "").replace("-", "").replace("_", "")
    return _ALIAS_ROL.get(r, r)


def crear_token(data: dict) -> str:
    """Firma un JWT con `data` + claim de expiración.

    Convención: incluimos al menos `sub` (subject = id del usuario) y `rol`.
    El frontend solo necesita guardar el string resultante; el contenido se
    puede leer (no es encriptado, solo firmado), así que NO metas secretos.
    """
    payload = data.copy()
    # Normaliza el rol antes de firmar: el JWT siempre lleva el rol canónico
    # ("admin" en lugar de "administrador", "super_admin" en lugar de
    # "superadministrador", etc.). Así no dependemos de qué hay en BD para
    # comparar roles en require_role.
    rol = payload.get("rol")
    if isinstance(rol, str):
        payload["rol"] = normalizar_rol(rol)
    # exp se compara contra la hora actual al verificar. Usamos UTC para
    # evitar problemas con cambios de huso/horario de verano.
    payload["exp"] = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def _decodificar_token(token: str) -> dict:
    """Verifica firma + expiración y devuelve el payload.

    Levanta 401 ante cualquier fallo (firma inválida, token expirado,
    formato corrupto). El mensaje es genérico a propósito: no queremos
    ayudar a un atacante distinguir entre "firmado mal" y "caducado".
    """
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")


def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    """Decodifica el JWT y revalida el estado del usuario contra la BD.

    Además de verificar la firma y expiración del token, realiza un lookup
    ligero en `coleccion_usuarios` para garantizar que:
      - El usuario sigue existiendo (no fue borrado físicamente).
      - La cuenta está activa (`activo != False`).
      - El rol actual de BD se usa si difiere del del JWT (cambio de rol en caliente).

    Tradeoff: añade un `find_one` por cada request autenticado.
    Para el tamaño actual del proyecto (dev/MVP) es asumible.
    En producción con carga alta conviene cachear con TTL corto (Redis o
    lru_cache con ttl) para no saturar MongoDB con lecturas de sesión.
    """
    # El header debe venir como "Bearer <token>". Cualquier otra forma
    # (vacío, otro esquema) se trata como no autenticado.
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Autenticación requerida")
    token = authorization.removeprefix("Bearer ").strip()
    payload = _decodificar_token(token)

    # Lookup ligero: solo leemos `activo` y `rol` para minimizar I/O.
    # Import LOCAL para evitar ciclo de imports (security ↔ database).
    from database import coleccion_usuarios

    sub = payload.get("sub", "")
    try:
        # El `sub` es el `_id` del usuario serializado como string.
        # ObjectId valida que sea hex de 24 chars; si no, sesión inválida.
        oid = ObjectId(sub)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=401, detail="Sesión inválida, vuelve a entrar")

    # Projection {"activo": 1, "rol": 1} = solo traemos esos campos.
    # Evitamos transferir password_hash, datos personales, etc.
    doc = coleccion_usuarios.find_one({"_id": oid}, {"activo": 1, "rol": 1})
    if doc is None:
        # El usuario fue borrado pero su JWT sigue vigente. Cerramos sesión.
        raise HTTPException(status_code=401, detail="Sesión inválida, vuelve a entrar")
    if doc.get("activo") is False:
        # El admin suspendió la cuenta. Tampoco dejamos pasar.
        raise HTTPException(status_code=401, detail="Cuenta suspendida")

    # Si el admin cambió el rol del usuario mientras tenía sesión abierta,
    # forzamos el rol de BD para que require_role lo evalúe correctamente.
    # (El JWT es estático; BD es la fuente de verdad para autorización.)
    rol_bd = normalizar_rol(doc.get("rol", ""))
    rol_jwt = normalizar_rol(payload.get("rol", ""))
    if rol_bd and rol_bd != rol_jwt:
        logger.warning(
            "Rol en BD (%r) difiere del JWT (%r) para sub=%s — se usa el de BD",
            rol_bd, rol_jwt, sub,
        )
        payload["rol"] = rol_bd

    return payload


def require_role(roles: list[str]):
    """Dependency factory: exige que el usuario tenga uno de los roles indicados.

    Uso típico en un router:
        @router.post("/usuarios", dependencies=[Depends(require_role(["admin"]))])
        def crear_usuario(...): ...

    O para inyectar el usuario actual además del check:
        def endpoint(user=Depends(require_role(["admin", "super_admin"]))): ...

    Normaliza tanto el rol del JWT como los roles esperados, así un token
    que (por la razón que sea) lleve el alias legacy `administrador` cumple
    igual el requisito de `admin`.
    """
    # Se calcula una sola vez (al crear el decorador), no en cada request.
    roles_canonicos = {normalizar_rol(r) for r in roles}

    def _check(current_user: dict = Depends(get_current_user)) -> dict:
        rol_jwt = current_user.get("rol", "")
        rol_norm = normalizar_rol(rol_jwt) if isinstance(rol_jwt, str) else ""
        if rol_norm not in roles_canonicos:
            # Log interno con detalle (qué rol llegó vs cuáles se esperaban)
            # para acelerar diagnóstico de 403. Al cliente sólo le devolvemos
            # un mensaje genérico, sin filtrar la lista de roles válidos
            # (evitar fingerprint de la API por parte de atacantes).
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
