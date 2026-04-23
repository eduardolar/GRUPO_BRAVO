# ARCHIVO DEPRECADO — ELIMINAR
#
# Este archivo es una versión antigua de main.py que duplica las rutas /registro y /login
# sin validación de contraseña ni verificación por correo.
#
# Toda la lógica ha sido consolidada en:
#   - backend/main.py          (configuración de la app FastAPI)
#   - backend/routes/auth.py   (endpoints /registro y /login)
#
# Acción requerida: eliminar este archivo del repositorio.
#   git rm backend/servidor.py

raise ImportError(
    "servidor.py está deprecado. Usa main.py como punto de entrada del backend."
)
