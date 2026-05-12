"""Tests de los endpoints de subida/borrado de imágenes de productos.

Cubre: POST /productos/{id}/imagen  y  DELETE /productos/{id}/imagen.

Estrategia de mocking:
- La librería `cloudinary` puede no estar instalada en el entorno de CI.
- Para evitar ImportError al parchear `cloudinary.uploader.upload`, los tests
  inyectan un módulo falso en sys.modules antes de cada prueba que llama a
  Cloudinary, y parchan directamente los nombres importados en routes.uploads.
- `cloudinary_client._DISPONIBLE` se parchea con monkeypatch para simular
  el estado de configuración sin tocar el entorno real.
"""
import sys
import types
from io import BytesIO
from unittest.mock import MagicMock, patch

import pytest
from bson import ObjectId

from tests.tok_helpers import tok


# ─── Stub de cloudinary para entornos sin la lib instalada ───────────────────

def _instalar_stub_cloudinary():
    """Inyecta módulos falsos en sys.modules para que los imports dentro de
    routes.uploads no fallen cuando cloudinary no está instalado."""
    if "cloudinary" not in sys.modules:
        # Módulo raíz
        cloudinary_mod = types.ModuleType("cloudinary")
        sys.modules["cloudinary"] = cloudinary_mod

        # Submódulo uploader
        uploader_mod = types.ModuleType("cloudinary.uploader")
        uploader_mod.upload = MagicMock()
        uploader_mod.destroy = MagicMock()
        cloudinary_mod.uploader = uploader_mod
        sys.modules["cloudinary.uploader"] = uploader_mod


# Instalar el stub tan pronto como se importa el módulo de tests,
# antes de que cualquier test importe routes.uploads.
_instalar_stub_cloudinary()


# ─── Helpers de tokens ───────────────────────────────────────────────────────

def _tok_admin(rid: str = "R1") -> dict:
    return tok("admin", restaurante_id=rid)


def _tok_super() -> dict:
    return tok("super_admin")


# ─── Helper: respuesta falsa de Cloudinary ───────────────────────────────────

def _mk_upload_result(
    secure_url: str = "https://res.cloudinary.com/demo/image/upload/v1/abc.jpg",
    public_id: str = "grupo_bravo/productos/R1/abc",
) -> dict:
    return {"secure_url": secure_url, "public_id": public_id}


# ─── Helper: fichero multipart de prueba ─────────────────────────────────────

def _fake_file(
    nombre: str = "foto.jpg",
    content_type: str = "image/jpeg",
    size_bytes: int = 1024,
) -> tuple:
    """Retorna la tupla que TestClient necesita en files={'file': (...)}."""
    datos = b"x" * size_bytes
    return (nombre, BytesIO(datos), content_type)


# ─── Helper: documento producto en BD ────────────────────────────────────────

def _producto(
    prod_id: ObjectId | None = None,
    rid: str = "R1",
    imagen: str | None = None,
    imagen_public_id: str | None = None,
) -> dict:
    oid = prod_id or ObjectId()
    doc: dict = {
        "_id": oid,
        "nombre": "Producto Test",
        "descripcion": "desc",
        "precio": 9.99,
        "categoria": "Test",
        "restaurante_id": rid,
    }
    if imagen is not None:
        doc["imagen"] = imagen
    if imagen_public_id is not None:
        doc["imagen_public_id"] = imagen_public_id
    return doc


# ─── Contextos de configuración ──────────────────────────────────────────────

def _disponible(valor: bool = True):
    """Parchea cloudinary_client._DISPONIBLE al valor indicado."""
    return patch("cloudinary_client._DISPONIBLE", valor)


def _mock_upload(result: dict):
    """Parchea cloudinary.uploader.upload en routes.uploads."""
    mock = MagicMock(return_value=result)
    return patch("cloudinary.uploader.upload", mock), mock


def _mock_destroy():
    """Parchea cloudinary.uploader.destroy en routes.uploads."""
    mock = MagicMock()
    return patch("cloudinary.uploader.destroy", mock), mock


# ═══════════════════════════════════════════════════════════════════════════════
# POST /productos/{id}/imagen
# ═══════════════════════════════════════════════════════════════════════════════

