import os
import logging
import traceback
from pathlib import Path
from fastapi import APIRouter, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from limiter import limiter
from exceptions import AppError

# Cargar variables de entorno del archivo .env
load_dotenv()

# Puerto y host configurables desde .env o variables de entorno
PORT = int(os.getenv("PORT", 8000))
HOST = os.getenv("HOST", "127.0.0.1")
# Cargar variables de entorno desde el archivo local 'env' o 'env.local'
dotenv_path = Path(__file__).with_name("env")
dotenv_local_path = Path(__file__).with_name("env.local")
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
elif dotenv_local_path.exists():
    load_dotenv(dotenv_path=dotenv_local_path)
else:
    load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

from routes import auth, usuarios, categorias, productos, pedidos, mesas, reservas, ingredientes
from routes import restaurantes
import pagos
from tickets import router as tickets_router

logger = logging.getLogger("uvicorn")

app = FastAPI(title="API Restaurante Bravo")

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# --- CONFIGURACIÓN DE CORS CORREGIDA (PARA EVITAR 400 OPTIONS) ---
# Al usar allow_origins=["*"], permitimos que cualquier origen conecte.
# IMPORTANTE: allow_credentials debe ser False cuando usamos el comodín "*".
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False, 
    allow_methods=["*"],
    allow_headers=["*"],
)
# ----------------------------------------------------------------

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
app.include_router(v1)

@app.get("/")
def inicio():
    return {"status": "Servidor funcionando"}

if __name__ == "__main__":
    import uvicorn
    try:
        uvicorn.run(app, host=HOST, port=PORT)
    except OSError as exc:
        logger.error("No se pudo iniciar el servidor en %s:%d - %s", HOST, PORT, exc)
        print(f"ERROR: No se pudo iniciar el servidor en {HOST}:{PORT}. Puede que el puerto ya esté en uso. Usa otro puerto en la variable PORT o detén el proceso que lo está usando.")
        raise