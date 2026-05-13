# ============================================================================
# backend/log_redactor.py
# ----------------------------------------------------------------------------
# Filtro de logging que REDACTA datos sensibles antes de escribirlos.
#
# ¿Por qué? Los frameworks loggean mucho por defecto: cuerpo de la petición,
# headers, errores con tracebacks que contienen variables locales... Si un
# usuario manda su número de tarjeta o un Bearer token y eso acaba en un
# archivo de logs (o en stdout que va a un agregador externo), se incumple
# PCI-DSS (almacenamiento de PAN) y RGPD (datos personales).
#
# La solución: instalamos un `logging.Filter` en los loggers principales
# (uvicorn, fastapi, slowapi). El filtro se ejecuta ANTES de escribir cada
# registro y reemplaza los patrones sensibles por "[REDACTED]".
#
# Si necesitas cubrir un patrón nuevo, añádelo a `_PATTERNS` con una regex
# precisa (regexes demasiado amplias generan falsos positivos: por ejemplo,
# una regex de "13-19 dígitos" puede pisar timestamps largos).
# ============================================================================
"""Filtro de logging que redacta datos sensibles antes de escribirlos.

Cumple con el principio PCI-DSS de no escribir PAN, CVV ni `client_secret`
en los logs (uvicorn, slowapi, traceback). Se instala en `main.py` con
`add_filter` sobre el logger raíz y los principales loggers.

Si quieres cubrir otros patrones, añádelos a `_PATTERNS`.
"""
from __future__ import annotations

import logging
import re
from typing import Pattern, Tuple

# Texto que sustituye a la coincidencia. Centralizado para poder cambiarlo
# fácilmente (algunos prefieren "***" o "[redacted]" en minúsculas).
_REDACT = "[REDACTED]"

# Cada entrada es (regex, reemplazo). Se aplican EN ORDEN sobre el texto:
# si una regex captura un grupo (los `\1` del reemplazo), preservamos el
# nombre del campo y solo borramos el valor (más legible que un blob negro).
_PATTERNS: tuple[tuple[Pattern[str], str], ...] = (
    # Tarjeta de crédito (12-19 dígitos con o sin separadores). Acepta sólo
    # secuencias largas de dígitos: deja en paz timestamps y otros números.
    (re.compile(r"\b(?:\d[ -]*?){13,19}\b"), _REDACT),
    # CVV cuando aparece etiquetado. Sin etiqueta no se puede detectar
    # (un "123" suelto podría ser cualquier cosa), pero `"cvv":"123"` sí.
    (re.compile(r"(?i)(cvv|cvc|cvv2)[\"']?\s*[:=]\s*[\"']?\d{3,4}[\"']?"), r"\1=" + _REDACT),
    # client_secret de Stripe (`pi_..._secret_...`, `seti_..._secret_...`, …)
    # Estos secretos permiten confirmar pagos: filtrarlos compromete pagos
    # en curso, así que los matamos siempre.
    (re.compile(r"\b(?:pi|seti|src|cs|cus|sub)_[A-Za-z0-9]+_secret_[A-Za-z0-9]+\b"), _REDACT),
    # Bearer JWT: tres bloques base64 separados por puntos.
    (re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._\-]+\.[A-Za-z0-9._\-]+\.[A-Za-z0-9._\-]+"), "Bearer " + _REDACT),
    # Authorization header genérica (cualquier esquema, no solo Bearer).
    (re.compile(r'(?i)("?authorization"?\s*[:=]\s*"?)[^"\s,}]+'), r"\1" + _REDACT),
    # password en cualquier kv pair (acepta inglés y español).
    (re.compile(r'(?i)("?(?:password|contrase[ñn]a|password_hash)"?\s*[:=]\s*"?)[^"\s,}]+'),
     r"\1" + _REDACT),
    # api_key / secret_key (Stripe sk_..., rk_..., whsec_..., pk_live_...).
    (re.compile(r"(?i)\b(sk|rk|whsec|pk_live)_[A-Za-z0-9]+"), _REDACT),
)


class RedactingFilter(logging.Filter):
    """Filtra el mensaje y los args del LogRecord aplicando los patrones.

    Cómo funciona un `logging.Filter`:
        - El método `filter(record)` se invoca por cada log que sale.
        - Si devuelve True, el registro se procesa; si False, se descarta.
        - Podemos MUTAR `record.msg` y `record.args` antes de devolver True
          para alterar el mensaje final sin perder el log.

    Mantenemos la lista de patrones corta y específica para no penalizar
    el rendimiento del logging en caliente (el filtro se ejecuta MUCHAS
    veces en una API con tráfico).
    """

    def filter(self, record: logging.LogRecord) -> bool:  # type: ignore[override]
        try:
            # `record.msg` es la plantilla pasada al logger
            # (logger.info("user=%s", correo) → msg="user=%s", args=(correo,))
            if isinstance(record.msg, str):
                record.msg = self._redact(record.msg)
            # Los args también: a veces el dato sensible viene como arg.
            if record.args:
                record.args = tuple(
                    self._redact(a) if isinstance(a, str) else a
                    for a in record.args
                )
        except Exception:
            # Regla de oro del logging: si el filtro falla, NO interrumpas
            # el log original (sería peor perder el mensaje que loggearlo
            # con algún secreto residual; aun así, las regex son robustas).
            pass
        return True

    @staticmethod
    def _redact(text: str) -> str:
        """Aplica todos los patrones en orden y devuelve el texto saneado."""
        for pattern, repl in _PATTERNS:
            text = pattern.sub(repl, text)
        return text


def install(*loggers: str) -> None:
    """Instala el filtro en los loggers indicados (y en el raíz).

    Se llama desde `main.py` con los nombres de los loggers usados por
    nuestras dependencias. Pasar el filtro también al logger RAÍZ es
    cinturón + tirantes: cubre cualquier `logger.getLogger(...)` que
    aparezca en el futuro sin tener que recordar añadirlo aquí.
    """
    f = RedactingFilter()
    logging.getLogger().addFilter(f)
    for name in loggers:
        logging.getLogger(name).addFilter(f)
