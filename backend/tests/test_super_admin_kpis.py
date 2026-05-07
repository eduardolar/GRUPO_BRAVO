"""Tests del endpoint GET /api/v1/super-admin/kpis-hoy."""
from datetime import datetime, timezone

from bson import ObjectId
from security import crear_token


# ── Helpers de tokens ─────────────────────────────────────────────────────────

def _tok_super() -> dict:
    token = crear_token({"sub": "super_id", "correo": "super@bravo.com", "rol": "super_admin"})
    return {"Authorization": f"Bearer {token}"}


def _tok_admin(rid: str = "R1") -> dict:
    token = crear_token({
        "sub": "admin_id",
        "correo": "admin@r1.com",
        "rol": "admin",
        "restaurante_id": rid,
    })
    return {"Authorization": f"Bearer {token}"}


# ── Helpers BD ────────────────────────────────────────────────────────────────

def _insertar_restaurante(nombre: str = "Bravo Test") -> str:
    from database import coleccion_restaurantes
    res = coleccion_restaurantes.insert_one({
        "nombre": nombre,
        "direccion": "Calle Test 1",
        "codigo": "TST01",
        "activo": True,
    })
    return str(res.inserted_id)


def _insertar_pedido(restaurante_id: str, estado: str = "listo", total: float = 20.0) -> str:
    from database import coleccion_pedidos
    hoy = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    res = coleccion_pedidos.insert_one({
        "restaurante_id": restaurante_id,
        "estado": estado,
        "total": total,
        "fecha": f"{hoy}T12:00:00",
        "items": [{"cantidad": 2, "producto_id": "pid", "precio": 10.0}],
        "metodo_pago": "efectivo",
    })
    return str(res.inserted_id)


def _insertar_reserva_hoy(restaurante_id: str) -> str:
    from database import coleccion_reservas
    hoy = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    res = coleccion_reservas.insert_one({
        "restaurante_id": restaurante_id,
        "fecha": hoy,
        "hora": "13:00",
        "comensales": 2,
        "estado": "Confirmada",
        "usuario_id": "u1",
    })
    return str(res.inserted_id)


def _insertar_cierre_abierto(restaurante_id: str) -> str:
    from database import coleccion_cierres_caja
    hoy = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    res = coleccion_cierres_caja.insert_one({
        "restaurante_id": restaurante_id,
        "turno": "comida",
        "fecha": hoy,
        "estado": "abierto",
        "abierto_at": datetime.now(timezone.utc).isoformat(),
    })
    return str(res.inserted_id)


# ── Tests ─────────────────────────────────────────────────────────────────────

def test_kpis_hoy_solo_super_admin_403_para_admin(client):
    """Un admin recibe 403; el endpoint exige super_admin."""
    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_admin("R1"))
    assert resp.status_code == 403


def test_kpis_hoy_solo_super_admin_401_sin_token(client):
    """Sin token se recibe 401."""
    resp = client.get("/api/v1/super-admin/kpis-hoy")
    assert resp.status_code == 401


def test_kpis_hoy_super_admin_200(client):
    """super_admin recibe 200."""
    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_super())
    assert resp.status_code == 200, resp.json()


def test_kpis_hoy_devuelve_estructura_completa(client):
    """La respuesta contiene todas las claves esperadas con tipos correctos."""
    _insertar_restaurante("Bravo Centro")

    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_super())
    assert resp.status_code == 200, resp.json()
    data = resp.json()

    # Clave raíz
    assert "fecha" in data
    assert "totales" in data
    assert "por_sucursal" in data

    # Claves de totales
    totales = data["totales"]
    claves_esperadas = {
        "ingresos_hoy", "pedidos_hoy", "ticket_medio", "items_vendidos",
        "pedidos_en_cocina", "reservas_hoy", "stock_bajo_total",
        "cierres_pendientes", "sucursales_abiertas", "sucursales_total",
    }
    for clave in claves_esperadas:
        assert clave in totales, f"Falta la clave: {clave}"

    # Tipos numéricos
    assert isinstance(totales["ingresos_hoy"], (int, float))
    assert isinstance(totales["pedidos_hoy"], int)
    assert isinstance(totales["ticket_medio"], (int, float))
    assert isinstance(totales["sucursales_total"], int)

    # Fecha tiene formato correcto
    from datetime import date
    date.fromisoformat(data["fecha"])  # lanza ValueError si no es YYYY-MM-DD


def test_kpis_hoy_agrega_por_sucursal(client):
    """Con 3 sucursales, por_sucursal tiene exactamente 3 entradas."""
    r1 = _insertar_restaurante("Bravo Norte")
    r2 = _insertar_restaurante("Bravo Sur")
    r3 = _insertar_restaurante("Bravo Este")

    # Insertar un pedido en r1 para que tenga ingresos
    _insertar_pedido(r1, estado="listo", total=50.0)

    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_super())
    assert resp.status_code == 200, resp.json()
    data = resp.json()

    por_sucursal = data["por_sucursal"]
    assert len(por_sucursal) == 3, f"Esperadas 3 sucursales, obtenidas {len(por_sucursal)}"

    # Verificar estructura de cada entrada
    for entrada in por_sucursal:
        assert "restaurante_id" in entrada
        assert "nombre" in entrada
        assert "ingresos_hoy" in entrada
        assert "pedidos_hoy" in entrada
        assert "pedidos_en_cocina" in entrada
        assert "abierta" in entrada
        assert isinstance(entrada["abierta"], bool)

    # Verificar que r1 acumula el pedido insertado
    ids_en_respuesta = {e["restaurante_id"] for e in por_sucursal}
    assert r1 in ids_en_respuesta


def test_kpis_hoy_cuenta_reservas_hoy(client):
    """El campo reservas_hoy refleja solo las reservas del día actual."""
    r1 = _insertar_restaurante("Bravo Reservas")
    _insertar_reserva_hoy(r1)
    _insertar_reserva_hoy(r1)

    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_super())
    assert resp.status_code == 200
    assert resp.json()["totales"]["reservas_hoy"] == 2


def test_kpis_hoy_sucursales_abiertas_con_cierre(client):
    """Una sucursal con cierre abierto hoy se cuenta como abierta."""
    r1 = _insertar_restaurante("Bravo Abierta")
    _insertar_cierre_abierto(r1)

    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_super())
    assert resp.status_code == 200
    totales = resp.json()["totales"]
    assert totales["sucursales_abiertas"] >= 1
    assert totales["cierres_pendientes"] >= 1

    # La sucursal debe aparecer como abierta en por_sucursal
    por_sucursal = resp.json()["por_sucursal"]
    entry = next((e for e in por_sucursal if e["restaurante_id"] == r1), None)
    assert entry is not None
    assert entry["abierta"] is True


def test_kpis_hoy_ticket_medio_cero_sin_ventas(client):
    """Si no hay pedidos en estado venta, ticket_medio debe ser 0."""
    _insertar_restaurante("Bravo Vacío")
    resp = client.get("/api/v1/super-admin/kpis-hoy", headers=_tok_super())
    assert resp.status_code == 200
    assert resp.json()["totales"]["ticket_medio"] == 0.0
