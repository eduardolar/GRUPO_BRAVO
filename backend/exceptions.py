# ============================================================================
# backend/exceptions.py
# ----------------------------------------------------------------------------
# Jerarquía de excepciones de dominio.
#
# La idea: en lugar de lanzar `HTTPException(status_code=409, detail="...")`
# directamente desde los servicios y los routers, lanzamos excepciones con
# semántica de negocio (NotFoundError, ConflictError, ValidacionError...).
# Después un único `exception_handler` en `main.py` las convierte al
# `JSONResponse` correspondiente.
#
# Ventajas:
#   - Los servicios no dependen de FastAPI (más testeables, reutilizables).
#   - El status_code vive con la clase, no se repite en cada `raise`.
#   - Si mañana cambias a otro framework, solo tocas el handler.
#
# Ejemplo de uso:
#     if not pedido:
#         raise NotFoundError("Pedido no encontrado")
#     if pedido.estado == "pagado":
#         raise ConflictError("El pedido ya está pagado")
# ============================================================================


class AppError(Exception):
    """Base para todas las excepciones de dominio de la aplicación.

    Sirve como "marca" para que el `exception_handler` en main.py las
    capture en un único bloque y no se confundan con otras Exception.
    """
    # Código HTTP por defecto. Las subclases lo sobreescriben con el suyo.
    # Si alguien lanza un AppError "pelado" se devuelve 500 (bug del dev).
    status_code: int = 500

    def __init__(self, detail: str) -> None:
        # `detail` se serializa tal cual en la respuesta JSON:
        #     { "detail": "Pedido no encontrado" }
        # Por eso debe ser un mensaje legible para el usuario final.
        self.detail = detail
        super().__init__(detail)


class NotFoundError(AppError):
    """El recurso solicitado no existe → 404."""
    status_code = 404


class ConflictError(AppError):
    """El estado actual impide la operación (duplicado, stock insuficiente…) → 409.

    Casos típicos:
      - Email ya registrado al crear usuario.
      - Reservar una mesa que ya está ocupada en ese horario.
      - Modificar un pedido ya pagado.
    """
    status_code = 409


class ValidacionError(AppError):
    """El valor enviado no cumple las reglas de negocio → 422.

    Distinto de la `RequestValidationError` de Pydantic (que valida tipos
    y formato): aquí entran reglas de NEGOCIO (p. ej. "el descuento no
    puede superar el total del pedido").
    """
    status_code = 422


class AutenticacionError(AppError):
    """Credenciales inválidas o sesión no iniciada → 401."""
    status_code = 401


class AutorizacionError(AppError):
    """El usuario está autenticado pero no tiene permiso para esta acción → 403.

    Distinción importante:
      - 401 = "no sé quién eres" (sin login).
      - 403 = "sé quién eres, pero no puedes hacer esto" (sin rol).
    """
    status_code = 403
