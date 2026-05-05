import logging
import traceback
from fastapi import APIRouter, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

import config  # carga .env una sola vez (efecto de import)
from limiter import limiter
from exceptions import AppError
import log_redactor

# Instala el filtro que redacta PAN/CVV/client_secret/Bearer/JWT/API keys
# antes de escribir en los logs (cumple PCI-DSS y RGPD).
log_redactor.install("uvicorn", "uvicorn.error", "uvicorn.access", "fastapi")

from routes import auth, usuarios, categorias, productos, pedidos, mesas, reservas, ingredientes, cupones
from routes import restaurantes
import pagos
from tickets import router as tickets_router

logger = logging.getLogger("uvicorn")

app = FastAPI(title="API Restaurante Bravo")

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# --- CORS: restringe orígenes en producción mediante ALLOWED_ORIGINS en .env ---
# Ejemplo producción: ALLOWED_ORIGINS=https://app.grupobravo.com,https://admin.grupobravo.com
# Desarrollo (vacío): permite cualquier origen, sin credenciales.
_allowed_origins = [o.strip() for o in config.ALLOWED_ORIGINS.split(",") if o.strip()]
if not _allowed_origins:
    _allowed_origins = ["*"]
_allow_credentials = _allowed_origins != ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=_allow_credentials,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Actor"],
)

@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    msgs = []
    for e in exc.errors():
        loc = " → ".join(str(l) for l in e["loc"] if l != "body")
        msgs.append(f"{loc}: {e['msg']}" if loc else e["msg"])
    return JSONResponse(status_code=422, content={"detail": "; ".join(msgs)})


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    from fastapi import HTTPException
    if isinstance(exc, HTTPException):
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
    logger.error("Error no controlado en %s %s:\n%s", request.method, request.url.path, traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor. Por favor, inténtalo de nuevo más tarde."},
    )

# Registrar routers bajo /api/v1
v1 = APIRouter(prefix="/api/v1")
v1.include_router(auth.router)
v1.include_router(usuarios.router)
v1.include_router(restaurantes.router)
v1.include_router(categorias.router)
v1.include_router(productos.router)
v1.include_router(pedidos.router)
v1.include_router(mesas.router)
v1.include_router(reservas.router)
v1.include_router(ingredientes.router)
v1.include_router(pagos.router)
v1.include_router(tickets_router)
v1.include_router(cupones.router)
app.include_router(v1)

@app.get("/", summary="Healthcheck básico", tags=["health"])
def inicio():
    return {"status": "Servidor funcionando"}

if __name__ == "__main__":
    import uvicorn
    try:
        uvicorn.run(app, host=config.HOST, port=config.PORT)
    except OSError as exc:
        logger.error(
            "No se pudo iniciar el servidor en %s:%d - %s. "
            "Puede que el puerto ya esté en uso. Cambia la variable PORT o detén el proceso que lo ocupa.",
            config.HOST, config.PORT, exc,
        )
        raise