def test_subir_imagen_ok(client):
    """Subida exitosa: update_one recibe la URL y public_id correctos."""
    prod = _producto()
    prod_id = str(prod["_id"])
    upload_result = _mk_upload_result(
        secure_url="https://res.cloudinary.com/demo/img/abc.jpg",
        public_id="grupo_bravo/productos/R1/abc",
    )

    upload_patch, mock_upload = _mock_upload(upload_result)
    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col, \
         upload_patch:

        mock_col.find_one.return_value = prod
        mock_col.update_one.return_value = MagicMock()

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["imagen"] == upload_result["secure_url"]
    assert data["imagen_public_id"] == upload_result["public_id"]

    # Verificar que update_one fue llamado con los valores correctos
    call_args = mock_col.update_one.call_args
    set_doc = call_args[0][1]["$set"]
    assert set_doc["imagen"] == upload_result["secure_url"]
    assert set_doc["imagen_public_id"] == upload_result["public_id"]


def test_subir_imagen_reemplaza_public_id_distinto_borra_vieja(client):
    """Si el producto ya tenía un public_id diferente al nuevo, destroy se llama con el viejo."""
    public_id_viejo = "grupo_bravo/productos/R1/id_viejo"
    public_id_nuevo = "grupo_bravo/productos/R1/nuevo"
    prod = _producto(imagen_public_id=public_id_viejo)
    prod_id = str(prod["_id"])

    upload_result = _mk_upload_result(public_id=public_id_nuevo)
    upload_patch, _ = _mock_upload(upload_result)
    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col, \
         upload_patch, destroy_patch:

        mock_col.find_one.return_value = prod
        mock_col.update_one.return_value = MagicMock()

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 200, resp.text
    # destroy debe haberse llamado exactamente con el public_id anterior
    mock_destroy.assert_called_once_with(public_id_viejo)


def test_subir_imagen_mismo_public_id_no_borra(client):
    """Si el upload genera el mismo public_id (overwrite idempotente), destroy NO se llama."""
    mismo_public_id = "grupo_bravo/productos/R1/abc"
    prod = _producto(imagen_public_id=mismo_public_id)
    prod_id = str(prod["_id"])

    upload_result = _mk_upload_result(public_id=mismo_public_id)
    upload_patch, _ = _mock_upload(upload_result)
    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col, \
         upload_patch, destroy_patch:

        mock_col.find_one.return_value = prod
        mock_col.update_one.return_value = MagicMock()

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 200, resp.text
    mock_destroy.assert_not_called()


def test_subir_imagen_mime_invalido_devuelve_400(client):
    """Un GIF (no permitido) devuelve 400 antes de intentar subir."""
    prod = _producto()
    prod_id = str(prod["_id"])

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col:

        mock_col.find_one.return_value = prod

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file(nombre="foto.gif", content_type="image/gif")},
        )

    assert resp.status_code == 400, resp.text
    assert "no permitido" in resp.json()["detail"].lower()


def test_subir_imagen_excede_5mb_devuelve_413(client):
    """Archivo mayor a 5 MB devuelve 413."""
    prod = _producto()
    prod_id = str(prod["_id"])
    # 5 MB + 1 byte
    size_excedido = 5 * 1024 * 1024 + 1

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col:

        mock_col.find_one.return_value = prod

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file(size_bytes=size_excedido)},
        )

    assert resp.status_code == 413, resp.text
    assert "5 mb" in resp.json()["detail"].lower()


def test_subir_imagen_producto_inexistente_devuelve_404(client):
    """Producto que no existe en BD devuelve 404."""
    prod_id = str(ObjectId())

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col:

        mock_col.find_one.return_value = None

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 404, resp.text


def test_subir_imagen_admin_otra_sucursal_devuelve_403(client):
    """Admin de R2 no puede modificar un producto que pertenece a R1."""
    prod = _producto(rid="R1")
    prod_id = str(prod["_id"])

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col:

        mock_col.find_one.return_value = prod

        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R2"),  # admin de sucursal diferente
            files={"file": _fake_file()},
        )

    assert resp.status_code == 403, resp.text


def test_subir_imagen_sin_token_devuelve_401(client):
    """Sin token de autenticación el endpoint devuelve 401."""
    prod_id = str(ObjectId())
    resp = client.post(
        f"/api/v1/productos/{prod_id}/imagen",
        files={"file": _fake_file()},
        # Sin headers de autorización
    )
    assert resp.status_code == 401, resp.text


