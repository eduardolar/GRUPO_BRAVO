import os
import uuid
from typing import Optional, Dict, Any

import httpx
import stripe
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

load_dotenv()

stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")

PAYPAL_CLIENT_ID = os.getenv("PAYPAL_CLIENT_ID", "")
PAYPAL_CLIENT_SECRET = os.getenv("PAYPAL_CLIENT_SECRET", "")
PAYPAL_BASE_URL = os.getenv("PAYPAL_BASE_URL", "https://api-m.sandbox.paypal.com")

router = APIRouter(prefix="/payments", tags=["Pagos"])

# ── Modelos ────────────────────────────────────────────────────────────────────

class PaymentIntentCreate(BaseModel):
    amount: float = Field(gt=0)
    currency: str = "eur"

class CardConfirmRequest(BaseModel):
    clientSecret: str
    numeroTarjeta: str
    fechaExpiracion: str
    cvv: str
    nombreTitular: str

class GooglePayInitRequest(BaseModel):
    total: float = Field(gt=0)

class GooglePayVerifyRequest(BaseModel):
    token: Optional[Dict[str, Any]] = None
    packageName: Optional[str] = None
    productId: Optional[str] = None
    purchaseToken: Optional[str] = None

class CheckoutSessionCreate(BaseModel):
    total: float = Field(gt=0)
    currency: str = "eur"
    success_url: str
    cancel_url: str

class PayPalOrderCreate(BaseModel):
    total: float = Field(gt=0)
    currency: str = "EUR"

class PayPalCaptureRequest(BaseModel):
    orderId: str

# ── Stripe ─────────────────────────────────────────────────────────────────────

@router.post("/stripe/create-intent")
@router.post("/card/create-intent")
def crear_payment_intent(payload: PaymentIntentCreate):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.create(
            amount=int(round(payload.amount * 100)),
            currency=payload.currency.lower(),
            automatic_payment_methods={"enabled": True},
            # Soporte para Apple Pay/Google Pay
            payment_method_types=["card", "card_present"],
        )
        return {
            "payment_intent_id": intent["id"],
            "client_secret": intent["client_secret"],
            "status": intent["status"],
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/stripe/confirm")
@router.post("/card/confirm")
def confirmar_payment_intent(payload: CardConfirmRequest):
    if not payload.clientSecret.strip():
        raise HTTPException(status_code=400, detail="clientSecret requerido")
    if not payload.numeroTarjeta.strip():
        raise HTTPException(status_code=400, detail="Número de tarjeta requerido")
    if not payload.fechaExpiracion.strip():
        raise HTTPException(status_code=400, detail="Fecha de expiración requerida")
    if not payload.cvv.strip():
        raise HTTPException(status_code=400, detail="CVV requerido")
    if not payload.nombreTitular.strip():
        raise HTTPException(status_code=400, detail="Nombre del titular requerido")

    return {"success": True, "message": "Confirmación simulada en backend de desarrollo"}

@router.get("/stripe/verify/{payment_intent_id}")
@router.get("/card/verify/{payment_intent_id}")
def verificar_payment_intent(payment_intent_id: str):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id)
        return {
            "id": intent["id"],
            "status": intent["status"],
            "paid": intent["status"] == "succeeded",
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Stripe Checkout (web) ──────────────────────────────────────────────────────

@router.post("/stripe/create-checkout-session")
def crear_checkout_session(payload: CheckoutSessionCreate):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": payload.currency.lower(),
                    "product_data": {"name": "Pedido Restaurante Bravo"},
                    "unit_amount": int(round(payload.total * 100)),
                },
                "quantity": 1,
            }],
            mode="payment",
            success_url=payload.success_url,
            cancel_url=payload.cancel_url,
        )
        return {"session_id": session.id, "checkout_url": session.url}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/stripe/verify-session/{session_id}")
