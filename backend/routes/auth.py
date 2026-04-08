from fastapi import APIRouter, HTTPException
import bcrypt
from database import coleccion_usuarios
from models import UsuarioRegistro, UsuarioLogin

router = APIRouter()

@router.post("/registro")
def registrar_usuario(usuario: UsuarioRegistro):
    try:
        if coleccion_usuarios.find_one({"correo": usuario.correo}):
            raise HTTPException(status_code=400, detail="El correo ya está registrado")

        password_bytes = usuario.password_hash.encode('utf-8')
        salt = bcrypt.gensalt()
        hashed_password = bcrypt.hashpw(password_bytes, salt)

        usuario_dict = usuario.dict()
        usuario_dict["password_hash"] = hashed_password.decode('utf-8')

        resultado = coleccion_usuarios.insert_one(usuario_dict)
        return {"mensaje": "Usuario creado correctamente", "id": str(resultado.inserted_id)}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/login")
def iniciar_sesion(credenciales: UsuarioLogin):
    usuario_db = coleccion_usuarios.find_one({"correo": credenciales.correo})

    if usuario_db:
        password_escrita = credenciales.password_hash.encode('utf-8')
        hash_almacenado = usuario_db["password_hash"].encode('utf-8')

        if bcrypt.checkpw(password_escrita, hash_almacenado):
            return {
                "id": str(usuario_db["_id"]),
                "nombre": usuario_db["nombre"],
                "correo": usuario_db["correo"],
                "telefono": usuario_db.get("telefono", ""),
                "direccion": usuario_db.get("direccion", ""),
                "rol": usuario_db.get("rol", "cliente"),
            }

    raise HTTPException(status_code=401, detail="Credenciales incorrectas")
