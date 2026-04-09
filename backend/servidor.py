from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pymongo import MongoClient
import bcrypt

# Conexión a MongoDB Atlas
MONGO_URI = "mongodb+srv://dam_grupo_bravo:cduEJRiDSc99ErTG@cluster0.wdmtidw.mongodb.net/?appName=Cluster0"
cliente = MongoClient(MONGO_URI)
db = cliente['comandas_db']
coleccion_usuarios = db['usuarios']

app = FastAPI(title="API Restaurante Bravo")

# Configuración de CORS para permitir solicitudes desde el frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelos de datos para registro y login
class UsuarioRegistro(BaseModel):
    nombre: str
    password_hash: str
    correo: str
    telefono: str
    direccion: str
    rol: str = "cliente"

class UsuarioLogin(BaseModel):
    correo: str  
    password_hash: str

# Ruta para registrar un nuevo usuario
@app.post("/registro")
def registrar_usuario(usuario: UsuarioRegistro):
    try:
        # Verificamos si el correo ya existe para no duplicar
        if coleccion_usuarios.find_one({"correo": usuario.correo}):
            raise HTTPException(status_code=400, detail="El correo ya está registrado")
        
        # Hashear la contraseña con bcrypt
        password_bytes = usuario.password_hash.encode('utf-8')
        salt = bcrypt.gensalt()
        hashed_password = bcrypt.hashpw(password_bytes, salt)

        usuario_dict = usuario.dict()
        usuario_dict["password_hash"] = hashed_password.decode('utf-8')

        resultado = coleccion_usuarios.insert_one(usuario_dict)
        return {"mensaje": "Usuario creado correctamente", "id": str(resultado.inserted_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Ruta para iniciar sesión
@app.post("/login")
def iniciar_sesion(credenciales: UsuarioLogin):
    usuario = coleccion_usuarios.find_one({"correo": credenciales.correo})
    if usuario:
        password_escrita = credenciales.password_hash.encode('utf-8')
        hash_almacenado = usuario["password_hash"].encode('utf-8')
        if bcrypt.checkpw(password_escrita, hash_almacenado):
            return {"mensaje": "Login exitoso", "nombre": usuario["nombre"]}
    raise HTTPException(status_code=401, detail="Credenciales incorrectas")

@app.get("/")
def inicio():
    return {"status": "Servidor funcionando"}