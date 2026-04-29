import os
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

import httpx
import stripe
from bson import ObjectId
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, Field

from audit import registrar_pago
from database import coleccion_auditoria_pagos

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

class ApplePayInitRequest(BaseModel):
    total: float = Field(gt=0)
    currency: str = "EUR"
    country: str = "ES"

class GooglePayInitRequest(BaseModel):
    total: float = Field(gt=0)
    currency: str = "EUR"

class ConfirmPaymentIntentRequest(BaseModel):
    payment_intent_id: str
    payment_method_id: str

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
def crear_payment_intent(request: Request, payload: PaymentIntentCreate):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.create(
            amount=int(round(payload.amount * 100)),
            currency=payload.currency.lower(),
            automatic_payment_methods={"enabled": True},
        )
        registrar_pago(request, "stripe.intent_created", "stripe",
                       importe=payload.amount, moneda=payload.currency,
                       referencia=intent["id"], estado=intent["status"])
        return {
            "payment_intent_id": intent["id"],
            "client_secret": intent["client_secret"],
            "status": intent["status"],
        }
    except Exception as e:
        registrar_pago(request, "stripe.intent_created", "stripe",
                       importe=payload.amount, moneda=payload.currency,
                       estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/stripe/confirm")
@router.post("/card/confirm")
def confirmar_payment_intent(request: Request, payload: CardConfirmRequest):
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

    registrar_pago(request, "stripe.card_confirm", "stripe",
                   estado="simulado", detalle="Confirmación simulada en entorno de desarrollo")
    return {"success": True, "message": "Confirmación simulada en backend de desarrollo"}


@router.post("/apple-pay/init")
async def iniciar_apple_pay(request: Request, payload: ApplePayInitRequest):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.create(
            amount=int(round(payload.total * 100)),
            currency=payload.currency.lower(),
            automatic_payment_methods={"enabled": True},
            metadata={"platform": "apple_pay", "country": payload.country},
        )
        registrar_pago(request, "apple_pay.intent_created", "apple_pay",
                       importe=payload.total, moneda=payload.currency,
                       referencia=intent["id"], estado=intent["status"])
        return {
            "payment_intent_id": intent["id"],
            "client_secret": intent["client_secret"],
            "status": intent["status"],
        }
    except Exception as e:
        registrar_pago(request, "apple_pay.intent_created", "apple_pay",
                       importe=payload.total, moneda=payload.currency,
                       estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/apple-pay/confirm")
async def confirmar_apple_pay(request: Request, payload: ConfirmPaymentIntentRequest):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    if not payload.payment_intent_id.strip() or not payload.payment_method_id.strip():
        raise HTTPException(status_code=400, detail="payment_intent_id y payment_method_id son requeridos")
    try:
        intent = stripe.PaymentIntent.confirm(
            payload.payment_intent_id,
            payment_method=payload.payment_method_id,
        )
        registrar_pago(request, "apple_pay.confirmed", "apple_pay",
                       referencia=intent["id"], estado=intent["status"],
                       detalle=f"paid={intent['status'] == 'succeeded'}")
        return {
            "id": intent["id"],
            "status": intent["status"],
            "paid": intent["status"] == "succeeded",
        }
    except Exception as e:
        registrar_pago(request, "apple_pay.confirmed", "apple_pay",
                       referencia=payload.payment_intent_id,
                       estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/apple-pay/verify/{payment_intent_id}")
def verificar_apple_pay(request: Request, payment_intent_id: str):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id)
        paid = intent["status"] == "succeeded"
        registrar_pago(request, "apple_pay.verified", "apple_pay",
                       referencia=intent["id"], estado=intent["status"],
                       detalle=f"paid={paid}")
        return {
            "id": intent["id"],
            "status": intent["status"],
            "paid": paid,
            "apple_pay": intent["metadata"].get("platform") == "apple_pay",
        }
    except Exception as e:
        registrar_pago(request, "apple_pay.verified", "apple_pay",
                       referencia=payment_intent_id, estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/google-pay/init")
async def iniciar_google_pay(request: Request, payload: GooglePayInitRequest):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.create(
            amount=int(round(payload.total * 100)),
            currency=payload.currency.lower(),
            automatic_payment_methods={"enabled": True},
            metadata={"platform": "google_pay"},
        )
        registrar_pago(request, "google_pay.intent_created", "google_pay",
                       importe=payload.total, moneda=payload.currency,
                       referencia=intent["id"], estado=intent["status"])
        return {
            "payment_intent_id": intent["id"],
            "client_secret": intent["client_secret"],
            "status": intent["status"],
        }
    except Exception as e:
        registrar_pago(request, "google_pay.intent_created", "google_pay",
                       importe=payload.total, moneda=payload.currency,
                       estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/google-pay/confirm")
async def confirmar_google_pay(request: Request, payload: ConfirmPaymentIntentRequest):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    if not payload.payment_intent_id.strip() or not payload.payment_method_id.strip():
        raise HTTPException(status_code=400, detail="payment_intent_id y payment_method_id son requeridos")
    try:
        intent = stripe.PaymentIntent.confirm(
            payload.payment_intent_id,
            payment_method=payload.payment_method_id,
        )
        registrar_pago(request, "google_pay.confirmed", "google_pay",
                       referencia=intent["id"], estado=intent["status"],
                       detalle=f"paid={intent['status'] == 'succeeded'}")
        return {
            "id": intent["id"],
            "status": intent["status"],
            "paid": intent["status"] == "succeeded",
        }
    except Exception as e:
        registrar_pago(request, "google_pay.confirmed", "google_pay",
                       referencia=payload.payment_intent_id,
                       estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/google-pay/verify/{payment_intent_id}")
def verificar_google_pay(request: Request, payment_intent_id: str):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id)
        paid = intent["status"] == "succeeded"
        registrar_pago(request, "google_pay.verified", "google_pay",
                       referencia=intent["id"], estado=intent["status"],
                       detalle=f"paid={paid}")
        return {
            "id": intent["id"],
            "status": intent["status"],
            "paid": paid,
            "google_pay": intent["metadata"].get("platform") == "google_pay",
        }
    except Exception as e:
        registrar_pago(request, "google_pay.verified", "google_pay",
                       referencia=payment_intent_id, estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/stripe/verify/{payment_intent_id}")
@router.get("/card/verify/{payment_intent_id}")
def verificar_payment_intent(request: Request, payment_intent_id: str):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id)
        paid = intent["status"] == "succeeded"
        registrar_pago(request, "stripe.intent_verified", "stripe",
                       referencia=intent["id"], estado=intent["status"],
                       detalle=f"paid={paid}")
        return {
            "id": intent["id"],
            "status": intent["status"],
            "paid": paid,
        }
    except Exception as e:
        registrar_pago(request, "stripe.intent_verified", "stripe",
                       referencia=payment_intent_id, estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


# ── Stripe Checkout (web) ──────────────────────────────────────────────────────

@router.post("/stripe/create-checkout-session")
def crear_checkout_session(request: Request, payload: CheckoutSessionCreate):
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
        registrar_pago(request, "stripe.checkout_created", "stripe",
                       importe=payload.total, moneda=payload.currency,
                       referencia=session.id, estado="created")
        return {"session_id": session.id, "checkout_url": session.url}
    except Exception as e:
        registrar_pago(request, "stripe.checkout_created", "stripe",
                       importe=payload.total, moneda=payload.currency,
                       estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/stripe/verify-session/{session_id}")
def verificar_checkout_session(request: Request, session_id: str):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        registrar_pago(request, "stripe.checkout_verified", "stripe",
                       referencia=session.id, estado=session.payment_status,
                       detalle=f"paid={session.payment_status == 'paid'}")
        return {
            "session_id": session.id,
            "payment_status": session.payment_status,
            "paid": session.payment_status == "paid",
        }
    except Exception as e:
        registrar_pago(request, "stripe.checkout_verified", "stripe",
                       referencia=session_id, estado="error", detalle=str(e))
        raise HTTPException(status_code=400, detail=str(e))


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

def _paypal_simulado_order_response(order_id: str, total: float = 0.0, currency: str = "EUR") -> Dict[str, Any]:
    return {
        "id": order_id,
        "status": "CREATED",
        "purchase_units": [{"amount": {"currency_code": currency, "value": f"{total:.2f}"}}],
        "links": [{"href": f"https://www.sandbox.paypal.com/checkoutnow?token={order_id}", "rel": "approve", "method": "GET"}],
    }

def _paypal_simulado_capture_response(order_id: str, total: float = 0.0, currency: str = "EUR") -> Dict[str, Any]:
    return {
        "id": order_id,
        "status": "COMPLETED",
        "purchase_units": [{"payments": {"captures": [{"id": f"{order_id}-CAPTURE", "status": "COMPLETED", "amount": {"currency_code": currency, "value": f"{total:.2f}"}}]}}],
    }


@router.post("/paypal/create-order")
async def crear_orden_paypal(request: Request, payload: PayPalOrderCreate):
    if _PAYPAL_SIMULADO:
        order_id = str(uuid.uuid4())
        registrar_pago(request, "paypal.order_created", "paypal",
                       importe=payload.total, moneda=payload.currency,
                       referencia=order_id, estado="CREATED_SIMULADO")
        return _paypal_simulado_order_response(order_id, payload.total, payload.currency)

    token = await _paypal_access_token()
    body = {"intent": "CAPTURE", "purchase_units": [{"amount": {"currency_code": payload.currency, "value": f"{payload.total:.2f}"}}]}

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PAYPAL_BASE_URL}/v2/checkout/orders",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json=body,
        )

    if response.status_code >= 400:
        registrar_pago(request, "paypal.order_created", "paypal",
                       importe=payload.total, moneda=payload.currency,
                       estado="error", detalle=response.text)
        raise HTTPException(status_code=400, detail=response.text)

    data = response.json()
    registrar_pago(request, "paypal.order_created", "paypal",
                   importe=payload.total, moneda=payload.currency,
                   referencia=data.get("id"), estado=data.get("status", "CREATED"))
    return data


@router.get("/paypal/order/{order_id}")
async def obtener_orden_paypal(order_id: str):
    if _PAYPAL_SIMULADO:
        return _paypal_simulado_order_response(order_id)

    token = await _paypal_access_token()

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(
            f"{PAYPAL_BASE_URL}/v2/checkout/orders/{order_id}",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=400, detail=response.text)

    return response.json()


@router.post("/paypal/capture-order")
@router.post("/paypal/capture")
async def capturar_orden_paypal(request: Request, payload: PayPalCaptureRequest):
    if _PAYPAL_SIMULADO:
        registrar_pago(request, "paypal.order_captured", "paypal",
                       referencia=payload.orderId, estado="COMPLETED_SIMULADO")
        return _paypal_simulado_capture_response(payload.orderId)

    token = await _paypal_access_token()

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PAYPAL_BASE_URL}/v2/checkout/orders/{payload.orderId}/capture",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )

    if response.status_code >= 400:
        registrar_pago(request, "paypal.order_captured", "paypal",
                       referencia=payload.orderId, estado="error", detalle=response.text)
        raise HTTPException(status_code=400, detail=response.text)

    data = response.json()
    registrar_pago(request, "paypal.order_captured", "paypal",
                   referencia=data.get("id"), estado=data.get("status", "COMPLETED"))
    return data


@router.get("/paypal/capture/{order_id}")
async def capturar_orden_paypal_get(request: Request, order_id: str):
    if _PAYPAL_SIMULADO:
        registrar_pago(request, "paypal.order_captured", "paypal",
                       referencia=order_id, estado="COMPLETED_SIMULADO")
        return _paypal_simulado_capture_response(order_id)

    token = await _paypal_access_token()

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PAYPAL_BASE_URL}/v2/checkout/orders/{order_id}/capture",
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )

    if response.status_code >= 400:
        registrar_pago(request, "paypal.order_captured", "paypal",
                       referencia=order_id, estado="error", detalle=response.text)
        raise HTTPException(status_code=400, detail=response.text)

    data = response.json()
    registrar_pago(request, "paypal.order_captured", "paypal",
                   referencia=data.get("id"), estado=data.get("status", "COMPLETED"))
    return data


# ── Auditoría (admin) ──────────────────────────────────────────────────────────

@router.get("/audit")
def obtener_auditoria(
    proveedor: Optional[str] = Query(None),
    estado: Optional[str] = Query(None),
    desde: Optional[str] = Query(None, description="ISO 8601, ej: 2024-01-01T00:00:00"),
    hasta: Optional[str] = Query(None, description="ISO 8601, ej: 2024-12-31T23:59:59"),
    limite: int = Query(100, ge=1, le=500),
):
    filtro: Dict[str, Any] = {}
    if proveedor:
        filtro["proveedor"] = proveedor
    if estado:
        filtro["estado"] = estado
    if desde or hasta:
        filtro["fecha"] = {}
        if desde:
            filtro["fecha"]["$gte"] = desde
        if hasta:
            filtro["fecha"]["$lte"] = hasta

    eventos = coleccion_auditoria_pagos.find(filtro, {"_id": 0}).sort("fecha", -1).limit(limite)
    return list(eventos)