# ═══════════════════════════════════════════════════════════════════════════════
# DELETE /productos/{id}/imagen
# ═══════════════════════════════════════════════════════════════════════════════

def test_borrar_imagen_ok(client):
    """Producto con public_id: destroy se llama y los campos se limpian en BD."""
    public_id = "grupo_bravo/productos/R1/abc"
    prod = _producto(
        imagen="https://res.cloudinary.com/demo/img/abc.jpg",
        imagen_public_id=public_id,
    )
    prod_id = str(prod["_id"])

    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col, \
         destroy_patch:

        mock_col.find_one.return_value = prod
        mock_col.update_one.return_value = MagicMock()

        resp = client.delete(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
        )

    assert resp.status_code == 200, resp.text
    mock_destroy.assert_called_once_with(public_id)

    # Verificar que se usó $set con string vacío para limpiar ambos campos
    # (no $unset porque puede romper schemas que exigen el campo como string).
    call_args = mock_col.update_one.call_args
    set_doc = call_args[0][1]["$set"]
    assert set_doc.get("imagen") == ""
    assert set_doc.get("imagen_public_id") == ""


def test_borrar_imagen_sin_imagen_previa(client):
    """Producto sin imagen previa: 200 silencioso (idempotente). destroy no se llama."""
    prod = _producto()  # sin imagen_public_id
    prod_id = str(prod["_id"])

    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_productos") as mock_col, \
         destroy_patch:

        mock_col.find_one.return_value = prod
        mock_col.update_one.return_value = MagicMock()

        resp = client.delete(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
        )

    assert resp.status_code == 200, resp.text
    mock_destroy.assert_not_called()


# ═══════════════════════════════════════════════════════════════════════════════
# Cloudinary no configurado (_DISPONIBLE = False)
# ═══════════════════════════════════════════════════════════════════════════════