def verificar_checkout_session(session_id: str):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        return {
            "session_id": session.id,
            "payment_status": session.payment_status,
            "paid": session.payment_status == "paid",
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Google Pay ─────────────────────────────────────────────────────────────────

@router.post("/google-pay/init")
@router.post("/google-play/init")
def iniciar_google_pay(payload: GooglePayInitRequest):
    return {
        "success": True,
        "productId": "pedido_bravo",
        "purchaseToken": f"gpay_{uuid.uuid4().hex}",
        "amount": payload.total,
        "currency": "EUR",
        "message": "Inicio simulado de Google Pay para desarrollo",
    }

@router.post("/google-pay/verify")
@router.post("/google-play/verify")
def verificar_google_pay(payload: GooglePayVerifyRequest):
    if payload.token:
        signed_message = payload.token.get("signedMessage")
        protocol_version = payload.token.get("protocolVersion")
        valid = bool(signed_message and protocol_version)
        return {
            "valid": valid,
            "verified": valid,
            "success": valid,
            "status": "SUCCESS" if valid else "ERROR",
            "message": "Validación básica de token Google Pay recibida",
            "orderId": f"gpay_order_{uuid.uuid4().hex[:12]}",
        }

    if payload.productId and payload.purchaseToken:
        return {
            "valid": True,
            "verified": True,
            "success": True,
            "status": "SUCCESS",
            "productId": payload.productId,
            "purchaseToken": payload.purchaseToken,
            "packageName": payload.packageName,
            "orderId": f"gplay_order_{uuid.uuid4().hex[:12]}",
            "message": "Verificación simulada de Google Play/Google Pay en desarrollo",
        }

    raise HTTPException(
        status_code=400,
        detail="Debes enviar token o productId + purchaseToken",
    )

# ── PayPal ─────────────────────────────────────────────────────────────────────

async def _paypal_access_token() -> str:
    if not PAYPAL_CLIENT_ID or not PAYPAL_CLIENT_SECRET:
        raise HTTPException(status_code=500, detail="Faltan credenciales de PayPal")

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PAYPAL_BASE_URL}/v1/oauth2/token",
            auth=(PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET),
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={"grant_type": "client_credentials"},
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=400, detail=f"Error OAuth PayPal: {response.text}")

    return response.json()["access_token"]

_PAYPAL_SIMULADO = not (PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET)

@router.post("/paypal/create-order")
async def crear_orden_paypal(payload: PayPalOrderCreate):
    if _PAYPAL_SIMULADO:
        order_id = f"SIMPP_{uuid.uuid4().hex[:16].upper()}"
        return {
            "id": order_id,
            "status": "CREATED",
            "simulated": True,
            "links": [
                {"rel": "approve", "href": f"https://sandbox.paypal.com/checkoutnow?token={order_id}", "method": "GET"},
                {"rel": "capture", "href": f"/payments/paypal/capture-order", "method": "POST"},
            ],
        }

    token = await _paypal_access_token()

    body = {
        "intent": "CAPTURE",
        "purchase_units": [
            {
                "amount": {
                    "currency_code": payload.currency,
                    "value": f"{payload.total:.2f}",
                }
            }
        ],
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PAYPAL_BASE_URL}/v2/checkout/orders",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=body,
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=400, detail=response.text)

    return response.json()

@router.post("/paypal/capture-order")
@router.post("/paypal/capture")
async def capturar_orden_paypal(payload: PayPalCaptureRequest):
    if _PAYPAL_SIMULADO:
        return {
            "id": payload.orderId,
            "status": "COMPLETED",
            "simulated": True,
            "purchase_units": [
                {
                    "payments": {
                        "captures": [
                            {
                                "id": f"CAP_{uuid.uuid4().hex[:12].upper()}",
                                "status": "COMPLETED",
                            }
                        ]
                    }
                }
            ],
        }

    token = await _paypal_access_token()

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PAYPAL_BASE_URL}/v2/checkout/orders/{payload.orderId}/capture",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=400, detail=response.text)

    return response.json()