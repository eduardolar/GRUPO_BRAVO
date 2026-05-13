"""
Migración: alinear el $jsonSchema de `mesas` con el modelo actual.

ESTADOS PERMITIDOS
==================
Tras eliminar el flujo intermedio "por_limpiar", el modelo de mesa vuelve
a ser binario:
    - libre     -> disponible para nuevos clientes
    - ocupada   -> con pedido en curso
    - reservada -> bloqueada por una reserva

Si en producción quedan documentos con `estado='por_limpiar'` (legacy del
flujo anterior) los normalizamos a `libre` ANTES de aplicar el validator
nuevo para evitar `WriteError 121` al primer update que los toque.

USO
===
    cd backend && python ../scripts/fix_validator_mesas.py

Idempotente.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "backend"))

from database import db, coleccion_mesas  # noqa: E402


VALIDATOR = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["numero", "capacidad", "estado"],
        "properties": {
            "numero":    {"bsonType": "int", "minimum": 1},
            "capacidad": {"bsonType": "int", "minimum": 1},
            "estado": {
                "bsonType": "string",
                "enum": ["libre", "ocupada", "reservada"],
            },
            "codigoQr": {"bsonType": "string"},
        },
    }
}


def main() -> int:
    info = db.command("listCollections", filter={"name": "mesas"})
    batch = info["cursor"]["firstBatch"]
    if not batch:
        print("La colección 'mesas' no existe. Salgo sin tocar nada.")
        return 0

    # 1) Normalizar documentos legacy antes de endurecer el validator.
    n_legacy = coleccion_mesas.count_documents({"estado": "por_limpiar"})
    if n_legacy:
        res = coleccion_mesas.update_many(
            {"estado": "por_limpiar"},
            {"$set": {"estado": "libre"}},
        )
        print(f"Normalizadas {res.modified_count} mesas 'por_limpiar' -> 'libre'")
    else:
        print("Sin mesas legacy en estado 'por_limpiar'.")

    # 2) Comprobar si el validator ya está alineado.
    actual = batch[0].get("options", {}).get("validator", {})
    enum_actual = (
        actual.get("$jsonSchema", {})
        .get("properties", {})
        .get("estado", {})
        .get("enum", [])
    )
    objetivo = VALIDATOR["$jsonSchema"]["properties"]["estado"]["enum"]
    if sorted(enum_actual) == sorted(objetivo):
        print("Validator ya alineado. Nada que hacer.")
        return 0

    print(f"Enum actual: {enum_actual} -> objetivo: {objetivo}")
    res = db.command("collMod", "mesas", validator=VALIDATOR)
    print("collMod mesas ok =", res.get("ok"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
