"""Resetea el estado operativo de la BBDD dev para pruebas.

Acciones (idempotentes):
  1. Borra pedidos no terminados (pendiente, preparando, listo) y entregados
     sin pagar. Mantiene los cancelados y entregados+pagados (históricos).
  2. Borra pedidos huérfanos: tipo_entrega='local' sin mesa_id o sin
     numero_mesa.
  3. Libera mesas "zombie": mesas en estado `ocupada` que no tengan ningún
     pedido activo asignado. Se quedan así cuando un pedido se canceló /
     limpió antes del fix que libera la mesa.

NO toca usuarios, restaurantes, productos, categorías ni reservas.

Uso:
    cd backend && python -m scripts.limpiar_pruebas
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import config  # noqa: F401  carga .env
from database import coleccion_mesas, coleccion_pedidos


def main() -> None:
    # ── Antes ─────────────────────────────────────────────────────
    mesas_no_libres = coleccion_mesas.count_documents({"estado": {"$ne": "libre"}})
    pedidos_total = coleccion_pedidos.count_documents({})
    pedidos_por_estado: dict[str, int] = {}
    for doc in coleccion_pedidos.aggregate([
        {"$group": {"_id": "$estado", "n": {"$sum": 1}}},
    ]):
        pedidos_por_estado[doc.get("_id") or "(null)"] = doc["n"]

    print("== ANTES ==")
    print(f"  Mesas no-libres: {mesas_no_libres}")
    print(f"  Pedidos totales: {pedidos_total}")
    for estado, n in sorted(pedidos_por_estado.items()):
        print(f"    - {estado}: {n}")

    # ── 1. Borrar pedidos incompletos (en curso o entregado sin pagar) ─
    estados_activos = ["pendiente", "preparando", "listo"]
    res_pedidos = coleccion_pedidos.delete_many({
        "$or": [
            {"estado": {"$in": estados_activos}},
            {"$and": [
                {"estado": "entregado"},
                {"$or": [
                    {"estado_pago": {"$ne": "pagado"}},
                    {"estado_pago": {"$exists": False}},
                ]},
            ]},
        ]
    })

    # ── 2. Borrar pedidos local huérfanos (sin mesa válida) ────────
    res_huerfanos = coleccion_pedidos.delete_many({
        "tipo_entrega": "local",
        "$or": [
            {"mesa_id": None},
            {"mesa_id": {"$exists": False}},
            {"numero_mesa": None},
            {"numero_mesa": {"$exists": False}},
        ],
    })

    # ── 3. Liberar mesas zombie (ocupadas sin pedido activo) ─────────
    no_libres = list(coleccion_mesas.find({"estado": "ocupada"}))
    mesas_con_pedido_activo: set[str] = set()
    for p in coleccion_pedidos.find({
        "estado": {"$in": ["pendiente", "preparando", "listo"]},
        "mesa_id": {"$ne": None},
    }):
        mid = p.get("mesa_id")
        if mid:
            mesas_con_pedido_activo.add(str(mid))

    zombies = [
        m["_id"] for m in no_libres
        if str(m["_id"]) not in mesas_con_pedido_activo
    ]
    if zombies:
        coleccion_mesas.update_many(
            {"_id": {"$in": zombies}},
            {"$set": {"estado": "libre"}},
        )

    # ── Después ───────────────────────────────────────────────────
    print("\n== DESPUÉS ==")
    print(f"  Pedidos borrados (incompletos): {res_pedidos.deleted_count}")
    print(f"  Pedidos borrados (huérfanos):   {res_huerfanos.deleted_count}")
    print(f"  Mesas zombie liberadas:         {len(zombies)}")
    print(
        f"  Pedidos restantes: "
        f"{coleccion_pedidos.count_documents({})}"
    )
    print(
        f"  Mesas no-libres restantes: "
        f"{coleccion_mesas.count_documents({'estado': {'$ne': 'libre'}})}"
    )


if __name__ == "__main__":
    main()
