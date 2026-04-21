from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from routes import auth, usuarios, categorias, productos, pedidos, mesas, reservas, ingredientes
import traceback
from routes import usuarios, restaurantes # archivo nuevo

app = FastAPI(title="API Restaurante Bravo")

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    traceback.print_exc()
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)},
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

@app.get("/")
def inicio():
    return {"status": "Servidor funcionando"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
