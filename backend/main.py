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

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelos de datos
class UsuarioRegistro(BaseModel):
    nombre: str
    password_hash: str  # Aquí llega la contraseña plana desde el frontend
    correo: str
    telefono: str
    direccion: str
    rol: str = "cliente"

class UsuarioLogin(BaseModel):
    correo: str  
    password_hash: str

# --- RUTAS ---

@app.post("/registro")
def registrar_usuario(usuario: UsuarioRegistro):
    try:
        # 1. Verificar si el correo ya existe
        if coleccion_usuarios.find_one({"correo": usuario.correo}):
            raise HTTPException(status_code=400, detail="El correo ya está registrado")
        
        # 2. PROCESO DE SEGURIDAD (Bcrypt)
        # Convertimos la contraseña que llega a bytes y le aplicamos el hash
        password_bytes = usuario.password_hash.encode('utf-8')
        salt = bcrypt.gensalt()
        hashed_password = bcrypt.hashpw(password_bytes, salt)

        # 3. Preparar el diccionario para MongoDB
        usuario_dict = usuario.dict()
        # Sobrescribimos la contraseña plana con el Hash seguro (en formato texto)
        usuario_dict["password_hash"] = hashed_password.decode('utf-8')

        # 4. Insertar en la base de datos
        resultado = coleccion_usuarios.insert_one(usuario_dict)
        return {"mensaje": "Usuario creado correctamente", "id": str(resultado.inserted_id)}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/login")
def iniciar_sesion(credenciales: UsuarioLogin):
    # 1. Buscar al usuario por correo
    usuario_db = coleccion_usuarios.find_one({"correo": credenciales.correo})
    
    if usuario_db:
        # 2. Verificar la contraseña usando bcrypt.checkpw
        # Comparamos la contraseña que escribe el usuario con el Hash de la DB
        password_escrita = credenciales.password_hash.encode('utf-8')
        hash_almacenado = usuario_db["password_hash"].encode('utf-8')

        if bcrypt.checkpw(password_escrita, hash_almacenado):
            return {"mensaje": "Login exitoso", "nombre": usuario_db["nombre"]}
    
    # Si no existe el usuario o la contraseña no coincide
    raise HTTPException(status_code=401, detail="Credenciales incorrectas")

@app.get("/")
def inicio():
    return {"status": "Servidor funcionando"}
