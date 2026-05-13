# ============================================================================
# backend/servidor.py
# ----------------------------------------------------------------------------
# Shim de compatibilidad: solo re-exporta `app` desde `main.py`.
#
# ¿Por qué existe? Algunos comandos antiguos del proyecto y de la docu
# referenciaban el módulo como `servidor:app`. Para no romper esos comandos
# (CI, scripts, ejemplos del README viejos), mantenemos este archivo que
# simplemente importa `app`.
#
# Cualquier desarrollo nuevo DEBE usar `main:app` directamente.
# Cuando ya no quede ningún script apuntando a `servidor`, este archivo se
# puede borrar sin riesgo.
# ============================================================================
# COMPATIBILIDAD LEGADA: expone la app desde main.py
#
# Este archivo se mantiene solo para que comandos antiguos como
#   py -m uvicorn servidor:app --reload
# sigan funcionando.
#
# Todo el desarrollo nuevo debe usar:
#   py -m uvicorn main:app --reload

from main import app  # noqa: F401
