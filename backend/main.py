import os
import logging
import traceback
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

# Cargar variables de entorno del archivo .env
load_dotenv()

# Puerto y host configurables desde .env o variables de entorno
PORT = int(os.getenv("PORT", 8001))
HOST = os.getenv("HOST", "127.0.0.1")

from routes import auth, usuarios, categorias, productos, pedidos, mesas, reservas, ingredientes
from routes import restaurantes
import pagos

logger = logging.getLogger("uvicorn")

app = FastAPI(title="API Restaurante Bravo")

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

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("Error no controlado en %s %s:\n%s", request.method, request.url.path, traceback.format_exc())
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor. Por favor, inténtalo de nuevo más tarde."},
    )

# Registrar routers
app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(restaurantes.router) 
app.include_router(categorias.router)
app.include_router(productos.router)
app.include_router(pedidos.router)
app.include_router(mesas.router)
app.include_router(reservas.router)
app.include_router(ingredientes.router)
app.include_router(pagos.router)

from tickets import router as tickets_router
app.include_router(tickets_router)

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