def test_cloudinary_no_disponible_devuelve_503_en_post(client):
    """Si _DISPONIBLE es False, el POST devuelve 503 con mensaje explicativo."""
    prod_id = str(ObjectId())

    with _disponible(False):
        resp = client.post(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 503, resp.text
    detail = resp.json()["detail"]
    assert "cloudinary" in detail.lower()
    assert "CLOUDINARY_CLOUD_NAME" in detail


def test_cloudinary_no_disponible_devuelve_503_en_delete(client):
    """Si _DISPONIBLE es False, el DELETE devuelve 503 con mensaje explicativo."""
    prod_id = str(ObjectId())

    with _disponible(False):
        resp = client.delete(
            f"/api/v1/productos/{prod_id}/imagen",
            headers=_tok_admin("R1"),
        )

    assert resp.status_code == 503, resp.text
    detail = resp.json()["detail"]
    assert "cloudinary" in detail.lower()


# ═══════════════════════════════════════════════════════════════════════════════
# POST /restaurantes/{id}/logo  y  DELETE /restaurantes/{id}/logo
# ═══════════════════════════════════════════════════════════════════════════════

def _restaurante(
    rest_id: ObjectId | None = None,
    logo_url: str | None = None,
    logo_public_id: str | None = None,
) -> dict:
    """Crea un documento de restaurante de prueba."""
    oid = rest_id or ObjectId()
    doc: dict = {
        "_id": oid,
        "nombre": "Restaurante Test",
        "direccion": "Calle Test 1",
        "codigo": "TSTXX",
        "activo": True,
    }
    if logo_url is not None:
        doc["logo_url"] = logo_url
    if logo_public_id is not None:
        doc["logo_public_id"] = logo_public_id
    return doc


def _mk_logo_result(
    secure_url: str = "https://res.cloudinary.com/demo/image/upload/v1/logo.jpg",
    public_id: str = "grupo_bravo/restaurantes/R1/logo",
) -> dict:
    return {"secure_url": secure_url, "public_id": public_id}


def test_subir_logo_restaurante_ok(client):
    """Subida de logo exitosa: BD actualizada con logo_url y logo_public_id."""
    rest = _restaurante()
    rest_id = str(rest["_id"])
    upload_result = _mk_logo_result(
        secure_url="https://res.cloudinary.com/demo/logo.jpg",
        public_id=f"grupo_bravo/restaurantes/{rest_id}/logo",
    )

    upload_patch, mock_upload = _mock_upload(upload_result)
    with _disponible(), \
         patch("routes.uploads.coleccion_restaurantes") as mock_col, \
         upload_patch:

        mock_col.find_one.return_value = rest
        mock_col.update_one.return_value = MagicMock()

        resp = client.post(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_super(),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["logo_url"] == upload_result["secure_url"]
    assert data["logo_public_id"] == upload_result["public_id"]

    call_args = mock_col.update_one.call_args
    set_doc = call_args[0][1]["$set"]
    assert set_doc["logo_url"] == upload_result["secure_url"]
    assert set_doc["logo_public_id"] == upload_result["public_id"]


def test_subir_logo_reemplaza_anterior(client):
    """Si el restaurante ya tenía un logo con public_id distinto, destroy se llama con el viejo."""
    public_id_viejo = "grupo_bravo/restaurantes/R1/logo_viejo"
    public_id_nuevo = "grupo_bravo/restaurantes/R1/logo_nuevo"
    rest = _restaurante(logo_url="https://old.jpg", logo_public_id=public_id_viejo)
    rest_id = str(rest["_id"])

    upload_result = _mk_logo_result(public_id=public_id_nuevo)
    upload_patch, _ = _mock_upload(upload_result)
    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_restaurantes") as mock_col, \
         upload_patch, destroy_patch:

        mock_col.find_one.return_value = rest
        mock_col.update_one.return_value = MagicMock()

        resp = client.post(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_super(),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 200, resp.text
    mock_destroy.assert_called_once_with(public_id_viejo)


def test_subir_logo_super_admin_only(client):
    """Un admin (no super_admin) recibe 403 al intentar subir el logo."""
    rest = _restaurante()
    rest_id = str(rest["_id"])

    with _disponible(), \
         patch("routes.uploads.coleccion_restaurantes") as mock_col:

        mock_col.find_one.return_value = rest

        resp = client.post(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_admin("R1"),
            files={"file": _fake_file()},
        )

    assert resp.status_code == 403, resp.text


def test_borrar_logo_restaurante_ok(client):
    """Borrado de logo: destroy se llama y BD queda con logo_url='' y logo_public_id=''."""
    public_id = "grupo_bravo/restaurantes/R1/logo"
    rest = _restaurante(
        logo_url="https://res.cloudinary.com/demo/logo.jpg",
        logo_public_id=public_id,
    )
    rest_id = str(rest["_id"])

    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_restaurantes") as mock_col, \
         destroy_patch:

        mock_col.find_one.return_value = rest
        mock_col.update_one.return_value = MagicMock()

        resp = client.delete(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_super(),
        )

    assert resp.status_code == 200, resp.text
    mock_destroy.assert_called_once_with(public_id)

    call_args = mock_col.update_one.call_args
    set_doc = call_args[0][1]["$set"]
    assert set_doc.get("logo_url") == ""
    assert set_doc.get("logo_public_id") == ""


def test_borrar_logo_sin_logo_previo(client):
    """Restaurante sin logo previo: 200 silencioso, destroy no se llama."""
    rest = _restaurante()  # sin logo_public_id
    rest_id = str(rest["_id"])

    destroy_patch, mock_destroy = _mock_destroy()

    with _disponible(), \
         patch("routes.uploads.coleccion_restaurantes") as mock_col, \
         destroy_patch:

        mock_col.find_one.return_value = rest
        mock_col.update_one.return_value = MagicMock()

        resp = client.delete(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_super(),
        )

    assert resp.status_code == 200, resp.text
    mock_destroy.assert_not_called()


def test_subir_logo_cloudinary_no_disponible_503(client):
    """Si Cloudinary no está configurado, POST logo devuelve 503."""
    rest_id = str(ObjectId())
    with _disponible(False):
        resp = client.post(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_super(),
            files={"file": _fake_file()},
        )
    assert resp.status_code == 503, resp.text
    assert "cloudinary" in resp.json()["detail"].lower()


def test_borrar_logo_cloudinary_no_disponible_503(client):
    """Si Cloudinary no está configurado, DELETE logo devuelve 503."""
    rest_id = str(ObjectId())
    with _disponible(False):
        resp = client.delete(
            f"/api/v1/restaurantes/{rest_id}/logo",
            headers=_tok_super(),
        )
    assert resp.status_code == 503, resp.text
