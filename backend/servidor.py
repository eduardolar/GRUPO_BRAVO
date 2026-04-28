# COMPATIBILIDAD LEGADA: expone la app desde main.py
#
# Este archivo se mantiene solo para que comandos antiguos como
#   py -m uvicorn servidor:app --reload
# sigan funcionando.
#
# Todo el desarrollo nuevo debe usar:
#   py -m uvicorn main:app --reload

from main import app  # noqa: F401
