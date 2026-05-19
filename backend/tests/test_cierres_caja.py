"""Tests del módulo /api/v1/cierres-caja.

Cubre:
  - Abrir turno: 200, doc con estado abierto.
  - Abrir turno duplicado abierto → 409.
  - Abrir turno ya cerrado → 409.
  - Cerrar con pedidos abiertos → 409 con count.
  - Cerrar correctamente: calcula totales y descuadre.
  - Cerrar cierre ya cerrado → 409.
  - Reabrir con motivo < 10 chars → 422.
  - Reabrir cierre abierto → 409.
  - Listar filtra por fecha y turno.
  - Aislamiento: admin R1 no ve ni cierra cierres de R2.
  - super_admin con ?restaurante_id=R2 ve cierres de R2.
  - abierto-actual: con cierre abierto → 200; sin él → 404.
"""
from datetime import datetime, timezone, timedelta

from bson import ObjectId

from bson import ObjectId
from tests.tok_helpers import tok, insertar_usuario_test, TEST_OID_ADMIN

# OID extra para el admin de R2 (distinto al de R1 que usa TEST_OID_ADMIN)
_OID_ADMIN_R2 = ObjectId("bbbbbbbbbbbbbbbbbbbbbbbc")


# ─── Helpers de tokens ────────────────────────────────────────────────────────

def _tok_admin(rid: str = "R1") -> dict:
    if rid == "R2":
        return tok("admin", oid=_OID_ADMIN_R2, restaurante_id=rid)
    return tok("admin", restaurante_id=rid)


def _tok_super() -> dict:
    return tok("super_admin")


def _tok_camarero() -> dict:
    return tok("camarero", restaurante_id="R1")


# ─── Helpers BD ───────────────────────────────────────────────────────────────

def _insertar_cierre(
    rid: str = "R1",
    turno: str = "comida",
    fecha: str = "2025-05-01",
    estado: str = "abierto",
    totales: dict | None = None,
    efectivo_declarado: float | None = None,
    efectivo_sistema: float | None = None,
    descuadre: float | None = None,
) -> str:
    from database import coleccion_cierres_caja
    doc = {
        "restaurante_id": rid,
        "turno": turno,
        "fecha": fecha,
        "abierto_por": f"admin_{rid}",
        "abierto_at": "2025-05-01T12:00:00",
        "cerrado_por": None,
        "cerrado_at": None,
        "estado": estado,
        "efectivo_declarado": efectivo_declarado,
        "efectivo_sistema": efectivo_sistema,
        "descuadre": descuadre,
        "totales": totales,
        "reaperturas": [],
    }
    if estado == "cerrado":
        doc["cerrado_por"] = f"admin_{rid}"
        doc["cerrado_at"] = "2025-05-01T17:00:00"
    res = coleccion_cierres_caja.insert_one(doc)
    return str(res.inserted_id)


def _insertar_pedido(
    rid: str = "R1",
    estado: str = "listo",
    fecha: str = "2025-05-01T13:00:00",
    total: float = 20.0,
    metodo_pago: str = "efectivo",
) -> str:
    from database import coleccion_pedidos
    doc = {
        "restaurante_id": rid,
        "estado": estado,
        "fecha": fecha,
        "total": total,
        "metodo_pago": metodo_pago,
        "items": [],
    }
    res = coleccion_pedidos.insert_one(doc)
    return str(res.inserted_id)


# ─── Tests: abrir turno ───────────────────────────────────────────────────────

def test_abrir_turno_ok(client):
    """POST /abrir devuelve 200 y doc con estado=abierto."""
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "comida", "fecha": "2025-05-01"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["estado"] == "abierto"
    assert data["turno"] == "comida"
    assert data["fecha"] == "2025-05-01"
    assert data["restaurante_id"] == "R1"
    assert data["id"] is not None


def test_abrir_turno_campos_opcionales_default_hoy(client):
    """Sin fecha en el body se usa la fecha de hoy."""
    hoy = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "comida"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    assert resp.json()["fecha"] == hoy


def test_abrir_turno_invalido_devuelve_422(client):
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "medianoche"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 422


def test_abrir_turno_sin_token_devuelve_401(client):
    resp = client.post("/api/v1/cierres-caja/abrir", json={"turno": "comida"})
    assert resp.status_code == 401


