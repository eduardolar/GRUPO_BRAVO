import os
import logging
import traceback
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from routes import auth, usuarios, categorias, productos, pedidos, mesas, reservas, ingredientes
from routes import restaurantes
import pagos

logger = logging.getLogger("uvicorn")

app = FastAPI(title="API Restaurante Bravo")

# Configuración de CORS
# En producción define ALLOWED_ORIGINS en el .env con las URLs reales del frontend.
# Ejemplo: ALLOWED_ORIGINS=https://miapp.com,https://admin.miapp.com
_raw_origins = os.getenv("ALLOWED_ORIGINS", "")
allowed_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]
# Sin orígenes explícitos (desarrollo) se permite cualquier origen.
# allow_credentials es incompatible con "*", y el auth es por token (no cookies).
_wildcard = not allowed_origins
if _wildcard:
    allowed_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=not _wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # El detalle completo se queda en los logs del servidor, nunca en la respuesta al cliente
    logger.error("Error no controlado en %s %s:\n%s", request.method, request.url.path, traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor. Por favor, inténtalo de nuevo más tarde."},
    )

# Registrar routers
app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(restaurantes.router) # nuevo router para restaurantes 
app.include_router(categorias.router)
app.include_router(productos.router)
app.include_router(pedidos.router)
app.include_router(mesas.router)
app.include_router(reservas.router)
app.include_router(ingredientes.router)
app.include_router(pagos.router)

@app.get("/")
def inicio():
    return {"status": "Servidor funcionando"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
