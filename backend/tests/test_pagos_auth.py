"""Tests de autenticación/autorización en endpoints /api/v1/payments/*.

Bloqueante 3 — los endpoints de creación de pago deben:
- Requerir JWT válido (sin token → 401).
- Validar que el pedido pertenece al caller (pedido ajeno → 403).
- El webhook de Stripe queda SIN JWT (valida Stripe-Signature).
"""
from unittest.mock import MagicMock, patch
from bson import ObjectId

from tests.tok_helpers import tok, TEST_OID_CLIENTE, TEST_OID_CAMARERO

# ID de cliente fijo (ObjectId string) que se usa como usuario_id en pedidos
_CLIENTE_ID = str(TEST_OID_CLIENTE)
_OTRO_CLIENTE_ID = str(ObjectId("000000000000000000000001"))


# ── Helpers de token ──────────────────────────────────────────────────────────

def _token_cliente(restaurante_id: str | None = None) -> dict:
    return tok("cliente", restaurante_id=restaurante_id)


def _token_camarero(restaurante_id: str = "r1") -> dict:
    return tok("camarero", restaurante_id=restaurante_id)


def _make_pedido(pedido_id, usuario_id: str | None = None, restaurante_id: str = "r1") -> dict:
    return {
        "_id": ObjectId(pedido_id),
        "usuario_id": usuario_id if usuario_id is not None else _CLIENTE_ID,
        "restaurante_id": restaurante_id,
        "total": 20.0,
        "estado": "pendiente",
        "estado_pago": "pendiente",
    }


# ── POST /payments/stripe/create-intent ──────────────────────────────────────

def test_stripe_intent_sin_token_devuelve_401(client):
    """Sin token JWT → 401."""
    pedido_id = str(ObjectId())
    resp = client.post(
        "/api/v1/payments/stripe/create-intent",
        json={"pedido_id": pedido_id, "currency": "eur"},
    )
    assert resp.status_code == 401


def test_stripe_intent_cliente_pedido_propio_devuelve_200(client):
    """Cliente con su propio pedido → 200 (Stripe mockeado)."""
    pedido_id = str(ObjectId())
    # usuario_id coincide con el sub del token (_CLIENTE_ID)
    pedido_doc = _make_pedido(pedido_id, usuario_id=_CLIENTE_ID)

    mock_intent = MagicMock()
    mock_intent.__getitem__ = lambda self, k: {
        "id": "pi_test", "client_secret": "cs_test", "status": "requires_payment_method"
    }[k]

    with patch("services.pagos_service.coleccion_pedidos") as mock_col, \
         patch("pagos.stripe") as mock_stripe, \
         patch("services.pagos_service.stripe") as mock_stripe_svc, \
         patch("pagos.registrar_pago"):
        mock_col.find_one.return_value = pedido_doc
        mock_stripe.PaymentIntent.create.return_value = {
            "id": "pi_test",
            "client_secret": "cs_test",
            "status": "requires_payment_method",
        }
        mock_stripe.api_key = "sk_test_fake"
        # _exigir_stripe vive ahora en services.pagos_service (piloto 6.2.3)
        # y lee SU referencia a stripe; hay que mockear su api_key también.
        mock_stripe_svc.api_key = "sk_test_fake"

        resp = client.post(
            "/api/v1/payments/stripe/create-intent",
            json={"pedido_id": pedido_id, "currency": "eur"},
            headers=_token_cliente(),
        )

    assert resp.status_code == 200
    assert "payment_intent_id" in resp.json()


