# ============================================================================
# backend/audit_general.py
# ----------------------------------------------------------------------------
# Auditoría GENERAL de acciones (login, gestión de usuarios, cupones, etc.).
#
# Se usa como `auditoria.registrar(...)` desde cualquier ruta para dejar
# rastro de QUIÉN hizo QUÉ y CUÁNDO. Esencial para:
#   - Soporte: "¿cuándo cambió el rol de este usuario?".
#   - Forense: rastrear actividad sospechosa.
#   - RGPD: justificar accesos a datos personales.
#
# La auditoría de PAGOS vive en otro fichero (`audit.py`) por tener un
# esquema y políticas distintas.
#
# Diseño "fire-and-forget" igual que en audit.py: si falla, sólo se logea
# el error y se sigue. No queremos que una caída de Mongo bloquee un login.
# ============================================================================
"""
Auditoría general de acciones de usuario y sistema.
Uso: registrar(accion, detalle, actor, objetivo)  — fire-and-forget, nunca lanza excepciones.
"""
import logging
from datetime import datetime, timezone
from database import coleccion_auditoria

logger = logging.getLogger("uvicorn")

# --- Categorías de eventos --------------------------------------------------
# Constantes en lugar de strings sueltos por todo el código:
#   - El IDE autocompleta y avisa de typos.
#   - Refactorizar el nombre se hace en un solo sitio.
#   - Sirve de "inventario" rápido de qué se audita.
USUARIO_CREADO      = "usuario.creado"
USUARIO_ELIMINADO   = "usuario.eliminado"
USUARIO_SUSPENDIDO  = "usuario.suspendido"
USUARIO_REACTIVADO  = "usuario.reactivado"
USUARIO_EDITADO     = "usuario.editado"
ROL_CAMBIADO        = "usuario.rol_cambiado"
ESTADO_CAMBIADO     = "usuario.estado_cambiado"
LOGIN_OK            = "auth.login_ok"
LOGIN_FALLIDO       = "auth.login_fallido"
RESTAURANTE_CREADO  = "restaurante.creado"
RESTAURANTE_EDITADO = "restaurante.editado"
RESERVA_ESTADO_CAMBIADO = "reserva.estado_cambiado"
RESERVA_MESA_ASIGNADA   = "reserva.mesa_asignada"
CUPON_CREADO        = "cupon.creado"
CUPON_EDITADO       = "cupon.editado"
CUPON_ELIMINADO     = "cupon.eliminado"
CUPON_ENVIADO_MASIVO = "cupon.enviado_masivo"
CIERRE_REABIERTO        = "cierre_caja.reabierto"
RESTAURANTE_SUSPENDIDO  = "restaurante.suspendido"
RESTAURANTE_REACTIVADO  = "restaurante.reactivado"
PEDIDO_CREADO           = "pedido.creado"
PEDIDO_COBRADO_MANUAL   = "pedido.cobrado_manual"
PEDIDO_CANCELADO        = "pedido.cancelado"
MESA_ESTADO_CAMBIADO    = "mesa.estado_cambiado"
INGREDIENTE_PUESTO_A_CERO = "ingrediente.puesto_a_cero"


def registrar(
    accion: str,
    *,                       # el `*` fuerza que el resto sean kwargs (más legible).
    actor: str | None = None,
    objetivo: str | None = None,
    detalle: str | None = None,
    extra: dict | None = None,
) -> None:
    """Inserta un evento de auditoría. Fire-and-forget.

    Parámetros:
        accion: usa una de las constantes (USUARIO_CREADO, LOGIN_OK...).
        actor:  quién hizo la acción (email o id del usuario logueado).
        objetivo: a quién/qué afecta (id del recurso modificado).
        detalle: texto libre con contexto adicional.
        extra:  dict opcional que se "spread"-ea en el doc. Útil cuando un
                evento concreto necesita más campos sin tocar el esquema.

    Ejemplo:
        registrar(
            ROL_CAMBIADO,
            actor=correo_admin,
            objetivo=str(user_id),
            detalle=f"de {rol_antes} a {rol_nuevo}",
        )
    """
    try:
        # Construimos el documento. Solo añadimos las claves con valor para
        # que la colección quede limpia (sin campos None ocupando espacio).
        doc: dict = {
            "fecha": datetime.now(timezone.utc).isoformat(),
            "accion": accion,
        }
        if actor:   doc["actor"]   = actor
        if objetivo: doc["objetivo"] = objetivo
        if detalle:  doc["detalle"]  = detalle
        if extra:    doc.update(extra)
        coleccion_auditoria.insert_one(doc)
    except Exception as exc:
        # Nunca propagamos: auditoría no debe romper el flujo principal.
        logger.error("Error registrando auditoría [%s]: %s", accion, exc)
