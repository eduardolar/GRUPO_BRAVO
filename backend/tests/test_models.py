"""Tests for Pydantic model validation."""
import pytest
from pydantic import ValidationError
from models import (
    ItemPedido,
    PedidoCrear,
    TipoEntrega,
    MetodoPago,
    EstadoPago,
    UsuarioRegistro,
    VerificarRecuperacion,
)



# ── ItemPedido ────────────────────────────────────────────────────────────────

class TestItemPedido:
    def test_valid_item(self):
        item = ItemPedido(producto_id="abc123", cantidad=2, precio=10.0)
        assert item.cantidad == 2
        assert item.precio == 10.0
        assert item.sin == []

    def test_cantidad_minima_es_uno(self):
        with pytest.raises(ValidationError):
            ItemPedido(producto_id="abc", cantidad=0, precio=5.0)

    def test_cantidad_negativa_rechazada(self):
        with pytest.raises(ValidationError):
            ItemPedido(producto_id="abc", cantidad=-3, precio=5.0)

    def test_precio_negativo_rechazado(self):
        with pytest.raises(ValidationError):
            ItemPedido(producto_id="abc", cantidad=1, precio=-1.0)

    def test_precio_cero_permitido(self):
        item = ItemPedido(producto_id="abc", cantidad=1, precio=0.0)
        assert item.precio == 0.0

    def test_sin_lista_personalizada(self):
        item = ItemPedido(producto_id="abc", cantidad=1, precio=5.0, sin=["cebolla", "tomate"])
        assert "cebolla" in item.sin

    def test_campos_extra_permitidos(self):
        item = ItemPedido(producto_id="abc", cantidad=1, precio=5.0, nombre="Pizza")
        assert item.nombre == "Pizza"


# ── PedidoCrear ───────────────────────────────────────────────────────────────

ITEM_BASE = {"producto_id": "abc", "cantidad": 1, "precio": 10.0}


class TestPedidoCrear:
    def _pedido(self, **kwargs):
        base = {
            "userId": "user1",
            "items": [ITEM_BASE],
            "tipoEntrega": "local",
            "metodoPago": "efectivo",
        }
        base.update(kwargs)
        return PedidoCrear(**base)

    def test_pedido_valido(self):
        p = self._pedido()
        assert p.estadoPago == EstadoPago.pendiente
        assert p.metodoPago == MetodoPago.efectivo

    def test_items_vacios_rechazados(self):
        with pytest.raises(ValidationError):
            self._pedido(items=[])

    def test_metodo_pago_invalido_rechazado(self):
        with pytest.raises(ValidationError):
            self._pedido(metodoPago="cripto")

    def test_tipo_entrega_invalido_rechazado(self):
        with pytest.raises(ValidationError):
            self._pedido(tipoEntrega="avion")

    def test_normalizacion_mesa_a_local(self):
        p = self._pedido(tipoEntrega="mesa")
        assert p.tipoEntrega == TipoEntrega.local

    def test_normalizacion_en_mesa_a_local(self):
        p = self._pedido(tipoEntrega="En mesa")
        assert p.tipoEntrega == TipoEntrega.local

    def test_normalizacion_domicilio_variantes(self):
        p = self._pedido(tipoEntrega="A domicilio")
        assert p.tipoEntrega == TipoEntrega.domicilio

    def test_normalizacion_recoger(self):
        p = self._pedido(tipoEntrega="Recoger en tienda")
        assert p.tipoEntrega == TipoEntrega.recoger

    # ── Normalización metodoPago (variantes display de Flutter) ──────────────

    def test_metodo_pago_tarjeta_capitalizado(self):
        p = self._pedido(metodoPago="Tarjeta")
        assert p.metodoPago == MetodoPago.tarjeta

    def test_metodo_pago_efectivo_capitalizado(self):
        p = self._pedido(metodoPago="Efectivo")
        assert p.metodoPago == MetodoPago.efectivo

    def test_metodo_pago_google_pay_con_espacio(self):
        p = self._pedido(metodoPago="Google Pay")
        assert p.metodoPago == MetodoPago.google_pay

    def test_metodo_pago_apple_pay_con_espacio(self):
        p = self._pedido(metodoPago="Apple Pay")
        assert p.metodoPago == MetodoPago.apple_pay

    def test_metodo_pago_paypal_capitalizado(self):
        p = self._pedido(metodoPago="PayPal")
        assert p.metodoPago == MetodoPago.paypal

    # ── Normalización estadoPago ──────────────────────────────────────────────

    def test_estado_pago_enum(self):
        p = self._pedido(estadoPago="pagado")
        assert p.estadoPago == EstadoPago.pagado

    def test_estado_pago_fallido(self):
        p = self._pedido(estadoPago="fallido")
        assert p.estadoPago == EstadoPago.fallido

    def test_estado_pago_pendiente_stripe_normaliza(self):
        p = self._pedido(estadoPago="pendiente_stripe")
        assert p.estadoPago == EstadoPago.pendiente

    def test_estado_pago_pendiente_paypal_normaliza(self):
        p = self._pedido(estadoPago="pendiente_paypal")
        assert p.estadoPago == EstadoPago.pendiente

    # ── Campos opcionales ─────────────────────────────────────────────────────

    def test_campos_opcionales_son_none_por_defecto(self):
        p = self._pedido()
        assert p.direccionEntrega is None
        assert p.mesaId is None
        assert p.numeroMesa is None
        assert p.notas is None


# ── UsuarioRegistro ───────────────────────────────────────────────────────────

class TestUsuarioRegistro:
    def _usuario(self, **kwargs):
        base = {
            "nombre": "Ana García",
            "password": "Segura123!",
            "correo": "ana@test.com",
            "telefono": "600000000",
            "direccion": "Calle Mayor 1",
        }
        base.update(kwargs)
        return UsuarioRegistro(**base)

    def test_usuario_valido(self):
        u = self._usuario()
        assert u.nombre == "Ana García"
        assert u.rol == "cliente"

    def test_password_muy_corta(self):
        with pytest.raises(ValidationError):
            self._usuario(password="Ab1!")

    def test_password_sin_mayuscula(self):
        with pytest.raises(ValidationError, match="mayúscula"):
            self._usuario(password="segura123!")

    def test_password_sin_numero(self):
        with pytest.raises(ValidationError, match="número"):
            self._usuario(password="Seguridad!")

    def test_password_sin_especial(self):
        with pytest.raises(ValidationError, match="especial"):
            self._usuario(password="Segura123")

    def test_correo_invalido(self):
        with pytest.raises(ValidationError):
            self._usuario(correo="no-es-un-correo")


# ── VerificarRecuperacion ─────────────────────────────────────────────────────

class TestVerificarRecuperacion:
    def test_parseo_correcto(self):
        v = VerificarRecuperacion(user_id="user1", codigo="ABCD1234-EFGH5678")
        assert v.user_id == "user1"
        assert v.codigo == "ABCD1234-EFGH5678"
