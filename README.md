# Grupo Bravo — Restaurante Bravo

Sistema de comandas, reservas, pagos y gestión multi-restaurante.

- **Backend**: FastAPI + MongoDB.
- **Frontend**: Flutter (Android/iOS/web/desktop).
- **Pagos**: Stripe (con webhook firmado) y PayPal.

## Requisitos previos

- Python 3.11+
- Flutter 3.27+
- (Opcional) Docker y Docker Compose para levantar la pila completa
- Una cuenta de MongoDB Atlas o un MongoDB local
- Una cuenta de Stripe en modo test
- Un correo SMTP (recomendado: app password de Gmail)

## Configuración del entorno

1. Copia `backend/.env.example` a `backend/.env` y rellénalo:

   - `MONGO_URI` — cadena de conexión Atlas o local.
   - `JWT_SECRET_KEY` — genera con `python -c "import secrets;print(secrets.token_urlsafe(48))"`.
   - `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.
   - `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`, `MAIL_SERVER`, `MAIL_PORT`.
   - `ALLOWED_ORIGINS` — lista de orígenes web autorizados (CORS).

2. **Importante**: nunca subas `backend/.env` al repositorio.

## Backend

```bash
cd backend
pip install -r requirements.txt
python -m scripts.init_indexes      # crea índices en Mongo (idempotente)
py -m uvicorn main:app --reload
```

API documentada en `http://127.0.0.1:8000/docs`.

## Frontend

```bash
cd frontend
flutter pub get
# Apuntar a un backend remoto:
flutter run -d chrome --dart-define=API_BASE_URL=https://api.tu-dominio.com
# O sin override (usa http://127.0.0.1:8000):
flutter run -d chrome
```

## Docker Compose

```bash
# Define MONGO_INITDB_ROOT_USERNAME y MONGO_INITDB_ROOT_PASSWORD en un .env raíz
docker compose up --build
```

Levanta backend + Mongo con healthchecks. El puerto de Mongo está enlazado a
`127.0.0.1` por seguridad.

## Webhook de Stripe

En el dashboard de Stripe, configura el endpoint:

```
POST https://tu-dominio.com/api/v1/payments/stripe/webhook
```

Eventos mínimos: `payment_intent.succeeded`, `payment_intent.payment_failed`,
`payment_intent.canceled`. Copia la `whsec_...` resultante en
`STRIPE_WEBHOOK_SECRET` del `.env`.

## Tests y CI

Antes de pushear, reproduce la pipeline en local:

```bash
bash scripts/check-ci.sh        # Linux/Mac
pwsh scripts/check-ci.ps1       # Windows
```

Si algún paso falla, el script imprime el comando exacto que lo arregla.
Para más detalle ve a [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
cd backend
pytest                          # tests del backend (66+)

cd ../frontend
flutter test                    # tests del frontend (100+)
```

## Estructura del proyecto

- `backend/` — API FastAPI, módulos: `routes/`, `pagos.py`, `tickets.py`,
  `security.py`, `audit*.py`, `database.py`, `config.py`.
- `frontend/` — App Flutter, módulos: `lib/screens/`, `lib/services/`,
  `lib/providers/`, `lib/components/`.
- `mongodb/` — Datos semilla (no usar en producción; contiene placeholders).
- `docs/` — Documentación funcional y de arquitectura.

## RGPD

- Política de privacidad: `https://grupobravo.com/privacidad`.
- Endpoints de derechos ARSULIPO:
  - `GET /api/v1/usuarios/{id}/mis-datos` — exportación.
  - `DELETE /api/v1/usuarios/{id}/mi-cuenta` — supresión (anonimización).

## Licencia

Ver [LICENSE](LICENSE).
