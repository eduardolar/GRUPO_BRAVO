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

_REDACT = "[REDACTED]"

_PATTERNS: tuple[tuple[Pattern[str], str], ...] = (
    # Tarjeta de crédito (12-19 dígitos con o sin separadores). Acepta sólo
    # secuencias largas de dígitos: deja en paz timestamps y otros números.
    (re.compile(r"\b(?:\d[ -]*?){13,19}\b"), _REDACT),
    # CVV cuando aparece etiquetado
    (re.compile(r"(?i)(cvv|cvc|cvv2)[\"']?\s*[:=]\s*[\"']?\d{3,4}[\"']?"), r"\1=" + _REDACT),
    # client_secret de Stripe (`pi_..._secret_...`, `seti_..._secret_...`, …)
    (re.compile(r"\b(?:pi|seti|src|cs|cus|sub)_[A-Za-z0-9]+_secret_[A-Za-z0-9]+\b"), _REDACT),
    # Bearer JWT
    (re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._\-]+\.[A-Za-z0-9._\-]+\.[A-Za-z0-9._\-]+"), "Bearer " + _REDACT),
    # Authorization header genérica
    (re.compile(r'(?i)("?authorization"?\s*[:=]\s*"?)[^"\s,}]+'), r"\1" + _REDACT),
    # password en cualquier kv pair
    (re.compile(r'(?i)("?(?:password|contrase[ñn]a|password_hash)"?\s*[:=]\s*"?)[^"\s,}]+'),
     r"\1" + _REDACT),
    # api_key / secret_key
    (re.compile(r"(?i)\b(sk|rk|whsec|pk_live)_[A-Za-z0-9]+"), _REDACT),
)


class RedactingFilter(logging.Filter):
    """Filtra el mensaje y los args del LogRecord aplicando los patrones.

    Mantenemos la lista corta y específica para no penalizar el rendimiento
    del logging en caliente.
    """

    def filter(self, record: logging.LogRecord) -> bool:  # type: ignore[override]
        try:
            if isinstance(record.msg, str):
                record.msg = self._redact(record.msg)
            if record.args:
                record.args = tuple(
                    self._redact(a) if isinstance(a, str) else a
                    for a in record.args
                )
        except Exception:
            # nunca dejes que el filtro rompa el logging
            pass
        return True

    @staticmethod
    def _redact(text: str) -> str:
        for pattern, repl in _PATTERNS:
            text = pattern.sub(repl, text)
        return text


def install(*loggers: str) -> None:
    """Instala el filtro en los loggers indicados (y en el raíz)."""
    f = RedactingFilter()
    logging.getLogger().addFilter(f)
    for name in loggers:
        logging.getLogger(name).addFilter(f)
