# ============================================================================
# backend/main.py
# ----------------------------------------------------------------------------
# Punto de entrada de la API REST de Grupo Bravo (FastAPI + MongoDB).
#
# Aquí se construye la aplicación FastAPI, se configuran middlewares globales
# (CORS, rate limiting, logging seguro), se registran los manejadores de
# errores y se montan todos los routers bajo el prefijo /api/v1.
#
# Diagrama mental del arranque:
#
#     import config          → carga variables de entorno desde .env
#     install log_redactor   → filtra secretos en los logs (PCI/RGPD)
#     FastAPI(...)           → crea la app
#     add_middleware(...)    → CORS, rate limit
#     exception_handler(...) → respuestas JSON uniformes ante errores
#     include_router(...)    → endpoints organizados por dominio
#     uvicorn.run(...)       → servidor ASGI escuchando peticiones
# ============================================================================

import logging
import traceback
from fastapi import APIRouter, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
# slowapi implementa rate limiting (limita peticiones por IP/usuario).
# Lo usamos para frenar fuerza bruta en /login y abusos en endpoints públicos.
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

import config  # Importar config ejecuta load_dotenv() una sola vez (efecto de import).

# Startup check: si ENV=production y faltan secretos críticos
# (STRIPE_WEBHOOK_SECRET, JWT_SECRET_KEY real), abortar el arranque ANTES de
# montar la app. Es preferible no arrancar a arrancar de forma insegura.
config.validar_entorno_produccion()
from limiter import limiter
from exceptions import AppError
import log_redactor

# Instala un filtro en los loggers principales para que NUNCA aparezcan en los
# logs datos sensibles (PAN de tarjeta, CVV, client_secret de Stripe, tokens
# Bearer, JWT, API keys...). Es un requisito de PCI-DSS y del RGPD.
log_redactor.install("uvicorn", "uvicorn.error", "uvicorn.access", "fastapi")

# Importamos los routers de cada dominio funcional. Cada uno expone sus
# endpoints (POST/GET/PUT/DELETE...) relativos a su prefijo (/auth, /pedidos,
# etc.) y luego se montan todos bajo /api/v1 más abajo.
from routes import auth, usuarios, clientes, categorias, productos, pedidos, mesas, reservas, ingredientes, cupones, cierres_caja, avisos_falta
from routes import restaurantes, uploads, super_admin
import pagos  # router de pagos (Stripe Checkout, webhook, etc.)
from tickets import router as tickets_router

# Logger que comparte salida con uvicorn (consola). Se usa para errores
# inesperados que no encajan en un AppError o en una validación Pydantic.
logger = logging.getLogger("uvicorn")

# Aplicación principal. El `title` aparece en la documentación auto-generada
# (Swagger UI en /docs y ReDoc en /redoc).
app = FastAPI(title="API Restaurante Bravo")

# --- Rate limiting global -------------------------------------------------
# `limiter` es un objeto Limiter de slowapi. Se guarda en app.state para que
# los decoradores @limiter.limit("...") en los routers puedan acceder a él,
# y se registra el handler que convierte RateLimitExceeded en HTTP 429.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# --- CORS: control de orígenes permitidos --------------------------------
# Los navegadores bloquean por defecto las peticiones AJAX entre dominios
# distintos (política same-origin). CORS le dice al navegador qué orígenes
# tienen permiso para llamar a esta API.
#
# En producción se define ALLOWED_ORIGINS en .env con la lista de dominios
# del frontend separados por coma:
#     ALLOWED_ORIGINS=https://app.grupobravo.com,https://admin.grupobravo.com
#
# En desarrollo (variable vacía) se permite "*" (cualquier origen), pero
# entonces NO se pueden enviar cookies/credenciales (limitación del estándar
# CORS: "*" y credenciales son incompatibles).
_allowed_origins = [o.strip() for o in config.ALLOWED_ORIGINS.split(",") if o.strip()]
if not _allowed_origins:
    _allowed_origins = ["*"]
_allow_credentials = _allowed_origins != ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=_allow_credentials,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    # Headers que el frontend puede enviar. Idempotency-Key se usa para evitar
    # duplicar pedidos/cobros si una petición se reintenta.
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
)

# --- Manejadores de errores globales -------------------------------------
# La idea es que el cliente SIEMPRE reciba un JSON con la forma
#     { "detail": "mensaje" }
# y un status code coherente, sin importar de qué capa venga el error.