def test_stripe_intent_cliente_pedido_ajeno_devuelve_403(client):
    """Cliente intenta crear intent sobre pedido de otro usuario → 403."""
    pedido_id = str(ObjectId())
    # usuario_id distinto al sub del token del cliente
    pedido_doc = _make_pedido(pedido_id, usuario_id=_OTRO_CLIENTE_ID)

    with patch("services.pagos_service.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido_doc

        resp = client.post(
            "/api/v1/payments/stripe/create-intent",
            json={"pedido_id": pedido_id, "currency": "eur"},
            headers=_token_cliente(),  # sub distinto al usuario_id del pedido
        )

    assert resp.status_code == 403


def test_stripe_intent_camarero_pedido_otra_sucursal_devuelve_403(client):
    """Camarero R1 intenta crear intent sobre pedido de R2 → 403."""
    pedido_id = str(ObjectId())
    pedido_doc = _make_pedido(pedido_id, usuario_id=_OTRO_CLIENTE_ID, restaurante_id="r2")

    with patch("services.pagos_service.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido_doc

        resp = client.post(
            "/api/v1/payments/stripe/create-intent",
            json={"pedido_id": pedido_id, "currency": "eur"},
            headers=_token_camarero("r1"),
        )

    assert resp.status_code == 403


# ── POST /payments/stripe/create-checkout-session ────────────────────────────

def test_checkout_session_sin_token_devuelve_401(client):
    """Sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.post(
        "/api/v1/payments/stripe/create-checkout-session",
        json={
            "pedido_id": pedido_id,
            "currency": "eur",
            "success_url": "https://example.com/ok",
            "cancel_url": "https://example.com/cancel",
        },
    )
    assert resp.status_code == 401


def test_checkout_session_cliente_pedido_ajeno_devuelve_403(client):
    """Cliente intenta crear sesión sobre pedido ajeno → 403."""
    pedido_id = str(ObjectId())
    pedido_doc = _make_pedido(pedido_id, usuario_id=_OTRO_CLIENTE_ID)

    with patch("services.pagos_service.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido_doc

        resp = client.post(
            "/api/v1/payments/stripe/create-checkout-session",
            json={
                "pedido_id": pedido_id,
                "currency": "eur",
                "success_url": "https://example.com/ok",
                "cancel_url": "https://example.com/cancel",
            },
            headers=_token_cliente(),
        )

    assert resp.status_code == 403


# ── POST /payments/paypal/create-order ───────────────────────────────────────

def test_paypal_create_order_sin_token_devuelve_401(client):
    """Sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.post(
        "/api/v1/payments/paypal/create-order",
        json={"pedido_id": pedido_id, "currency": "EUR"},
    )
    assert resp.status_code == 401


def test_paypal_create_order_cliente_pedido_ajeno_devuelve_403(client):
    """Cliente intenta crear orden PayPal sobre pedido ajeno → 403."""
    pedido_id = str(ObjectId())
    pedido_doc = _make_pedido(pedido_id, usuario_id=_OTRO_CLIENTE_ID)

    with patch("services.pagos_service.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido_doc

        resp = client.post(
            "/api/v1/payments/paypal/create-order",
            json={"pedido_id": pedido_id, "currency": "EUR"},
            headers=_token_cliente(),
        )

    assert resp.status_code == 403


# ── POST /payments/apple-pay/init ─────────────────────────────────────────────

def test_apple_pay_init_sin_token_devuelve_401(client):
    """Sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.post(
        "/api/v1/payments/apple-pay/init",
        json={"pedido_id": pedido_id, "currency": "EUR", "country": "ES"},
    )
    assert resp.status_code == 401


def test_apple_pay_init_cliente_pedido_ajeno_devuelve_403(client):
    """Cliente intenta Apple Pay sobre pedido ajeno → 403."""
    pedido_id = str(ObjectId())
    pedido_doc = _make_pedido(pedido_id, usuario_id=_OTRO_CLIENTE_ID)

    with patch("services.pagos_service.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido_doc

        resp = client.post(
            "/api/v1/payments/apple-pay/init",
            json={"pedido_id": pedido_id, "currency": "EUR", "country": "ES"},
            headers=_token_cliente(),
        )

    assert resp.status_code == 403


# ── POST /payments/google-pay/init ───────────────────────────────────────────

def test_google_pay_init_sin_token_devuelve_401(client):
    """Sin token → 401."""
    pedido_id = str(ObjectId())
    resp = client.post(
        "/api/v1/payments/google-pay/init",
        json={"pedido_id": pedido_id, "currency": "EUR"},
    )
    assert resp.status_code == 401


def test_google_pay_init_cliente_pedido_ajeno_devuelve_403(client):
    """Cliente intenta Google Pay sobre pedido ajeno → 403."""
    pedido_id = str(ObjectId())
    pedido_doc = _make_pedido(pedido_id, usuario_id=_OTRO_CLIENTE_ID)

    with patch("services.pagos_service.coleccion_pedidos") as mock_col:
        mock_col.find_one.return_value = pedido_doc

        resp = client.post(
            "/api/v1/payments/google-pay/init",
            json={"pedido_id": pedido_id, "currency": "EUR"},
            headers=_token_cliente(),
        )

    assert resp.status_code == 403


# ── Webhook de Stripe — permanece SIN JWT ────────────────────────────────────

def test_stripe_webhook_sin_firma_devuelve_400(client):
    """El webhook de Stripe rechaza peticiones sin Stripe-Signature → 400 o 503.

    Sin STRIPE_WEBHOOK_SECRET configurado en tests → 503.
    Con secret configurado pero sin firma → 400.
    En ambos casos NO debe ser 401 (no requiere JWT).
    """
    resp = client.post(
        "/api/v1/payments/stripe/webhook",
        content=b'{"type": "payment_intent.succeeded"}',
        headers={"Content-Type": "application/json"},
    )
    # 503 si falta el secret (entorno de test), 400 si la firma es inválida
    assert resp.status_code in {400, 503}
    assert resp.status_code != 401, "El webhook no debe exigir JWT; valida firma de Stripe"
