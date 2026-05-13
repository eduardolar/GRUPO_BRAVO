# ============================================================================
# backend/limiter.py
# ----------------------------------------------------------------------------
# Instancia global del rate limiter (slowapi).
#
# `Limiter` es el objeto que aplica los límites declarados con
# `@limiter.limit("5/minute")` en los routers (p. ej. `routes/auth.py` lo
# usa para frenar ataques de fuerza bruta en /login).
#
# `key_func=get_remote_address` significa que el límite es POR IP del cliente.
# Si quisiéramos limitar por usuario autenticado en su lugar (más justo si
# muchos clientes comparten IP, p. ej. NAT corporativo), usaríamos una
# función custom que leyera el JWT del header Authorization.
#
# Esta instancia se conecta a la app en `main.py`:
#     app.state.limiter = limiter
#     app.add_middleware(SlowAPIMiddleware)
# ============================================================================
from slowapi import Limiter
from slowapi.util import get_remote_address

# Singleton compartido: TODOS los routers importan este `limiter` para que
# los contadores sean coherentes (si cada router creara el suyo, los
# límites se aplicarían por router, no globales).
limiter = Limiter(key_func=get_remote_address)
