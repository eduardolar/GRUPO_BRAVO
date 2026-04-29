class AppError(Exception):
    """Base para todas las excepciones de dominio de la aplicación."""
    status_code: int = 500

    def __init__(self, detail: str) -> None:
        self.detail = detail
        super().__init__(detail)


class NotFoundError(AppError):
    """El recurso solicitado no existe → 404."""
    status_code = 404


class ConflictError(AppError):
    """El estado actual impide la operación (duplicado, stock insuficiente…) → 409."""
    status_code = 409


class ValidacionError(AppError):
    """El valor enviado no cumple las reglas de negocio → 422."""
    status_code = 422


class AutenticacionError(AppError):
    """Credenciales inválidas o sesión no iniciada → 401."""
    status_code = 401


class AutorizacionError(AppError):
    """El usuario no tiene permiso para esta acción → 403."""
    status_code = 403
