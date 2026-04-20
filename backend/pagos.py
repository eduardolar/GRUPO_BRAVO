from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import requests
import stripe
from google.oauth2 import service_account
from google.auth.transport.requests import Request

app = FastAPI()

# ---------- CONFIG ----------
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY", "")
stripe.api_key = STRIPE_SECRET_KEY

PAYPAL_CLIENT_ID = os.getenv("PAYPAL_CLIENT_ID", "")
PAYPAL_CLIENT_SECRET = os.getenv("PAYPAL_CLIENT_SECRET", "")
PAYPAL_BASE_URL = os.getenv("PAYPAL_BASE_URL", "https://api-m.sandbox.paypal.com")

GOOGLE_SERVICE_ACCOUNT_FILE = os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE", "service-account.json")
GOOGLE_PACKAGE_NAME = os.getenv("GOOGLE_PACKAGE_NAME", "com.tu.paquete.app")

# ---------- MODELOS ----------
class CardPaymentIntentIn(BaseModel):
    amount: float
    currency: str = "eur"

class PayPalCreateOrderIn(BaseModel):
    total: float
    currency: str = "EUR"

class PayPalCaptureOrderIn(BaseModel):
    order_id: str

class GooglePlayVerifyIn(BaseModel):
    product_id: str
    purchase_token: str
    package_name: str | None = None

# ---------- HELPERS ----------
def paypal_access_token() -> str:
    url = f"{PAYPAL_BASE_URL}/v1/oauth2/token"
    response = requests.post(
        url,
        auth=(PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET),
        data={"grant_type": "client_credentials"},
        headers={"Accept": "application/json"},
        timeout=30,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"PayPal auth error: {response.text}")
    return response.json()["access_token"]

def google_access_token() -> str:
    creds = service_account.Credentials.from_service_account_file(
        GOOGLE_SERVICE_ACCOUNT_FILE,
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    creds.refresh(Request())
    return creds.token

# ---------- TARJETA / STRIPE ----------
@app.post("/payments/card/create-intent")
def create_card_payment_intent(payload: CardPaymentIntentIn):
    try:
        amount_cents = int(round(payload.amount * 100))
        intent = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency=payload.currency.lower(),
            automatic_payment_methods={"enabled": True},
        )
        return {
            "payment_intent_id": intent["id"],
            "client_secret": intent["client_secret"],
            "status": intent["status"],
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Stripe error: {str(e)}")

@app.get("/payments/card/verify/{payment_intent_id}")
def verify_card_payment(payment_intent_id: str):
    try:
        intent = stripe.PaymentIntent.retrieve(payment_intent_id)
        return {
            "id": intent["id"],
            "status": intent["status"],
            "amount": intent["amount"],
            "currency": intent["currency"],
            "paid": intent["status"] == "succeeded",
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Stripe verify error: {str(e)}")

# ---------- PAYPAL ----------
@app.post("/payments/paypal/create-order")
def create_paypal_order(payload: PayPalCreateOrderIn):
    token = paypal_access_token()
    url = f"{PAYPAL_BASE_URL}/v2/checkout/orders"
    body = {
        "intent": "CAPTURE",
        "purchase_units": [
            {
                "amount": {
                    "currency_code": payload.currency,
                    "value": f"{payload.total:.2f}"
                }
            }
        ]
    }
    response = requests.post(
        url,
        json=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        timeout=30,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"PayPal create order error: {response.text}")
    data = response.json()
    return {
        "id": data.get("id"),
        "status": data.get("status"),
        "links": data.get("links", []),
    }

@app.post("/payments/paypal/capture-order")
def capture_paypal_order(payload: PayPalCaptureOrderIn):
    token = paypal_access_token()
    url = f"{PAYPAL_BASE_URL}/v2/checkout/orders/{payload.order_id}/capture"
    response = requests.post(
        url,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        timeout=30,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"PayPal capture error: {response.text}")
    data = response.json()
    return {
        "id": data.get("id"),
        "status": data.get("status"),
        "purchase_units": data.get("purchase_units", []),
    }

# ---------- GOOGLE PLAY ----------
@app.post("/payments/google-play/verify")
def verify_google_play_purchase(payload: GooglePlayVerifyIn):
    token = google_access_token()
    package_name = payload.package_name or GOOGLE_PACKAGE_NAME
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/"
        f"applications/{package_name}/purchases/products/"
        f"{payload.product_id}/tokens/{payload.purchase_token}"
    )

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        timeout=30,
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"Google Play verify error: {response.text}")

    data = response.json()
    purchase_state = data.get("purchaseState")
    acknowledgement_state = data.get("acknowledgementState")

    return {
        "valid": purchase_state == 0,
        "orderId": data.get("orderId"),
        "productId": data.get("productId"),
        "purchaseToken": data.get("purchaseToken"),
        "purchaseState": purchase_state,
        "acknowledgementState": acknowledgement_state,
        "raw": data,
    }