@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    """Errores de negocio lanzados por el código (ver `exceptions.py`).

    Ejemplo: `raise AppError(404, "Pedido no encontrado")` en un servicio
    se convierte automáticamente en una respuesta HTTP 404 con detail.
    """
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    """Errores de validación de Pydantic (body/query/path mal formados).

    Por defecto FastAPI devuelve una estructura compleja con `loc`, `msg`,
    `type`...  Aquí la aplanamos a un string legible para el usuario final
    y respetamos el código 422 (Unprocessable Entity) que es el estándar.
    """
    msgs = []
    for e in exc.errors():
        # `loc` es una tupla tipo ("body", "campo", "subcampo"). Eliminamos
        # el prefijo "body" para que el mensaje quede más limpio.
        loc = " → ".join(str(l) for l in e["loc"] if l != "body")
        msgs.append(f"{loc}: {e['msg']}" if loc else e["msg"])
    return JSONResponse(status_code=422, content={"detail": "; ".join(msgs)})


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Red de seguridad: cualquier excepción no capturada cae aquí.

    - Si es una HTTPException de FastAPI (404 manual, 403, etc.), se respeta.
    - Si es otra cosa (bug, error de Mongo, etc.), se loggea con stack trace
      completo y se devuelve un 500 genérico SIN exponer detalles al cliente
      (evitamos filtrar rutas internas, queries, etc.).
    """
    from fastapi import HTTPException
    if isinstance(exc, HTTPException):
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
    logger.error("Error no controlado en %s %s:\n%s", request.method, request.url.path, traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor. Por favor, inténtalo de nuevo más tarde."},
    )

# --- Registro de routers bajo /api/v1 ------------------------------------
# Versionar la API en la URL (/api/v1/...) permite publicar una v2 en el
# futuro sin romper clientes antiguos. Cada router agrupa endpoints por
# dominio para mantener `main.py` limpio.
v1 = APIRouter(prefix="/api/v1")
v1.include_router(auth.router)          # login, registro, refresh token
v1.include_router(usuarios.router)      # CRUD de usuarios (admin)
v1.include_router(clientes.router)      # perfil del cliente, direcciones
v1.include_router(restaurantes.router)  # multi-tenant: sucursales
v1.include_router(categorias.router)    # categorías de la carta
v1.include_router(productos.router)     # productos de la carta + stock
v1.include_router(pedidos.router)       # pedidos en sala / takeaway / delivery
v1.include_router(mesas.router)         # mapa de mesas y QR
v1.include_router(reservas.router)      # reservas de mesa
v1.include_router(ingredientes.router)  # ingredientes y composición de productos
v1.include_router(pagos.router)         # Stripe Checkout + webhook
v1.include_router(tickets_router)       # generación de tickets PDF/ESCPOS
v1.include_router(cupones.router)       # códigos de descuento
v1.include_router(cierres_caja.router)  # cierres de caja (Z report)
v1.include_router(uploads.router)       # subida de imágenes a almacenamiento
v1.include_router(super_admin.router)   # endpoints de superadministrador
v1.include_router(avisos_falta.router)  # avisos de productos faltantes
app.include_router(v1)

@app.get("/", summary="Healthcheck básico", tags=["health"])
def inicio():
    """Endpoint mínimo para comprobar que el servidor está vivo.

    Útil para que Docker / Kubernetes / un balanceador sepan si el servicio
    está respondiendo (no comprueba Mongo: para eso habría un /healthz más
    completo).
    """
    return {"status": "Servidor funcionando"}

# --- Modo "python main.py" (sin uvicorn externo) -------------------------
# En producción se suele lanzar con `uvicorn main:app --host 0.0.0.0 ...`
# desde el Dockerfile o systemd. Este bloque permite arrancar también con
# `python main.py` durante el desarrollo local.
if __name__ == "__main__":
    import uvicorn
    try:
        uvicorn.run(app, host=config.HOST, port=config.PORT)
    except OSError as exc:
        # El error típico aquí es "address already in use": otro proceso
        # (un uvicorn antiguo, otro servicio) está escuchando en el puerto.
        logger.error(
            "No se pudo iniciar el servidor en %s:%d - %s. "
            "Puede que el puerto ya esté en uso. Cambia la variable PORT o detén el proceso que lo ocupa.",
            config.HOST, config.PORT, exc,
        )
        raise
