"""Tests for the domain exception hierarchy."""
from exceptions import (
    AppError,
    NotFoundError,
    ConflictError,
    ValidacionError,
    AutenticacionError,
    AutorizacionError,
)


def test_base_error_status_code():
    err = AppError("algo salió mal")
    assert err.status_code == 500
    assert err.detail == "algo salió mal"
    assert str(err) == "algo salió mal"


def test_not_found_is_404():
    err = NotFoundError("recurso no encontrado")
    assert err.status_code == 404
    assert isinstance(err, AppError)


def test_conflict_is_409():
    err = ConflictError("correo duplicado")
    assert err.status_code == 409
    assert isinstance(err, AppError)


def test_validacion_is_422():
    err = ValidacionError("campo inválido")
    assert err.status_code == 422
    assert isinstance(err, AppError)


def test_autenticacion_is_401():
    err = AutenticacionError("credenciales incorrectas")
    assert err.status_code == 401
    assert isinstance(err, AppError)


def test_autorizacion_is_403():
    err = AutorizacionError("acceso denegado")
    assert err.status_code == 403
    assert isinstance(err, AppError)


def test_exception_carries_detail():
    err = NotFoundError("usuario no encontrado")
    assert err.detail == "usuario no encontrado"
