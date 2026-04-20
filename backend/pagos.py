import os
import uuid
from typing import List, Optional, Dict, Any

import httpx
import stripe
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv()

stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")

PAYPAL_CLIENT_ID = os.getenv("PAYPAL_CLIENT_ID", "")
PAYPAL_CLIENT_SECRET = os.getenv("PAYPAL_CLIENT_SECRET", "")
PAYPAL_BASE_URL = os.getenv("PAYPAL_BASE_URL", "https://api-m.sandbox.paypal.com")
ALLOWED_ORIGIN = os.getenv("ALLOWED_ORIGIN", "*")

app = FastAPI(title="Grupo Bravo API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[ALLOWED_ORIGIN] if ALLOWED_ORIGIN != "*" else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

PEDIDOS_DB: List[Dict[str, Any]] = []


class PedidoItem(BaseModel):
    producto_id: str
    nombre: str
    cantidad: int = Field(gt=0)
    precio: float = Field(ge=0)
    sin: Optional[List[str]] = None


class PedidoCreate(BaseModel):
    userId: str
    items: List[PedidoItem]
    tipoEntrega: str
    metodoPago: str
    total: float = Field(ge=0)
    direccionEntrega: Optional[str] = None
    mesaId: Optional[str] = None
    numeroMesa: Optional[str] = None
    notas: Optional[str] = ""
    referenciaPago: Optional[str] = None
    estadoPago: Optional[str] = "pendiente"


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


class PayPalOrderCreate(BaseModel):
    total: float = Field(gt=0)
    currency: str = "EUR"


class PayPalCaptureRequest(BaseModel):
    orderId: str


class PedidoResponse(BaseModel):
    id: str
    userId: str
    tipoEntrega: str
    metodoPago: str
    total: float
    estadoPago: str


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/pedidos", response_model=PedidoResponse)
def crear_pedido(payload: PedidoCreate):
    pedido_id = str(uuid.uuid4())

    pedido = {
        "id": pedido_id,
        "userId": payload.userId,
        "items": [item.model_dump() for item in payload.items],
        "tipoEntrega": payload.tipoEntrega,
        "metodoPago": payload.metodoPago,
        "total": payload.total,
        "direccionEntrega": payload.direccionEntrega,
        "mesaId": payload.mesaId,
        "numeroMesa": payload.numeroMesa,
        "notas": payload.notas,
        "referenciaPago": payload.referenciaPago,
        "estadoPago": payload.estadoPago or "pendiente",
    }

    PEDIDOS_DB.append(pedido)

    return {
        "id": pedido_id,
        "userId": payload.userId,
        "tipoEntrega": payload.tipoEntrega,
        "metodoPago": payload.metodoPago,
        "total": payload.total,
        "estadoPago": pedido["estadoPago"],
    }


@app.get("/pedidos")
def listar_pedidos():
    return PEDIDOS_DB


@app.post("/payments/stripe/create-intent")
def crear_payment_intent(payload: PaymentIntentCreate):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Falta STRIPE_SECRET_KEY")

    try:
        intent = stripe.PaymentIntent.create(
            amount=int(round(payload.amount * 100)),
            currency=payload.currency.lower(),
            automatic_payment_methods={"enabled": True},
        )
        return {
            "payment_intent_id": intent["id"],
            "client_secret": intent["client_secret"],
            "status": intent["status"],
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/payments/stripe/confirm")
def confirmar_payment_intent(payload: CardConfirmRequest):
    if not payload.clientSecret:
        raise HTTPException(status_code=400, detail="clientSecret requerido")

    if not payload.numeroTarjeta.strip():
        raise HTTPException(status_code=400, detail="Número de tarjeta requerido")

    if not payload.fechaExpiracion.strip():
        raise HTTPException(status_code=400, detail="Fecha de expiración requerida")

    if not payload.cvv.strip():
        raise HTTPException(status_code=400, detail="CVV requerido")

    if not payload.nombreTitular.strip():
        raise HTTPException(status_code=400, detail="Nombre del titular requerido")

    return {
        "success": True,
        "message": "Confirmación simulada en backend de desarrollo",
    }


@app.get("/payments/stripe/verify/{payment_intent_id}")
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


@app.post("/payments/google-pay/init")
def iniciar_google_pay(payload: GooglePayInitRequest):
    return {
        "success": True,
        "productId": "pedido_bravo",
        "purchaseToken": f"gpay_{uuid.uuid4().hex}",
        "amount": payload.total,
        "currency": "EUR",
        "message": "Inicio simulado de Google Pay para desarrollo",
    }


@app.post("/payments/google-pay/verify")
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

    data = response.json()
    return data["access_token"]


@app.post("/payments/paypal/create-order")
async def crear_orden_paypal(payload: PayPalOrderCreate):
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
        ]
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


@app.post("/payments/paypal/capture-order")
async def capturar_orden_paypal(payload: PayPalCaptureRequest):
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


@app.post("/payments/paypal/capture")
async def capturar_orden_paypal_alias(payload: PayPalCaptureRequest):
    return await capturar_orden_paypal(payload)