def test_abrir_turno_rol_camarero_devuelve_403(client):
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "comida", "fecha": "2025-05-01"},
        headers=_tok_camarero(),
    )
    assert resp.status_code == 403


def test_abrir_turno_duplicado_abierto_devuelve_409(client):
    """Si ya hay un cierre abierto para esa sucursal+fecha+turno → 409."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "comida", "fecha": "2025-05-01"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 409
    assert "abierto" in resp.json()["detail"].lower()


def test_abrir_turno_ya_cerrado_devuelve_409(client):
    """Si ya existe un cierre cerrado para esa sucursal+fecha+turno → 409."""
    _insertar_cierre(rid="R1", turno="cena", fecha="2025-05-01", estado="cerrado")
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "cena", "fecha": "2025-05-01"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 409
    assert "cerrado" in resp.json()["detail"].lower()


def test_abrir_turno_otra_sucursal_no_afecta(client):
    """El cierre de R2 no bloquea abrir el mismo turno en R1."""
    _insertar_cierre(rid="R2", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.post(
        "/api/v1/cierres-caja/abrir",
        json={"turno": "comida", "fecha": "2025-05-01"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200


# ─── Tests: cerrar turno ──────────────────────────────────────────────────────

def test_cerrar_con_pedidos_abiertos_devuelve_409(client):
    """Si hay pedidos bloqueantes en el rango del turno → 409 con count."""
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    # Pedido pendiente en la franja 12:00-16:59
    _insertar_pedido(rid="R1", estado="pendiente", fecha="2025-05-01T13:30:00")
    _insertar_pedido(rid="R1", estado="preparando", fecha="2025-05-01T14:00:00")

    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 50.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 409, resp.json()
    detail = resp.json()["detail"]
    # El mensaje debe incluir el número de pedidos bloqueantes
    assert "2" in detail


def test_cerrar_correctamente_calcula_totales(client):
    """Cierre correcto: calcula totales, efectivo_sistema y descuadre.

    Los pedidos en estado 'entregado' no bloquean el cierre y cuentan en totales.
    Los pedidos en estado 'listo' bloquan (están listos pero sin entregar).
    """
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    # Usamos 'entregado' porque 'listo' bloquea el cierre según el spec
    _insertar_pedido(rid="R1", estado="entregado", fecha="2025-05-01T12:30:00", total=30.0, metodo_pago="efectivo")
    _insertar_pedido(rid="R1", estado="entregado", fecha="2025-05-01T13:00:00", total=20.0, metodo_pago="tarjeta")

    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 35.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["estado"] == "cerrado"
    totales = data["totales"]
    assert totales["ventas_total"] == 50.0
    assert totales["ventas_efectivo"] == 30.0
    assert totales["ventas_tarjeta"] == 20.0
    assert totales["ventas_otros"] == 0.0
    assert totales["pedidos_count"] == 2
    assert data["efectivo_sistema"] == 30.0
    # descuadre = declarado - sistema = 35 - 30 = 5
    assert data["descuadre"] == 5.0


def test_cerrar_sin_pedidos_totales_en_cero(client):
    """Sin pedidos de venta en el turno, los totales son cero y no bloquea."""
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-02", estado="abierto")

    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 0.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["totales"]["pedidos_count"] == 0
    assert data["totales"]["ventas_total"] == 0.0
    assert data["descuadre"] == 0.0


def test_cerrar_cierre_ya_cerrado_devuelve_409(client):
    """Intentar cerrar un cierre que ya está cerrado → 409."""
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="cerrado")
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 50.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 409


def test_cerrar_cierre_inexistente_devuelve_404(client):
    fake_id = str(ObjectId())
    resp = client.post(
        f"/api/v1/cierres-caja/{fake_id}/cerrar",
        json={"efectivo_declarado": 0.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 404


def test_cerrar_efectivo_negativo_devuelve_422(client):
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": -5.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 422


# ─── Tests: reabrir ───────────────────────────────────────────────────────────

def test_reabrir_con_motivo_corto_devuelve_422(client):
    """Motivo con menos de 10 caracteres → 422."""
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="cerrado")
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/reabrir",
        json={"motivo": "corto"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 422


def test_reabrir_cierre_abierto_devuelve_409(client):
    """Reabrir un cierre que ya está abierto → 409."""
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/reabrir",
        json={"motivo": "corrección de error en caja"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 409


def test_reabrir_cierre_cerrado_ok(client):
    """Reabrir un cierre cerrado → estado=abierto, entrada en reaperturas."""
    cierre_id = _insertar_cierre(
        rid="R1", turno="comida", fecha="2025-05-01", estado="cerrado",
        totales={"ventas_total": 100.0, "ventas_efectivo": 60.0,
                 "ventas_tarjeta": 40.0, "ventas_otros": 0.0, "pedidos_count": 3},
        efectivo_declarado=65.0, efectivo_sistema=60.0, descuadre=5.0,
    )
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/reabrir",
        json={"motivo": "Error en el conteo de efectivo del turno"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["estado"] == "abierto"
    # Los totales históricos deben conservarse
    assert data["totales"]["ventas_total"] == 100.0
    assert data["efectivo_declarado"] == 65.0
    # Debe haber una entrada en reaperturas
    assert len(data["reaperturas"]) == 1
    assert "Error en el conteo" in data["reaperturas"][0]["motivo"]


def test_reabrir_cierre_inexistente_devuelve_404(client):
    fake_id = str(ObjectId())
    resp = client.post(
        f"/api/v1/cierres-caja/{fake_id}/reabrir",
        json={"motivo": "motivo suficientemente largo"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 404


# ─── Tests: listar cierres ────────────────────────────────────────────────────

def test_listar_devuelve_solo_cierres_de_la_sucursal(client):
    """Admin de R1 solo ve los cierres de R1."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R2", turno="cena", fecha="2025-05-01", estado="cerrado")

    resp = client.get("/api/v1/cierres-caja", headers=_tok_admin("R1"))
    assert resp.status_code == 200, resp.json()
    rids = {d["restaurante_id"] for d in resp.json()}
    assert rids == {"R1"}, "Admin R1 no debe ver cierres de R2"


