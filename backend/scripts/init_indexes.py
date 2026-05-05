"""Crea los índices recomendados en MongoDB.

Ejecutar UNA sola vez tras desplegar (es idempotente: `create_index` con
el mismo nombre no falla, sólo verifica). Útil antes de un go-live para
evitar full collection scans.

Uso:
    cd backend && python -m scripts.init_indexes
"""
from __future__ import annotations

import sys
from pathlib import Path

# Permite ejecutar el script con `python scripts/init_indexes.py`
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pymongo import ASCENDING, DESCENDING

import config  # noqa: F401  carga .env
from database import (
    coleccion_usuarios,
    coleccion_pedidos,
    coleccion_mesas,
    coleccion_reservas,
    coleccion_productos,
    coleccion_categorias,
    coleccion_ingredientes,
    coleccion_cupones,
    coleccion_auditoria,
    coleccion_auditoria_pagos,
)


def crear_indices() -> None:
    # USUARIOS
    coleccion_usuarios.create_index([("correo", ASCENDING)], unique=True, name="ux_correo")
    coleccion_usuarios.create_index([("rol", ASCENDING)], name="ix_rol")
    coleccion_usuarios.create_index([("restaurante_id", ASCENDING)], name="ix_restaurante")

    # PEDIDOS — consultas habituales: por usuario, por restaurante + estado + fecha
    coleccion_pedidos.create_index([("user_id", ASCENDING), ("fecha", DESCENDING)], name="ix_user_fecha")
    coleccion_pedidos.create_index(
        [("restaurante_id", ASCENDING), ("estado", ASCENDING), ("fecha", DESCENDING)],
        name="ix_restaurante_estado_fecha",
    )
    coleccion_pedidos.create_index([("estado_pago", ASCENDING)], name="ix_estado_pago")
    coleccion_pedidos.create_index(
        [("stripe_payment_intent_id", ASCENDING)],
        name="ix_stripe_intent",
        sparse=True,
    )

    # MESAS — el QR debe ser único globalmente; estado para filtrar libres/ocupadas
    coleccion_mesas.create_index([("codigo_qr", ASCENDING)], unique=True, sparse=True, name="ux_codigo_qr")
    coleccion_mesas.create_index(
        [("restaurante_id", ASCENDING), ("estado", ASCENDING)],
        name="ix_mesas_restaurante_estado",
    )

    # RESERVAS — por restaurante y por fecha
    coleccion_reservas.create_index(
        [("restaurante_id", ASCENDING), ("fecha", ASCENDING)],
        name="ix_reservas_restaurante_fecha",
    )
    coleccion_reservas.create_index([("user_id", ASCENDING)], name="ix_reservas_user")

    # PRODUCTOS / CATEGORÍAS — por restaurante y por categoría
    coleccion_productos.create_index(
        [("restaurante_id", ASCENDING), ("categoria", ASCENDING)],
        name="ix_productos_restaurante_categoria",
    )
    coleccion_categorias.create_index([("restaurante_id", ASCENDING), ("nombre", ASCENDING)],
                                      name="ix_categorias_restaurante_nombre")

    # INGREDIENTES — por restaurante y para detectar bajo stock
    coleccion_ingredientes.create_index([("restaurante_id", ASCENDING)], name="ix_ingredientes_restaurante")
    coleccion_ingredientes.create_index([("nombre", ASCENDING)], name="ix_ingredientes_nombre")

    # CUPONES — código único, búsquedas activas
    coleccion_cupones.create_index([("codigo", ASCENDING)], unique=True, name="ux_codigo_cupon")
    coleccion_cupones.create_index([("activo", ASCENDING)], name="ix_cupones_activo")

    # AUDITORÍA — consultas más recientes primero
    coleccion_auditoria.create_index([("fecha", DESCENDING)], name="ix_auditoria_fecha")
    coleccion_auditoria.create_index([("accion", ASCENDING)], name="ix_auditoria_accion")
    coleccion_auditoria_pagos.create_index([("fecha", DESCENDING)], name="ix_auditoria_pagos_fecha")
    coleccion_auditoria_pagos.create_index(
        [("proveedor", ASCENDING), ("estado", ASCENDING)],
        name="ix_auditoria_pagos_proveedor_estado",
    )

    print("Índices creados/verificados correctamente.")


if __name__ == "__main__":
    crear_indices()