def test_listar_filtra_por_fecha(client):
    """?fecha=2025-05-01 devuelve solo cierres de ese día."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R1", turno="cena", fecha="2025-05-02", estado="abierto")

    resp = client.get("/api/v1/cierres-caja?fecha=2025-05-01", headers=_tok_admin("R1"))
    assert resp.status_code == 200
    fechas = {d["fecha"] for d in resp.json()}
    assert fechas == {"2025-05-01"}


def test_listar_filtra_por_turno(client):
    """?turno=comida devuelve solo cierres de ese turno."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R1", turno="cena", fecha="2025-05-01", estado="abierto")

    resp = client.get("/api/v1/cierres-caja?turno=comida", headers=_tok_admin("R1"))
    assert resp.status_code == 200
    turnos = {d["turno"] for d in resp.json()}
    assert turnos == {"comida"}


def test_listar_filtra_por_estado(client):
    """?estado=cerrado devuelve solo cierres cerrados."""
    _insertar_cierre(rid="R1", turno="cena", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="cerrado")

    resp = client.get("/api/v1/cierres-caja?estado=cerrado", headers=_tok_admin("R1"))
    assert resp.status_code == 200
    estados = {d["estado"] for d in resp.json()}
    assert estados == {"cerrado"}


def test_listar_rango_fechas(client):
    """?fecha_desde y ?fecha_hasta filtran el rango."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-04-30", estado="abierto")
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-03", estado="abierto")

    resp = client.get(
        "/api/v1/cierres-caja?fecha_desde=2025-05-01&fecha_hasta=2025-05-02",
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200
    fechas = {d["fecha"] for d in resp.json()}
    assert "2025-04-30" not in fechas
    assert "2025-05-01" in fechas
    assert "2025-05-03" not in fechas


def test_listar_estado_invalido_devuelve_422(client):
    resp = client.get("/api/v1/cierres-caja?estado=fantasma", headers=_tok_admin("R1"))
    assert resp.status_code == 422


def test_listar_sin_token_devuelve_401(client):
    resp = client.get("/api/v1/cierres-caja")
    assert resp.status_code == 401


# ─── Tests: aislamiento R1 no accede a R2 ────────────────────────────────────

def test_admin_r1_no_puede_cerrar_cierre_de_r2(client):
    """Admin de R1 no puede cerrar un cierre de R2 → 403."""
    cierre_id = _insertar_cierre(rid="R2", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 50.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403


def test_admin_r1_no_ve_cierre_de_r2_en_detalle(client):
    """GET /{id} por admin R1 de un cierre de R2 → 404 (aislamiento)."""
    cierre_id = _insertar_cierre(rid="R2", turno="cena", fecha="2025-05-01", estado="abierto")
    resp = client.get(f"/api/v1/cierres-caja/{cierre_id}", headers=_tok_admin("R1"))
    assert resp.status_code == 404


def test_admin_r1_no_puede_reabrir_cierre_de_r2(client):
    """Admin de R1 no puede reabrir un cierre de R2 → 403."""
    cierre_id = _insertar_cierre(rid="R2", turno="comida", fecha="2025-05-01", estado="cerrado")
    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/reabrir",
        json={"motivo": "intento de acceso no autorizado"},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 403


# ─── Tests: super_admin ve cierres de R2 ─────────────────────────────────────

def test_super_admin_lista_cierres_de_r2_con_filtro(client):
    """super_admin con ?restaurante_id=R2 ve los cierres de R2."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R2", turno="cena", fecha="2025-05-01", estado="cerrado")

    resp = client.get(
        "/api/v1/cierres-caja?restaurante_id=R2",
        headers=_tok_super(),
    )
    assert resp.status_code == 200
    rids = {d["restaurante_id"] for d in resp.json()}
    assert rids == {"R2"}, "super_admin filtrando por R2 debe ver solo R2"


def test_super_admin_ve_cierre_de_r2_en_detalle(client):
    """GET /{id} por super_admin de un cierre de R2 → 200."""
    cierre_id = _insertar_cierre(rid="R2", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.get(f"/api/v1/cierres-caja/{cierre_id}", headers=_tok_super())
    assert resp.status_code == 200
    assert resp.json()["restaurante_id"] == "R2"


def test_super_admin_lista_todos_sin_filtro(client):
    """super_admin sin ?restaurante_id ve todos los cierres."""
    _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    _insertar_cierre(rid="R2", turno="cena", fecha="2025-05-01", estado="cerrado")

    resp = client.get("/api/v1/cierres-caja", headers=_tok_super())
    assert resp.status_code == 200
    rids = {d["restaurante_id"] for d in resp.json()}
    assert "R1" in rids and "R2" in rids


# ─── Tests: abierto-actual ────────────────────────────────────────────────────

def test_abierto_actual_con_cierre_abierto_devuelve_200(client):
    """Si existe un cierre abierto de hoy para el turno → 200 con el doc."""
    hoy = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    _insertar_cierre(rid="R1", turno="comida", fecha=hoy, estado="abierto")

    resp = client.get(
        "/api/v1/cierres-caja/abierto-actual?turno=comida",
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()
    data = resp.json()
    assert data["estado"] == "abierto"
    assert data["turno"] == "comida"
    assert data["fecha"] == hoy


def test_abierto_actual_sin_cierre_abierto_devuelve_null(client):
    """Si no hay ningún cierre abierto de hoy → 200 + null.

    Antes devolvía 404, pero el panel admin tenía que manejar el 404 como caso
    normal. Ahora es 200 + null para diferenciar "no hay turno abierto" de un
    error real (red/permisos).
    """
    resp = client.get(
        "/api/v1/cierres-caja/abierto-actual?turno=cena",
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200
    assert resp.json() is None


def test_abierto_actual_turno_invalido_devuelve_422(client):
    resp = client.get(
        "/api/v1/cierres-caja/abierto-actual?turno=madrugada",
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 422


def test_abierto_actual_sin_token_devuelve_401(client):
    resp = client.get("/api/v1/cierres-caja/abierto-actual?turno=comida")
    assert resp.status_code == 401


# ─── Tests: GET /{id} ────────────────────────────────────────────────────────

def test_obtener_cierre_por_id_ok(client):
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    resp = client.get(f"/api/v1/cierres-caja/{cierre_id}", headers=_tok_admin("R1"))
    assert resp.status_code == 200
    assert resp.json()["id"] == cierre_id
    assert resp.json()["turno"] == "comida"


def test_obtener_cierre_id_invalido_devuelve_422(client):
    resp = client.get("/api/v1/cierres-caja/no-es-un-oid", headers=_tok_admin("R1"))
    assert resp.status_code == 422


# ─── Tests unitarios: _rango_turno ───────────────────────────────────────────

def test_rango_turno_comida_no_cruza_medianoche():
    from routes.cierres_caja import _rango_turno
    ini, fin = _rango_turno("2025-05-01", "comida")
    # Comida cubre desde primera hora hasta las 16:59 (incluye lo que antes
    # era el turno desayuno).
    assert ini.hour == 5 and ini.minute == 0
    assert fin.hour == 16 and fin.minute == 59
    assert ini.date() == fin.date()


def test_rango_turno_cena_cruza_medianoche():
    from routes.cierres_caja import _rango_turno
    ini, fin = _rango_turno("2025-05-01", "cena")
    assert ini.hour == 17 and ini.minute == 0
    # La cena del 01 termina el 02 a las 04:59
    assert fin.hour == 4 and fin.minute == 59
    assert fin.date() > ini.date()


def test_rango_turno_desayuno_ya_no_existe():
    from routes.cierres_caja import _rango_turno
    from exceptions import ValidacionError
    try:
        _rango_turno("2025-06-15", "desayuno")
        assert False, "Debería haber lanzado por turno inválido"
    except (ValidacionError, KeyError):
        pass


def test_rango_turno_fecha_invalida_lanza_error():
    from routes.cierres_caja import _rango_turno
    from exceptions import ValidacionError
    try:
        _rango_turno("no-es-fecha", "comida")
        assert False, "Debería haber lanzado ValidacionError"
    except ValidacionError:
        pass


# ─── Tests: pedidos de R2 no afectan a R1 ───────────────────────────────────

def test_pedidos_de_r2_no_bloquean_cierre_de_r1(client):
    """Pedidos bloqueantes de R2 no deben bloquear el cierre de R1."""
    cierre_id = _insertar_cierre(rid="R1", turno="comida", fecha="2025-05-01", estado="abierto")
    # Pedido bloqueante pero de R2
    _insertar_pedido(rid="R2", estado="pendiente", fecha="2025-05-01T13:00:00")

    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 0.0},
        headers=_tok_admin("R1"),
    )
    # Sin pedidos de R1 bloqueando, debe cerrar sin problemas
    assert resp.status_code == 200, resp.json()


def test_pedidos_fuera_de_rango_no_bloquean_cierre(client):
    """Pedido pendiente fuera de la franja del turno no bloquea el cierre."""
    cierre_id = _insertar_cierre(rid="R1", turno="cena", fecha="2025-05-01", estado="abierto")
    # Pedido pendiente a las 13:30 (fuera del rango cena 17:00-04:59)
    _insertar_pedido(rid="R1", estado="pendiente", fecha="2025-05-01T13:30:00")

    resp = client.post(
        f"/api/v1/cierres-caja/{cierre_id}/cerrar",
        json={"efectivo_declarado": 0.0},
        headers=_tok_admin("R1"),
    )
    assert resp.status_code == 200, resp.json()


# ─── Tests: apertura automática del turno (a la hora de apertura) ─────────────

def _insertar_restaurante(horarios_dia: dict | None) -> str:
    """Inserta un restaurante con _id ObjectId real y devuelve el id str."""
    from database import coleccion_restaurantes
    doc = {"nombre": "Bravo Auto", "codigo": "AUTO1", "activo": True}
    if horarios_dia is not None:
        doc["horarios_dia"] = horarios_dia
    return str(coleccion_restaurantes.insert_one(doc).inserted_id)


def test_turno_activo_segun_hora_local():
    from routes.cierres_caja import _turno_activo
    # comida 05:00-16:59, cena 17:00-04:59 (cruza medianoche)
    assert _turno_activo(datetime(2026, 5, 20, 13, 0)) == "comida"
    assert _turno_activo(datetime(2026, 5, 20, 9, 30)) == "comida"
    assert _turno_activo(datetime(2026, 5, 20, 21, 0)) == "cena"
    assert _turno_activo(datetime(2026, 5, 20, 2, 0)) == "cena"  # madrugada


def test_restaurante_abierto_ahora_dentro_fuera_cerrado():
    from routes.cierres_caja import _restaurante_abierto_ahora, _DIAS_ES
    ahora = datetime(2026, 5, 20, 13, 0)               # miércoles
    dia = _DIAS_ES[ahora.weekday()]

    rid_ok = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": True}})
    assert _restaurante_abierto_ahora(rid_ok, ahora) is True
    assert _restaurante_abierto_ahora(rid_ok, datetime(2026, 5, 20, 11, 0)) is False  # antes de abrir

    rid_cerrado = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": False}})
    assert _restaurante_abierto_ahora(rid_cerrado, ahora) is False

    rid_sin_horario = _insertar_restaurante(None)
    assert _restaurante_abierto_ahora(rid_sin_horario, ahora) is True  # sin horarios: no bloquea


def test_auto_abrir_crea_cierre_cuando_dentro_de_horario():
    from routes.cierres_caja import _auto_abrir_si_corresponde, _DIAS_ES
    from database import coleccion_cierres_caja
    ahora = datetime(2026, 5, 20, 13, 0)
    dia = _DIAS_ES[ahora.weekday()]
    rid = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": True}})

    doc = _auto_abrir_si_corresponde(rid, "comida", "2026-05-20", ahora_local=ahora)
    assert doc is not None
    assert doc["estado"] == "abierto"
    assert doc["abierto_por"] == "sistema"
    assert coleccion_cierres_caja.count_documents(
        {"restaurante_id": rid, "fecha": "2026-05-20", "turno": "comida"}
    ) == 1


def test_auto_abrir_no_crea_fuera_de_horario_de_apertura():
    from routes.cierres_caja import _auto_abrir_si_corresponde, _DIAS_ES
    from database import coleccion_cierres_caja
    ahora = datetime(2026, 5, 20, 11, 0)  # antes de apertura 12:30
    dia = _DIAS_ES[ahora.weekday()]
    rid = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": True}})

    doc = _auto_abrir_si_corresponde(rid, "comida", "2026-05-20", ahora_local=ahora)
    assert doc is None
    assert coleccion_cierres_caja.count_documents({"restaurante_id": rid}) == 0


def test_auto_abrir_no_crea_si_turno_pedido_no_es_el_activo():
    from routes.cierres_caja import _auto_abrir_si_corresponde, _DIAS_ES
    from database import coleccion_cierres_caja
    ahora = datetime(2026, 5, 20, 13, 0)  # turno activo = comida
    dia = _DIAS_ES[ahora.weekday()]
    rid = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": True}})

    doc = _auto_abrir_si_corresponde(rid, "cena", "2026-05-20", ahora_local=ahora)
    assert doc is None
    assert coleccion_cierres_caja.count_documents({"restaurante_id": rid}) == 0


def test_auto_abrir_idempotente_devuelve_existente_sin_duplicar():
    from routes.cierres_caja import _auto_abrir_si_corresponde, _DIAS_ES
    from database import coleccion_cierres_caja
    ahora = datetime(2026, 5, 20, 13, 0)
    dia = _DIAS_ES[ahora.weekday()]
    rid = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": True}})

    primero = _auto_abrir_si_corresponde(rid, "comida", "2026-05-20", ahora_local=ahora)
    segundo = _auto_abrir_si_corresponde(rid, "comida", "2026-05-20", ahora_local=ahora)
    assert primero is not None and segundo is not None
    assert str(primero["_id"]) == str(segundo["_id"])
    assert coleccion_cierres_caja.count_documents({"restaurante_id": rid}) == 1


def test_auto_abrir_no_reabre_un_cierre_ya_cerrado():
    from routes.cierres_caja import _auto_abrir_si_corresponde, _DIAS_ES
    from database import coleccion_cierres_caja
    ahora = datetime(2026, 5, 20, 13, 0)
    dia = _DIAS_ES[ahora.weekday()]
    rid = _insertar_restaurante({dia: {"apertura": "12:30", "cierre": "23:30", "abierto": True}})
    coleccion_cierres_caja.insert_one({
        "restaurante_id": rid, "fecha": "2026-05-20", "turno": "comida",
        "estado": "cerrado", "abierto_por": "sistema",
    })

    doc = _auto_abrir_si_corresponde(rid, "comida", "2026-05-20", ahora_local=ahora)
    assert doc is not None
    assert doc["estado"] == "cerrado"  # NO se reabre solo
    assert coleccion_cierres_caja.count_documents({"restaurante_id": rid}) == 1
