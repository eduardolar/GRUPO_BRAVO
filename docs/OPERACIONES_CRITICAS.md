# Operaciones críticas pendientes (acción humana)

Este documento recoge las tareas del informe de auditoría que **no se
pueden automatizar desde el código** porque requieren acceder a paneles
externos o tomar decisiones operativas. Sigue los pasos en el orden
recomendado.

> Orden sugerido:
> 1. Hacer privado el repo
> 2. Rotar credenciales
> 3. Limpiar histórico de Git
> 4. Re-publicar como público (si procede)
> 5. Configurar webhook de Stripe en producción

---

## 1. Hacer privado el repositorio de GitHub

Mientras se completa la limpieza del `.env` filtrado.

```bash
gh repo edit eduardolar/GRUPO_BRAVO --visibility private --accept-visibility-change-consequences
```

> Si no tienes `gh` instalado: https://cli.github.com/

Manual: en `https://github.com/eduardolar/GRUPO_BRAVO/settings`
→ Danger Zone → "Change repository visibility" → Private.

---

## 2. Rotar credenciales filtradas

Las claves expuestas en `backend/.env` y/o en el histórico deben
considerarse comprometidas. **Rotar todas las que aparezcan, aunque
sean de modo test.**

### 2.1 MongoDB Atlas

1. https://cloud.mongodb.com/ → tu proyecto.
2. Database Access → usuario `dam_grupo_bravo` → "Edit" → "Edit Password" →
   genera una nueva contraseña fuerte.
3. Copia la nueva URI a `backend/.env` (`MONGO_URI=...`).
4. Network Access → revisa la IP allowlist y elimina entradas que ya no
   uses. En producción, evita `0.0.0.0/0`.
5. Considera **borrar el usuario antiguo** y crear uno nuevo con un nombre
   distinto, por trazabilidad.

### 2.2 Gmail (App Password)

1. https://myaccount.google.com/security
2. Verificación en dos pasos → Contraseñas de aplicación.
3. **Revoca** la app-password que aparezca como "Restaurante Bravo"
   (la que filtró: `sfgl yrgp pkub bhvj`).
4. Crea una nueva → cópiala a `MAIL_PASSWORD` en `backend/.env`.
5. Considera usar una cuenta **dedicada** (no personal) para el SMTP de
   producción.

### 2.3 Stripe

1. https://dashboard.stripe.com/apikeys
2. Modo **Test**: pulsa "Roll" en la Secret key (`sk_test_...`).
3. Modo **Live** (cuando publiques): genera la clave live y guárdala en
   un secret manager — nunca en `.env` versionado.
4. Copia la nueva clave a `STRIPE_SECRET_KEY` en `backend/.env`.

### 2.4 PayPal (cuando se active)

1. https://developer.paypal.com/dashboard/applications
2. Generar nuevo `Client Secret` para la aplicación de Restaurante Bravo.
3. Copiarlo a `PAYPAL_CLIENT_SECRET` en `backend/.env`.

### 2.5 JWT secret

1. Generar nuevo secreto:

   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(48))"
   ```

2. Pegar en `JWT_SECRET_KEY` del `.env`. **Cambiar este valor invalida
   todos los tokens en circulación** y obliga a los usuarios a iniciar
   sesión otra vez (efecto deseado tras una filtración).

---

## 3. Limpiar el histórico de Git

> ⚠ Reescribe el historial. Coordina con el equipo antes.

### 3.1 Backup

```bash
# Clonado completo a un ZIP por seguridad
git clone --mirror git@github.com:eduardolar/GRUPO_BRAVO.git GRUPO_BRAVO-backup-$(date +%F).git
```

### 3.2 Instalar git-filter-repo

```bash
pip install git-filter-repo
# o:  brew install git-filter-repo
# o:  choco install git-filter-repo
```

### 3.3 Ejecutar la purga

```bash
# Dry-run (no toca nada):
bash scripts/purgar_secretos_git.sh

# Aplicar (reescribe + pide confirmación):
bash scripts/purgar_secretos_git.sh --apply
```

### 3.4 Verificar

```bash
# .env no debe aparecer en ningún commit:
git log --all --pretty=oneline -- .env
git rev-list --all | xargs -I{} git ls-tree -r {} | grep '\.env$' || echo OK
```

### 3.5 Push forzado

```bash
git remote add origin git@github.com:eduardolar/GRUPO_BRAVO.git
git push --force --all
git push --force --tags
```

### 3.6 Comunicación al equipo

Cualquiera con un clon antiguo debe ejecutar:

```bash
git fetch --all
git reset --hard origin/<rama>
```

---

## 4. Volver a hacer público (opcional)

Una vez verificado que no quedan secretos en el histórico:

```bash
gh repo edit eduardolar/GRUPO_BRAVO --visibility public --accept-visibility-change-consequences
```

Considera dejarlo privado de manera permanente si el proyecto va a
manejar datos personales reales.

---

## 5. Configurar el webhook de Stripe en producción

El backend ya expone `POST /api/v1/payments/stripe/webhook` con
verificación de firma. Falta registrarlo en Stripe.

### 5.1 Registrar el endpoint

1. https://dashboard.stripe.com/webhooks → "Add endpoint".
2. URL del endpoint: `https://api.tu-dominio.com/api/v1/payments/stripe/webhook`
3. Eventos a escuchar (mínimo):
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `payment_intent.canceled`

### 5.2 Copiar el `whsec_...`

Stripe te muestra el "Signing secret" del endpoint (empieza por
`whsec_`). Guárdalo en `backend/.env`:

```
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxxxxxxx
```

Reinicia el backend para que `pagos.py` lo cargue.

### 5.3 Probar el webhook

Con la CLI de Stripe (`stripe listen`) puedes redirigir eventos al
backend local en desarrollo:

```bash
stripe listen --forward-to localhost:8000/api/v1/payments/stripe/webhook
stripe trigger payment_intent.succeeded
```

### 5.4 Asegurar el endpoint en producción

- HTTPS obligatorio.
- Dejar el endpoint **público** (Stripe debe poder llegar) pero con
  verificación de firma activa: cualquier petición sin Stripe-Signature
  válida se rechaza con 400.
- Considera limitar el rate limit del webhook si lo abusan.

---

## 6. Checklist final

- [ ] Repo en privado.
- [ ] MongoDB Atlas: contraseña rotada, allowlist revisada.
- [ ] Gmail app-password rotada.
- [ ] Stripe `sk_test_*` rotada.
- [ ] PayPal Client Secret regenerado (cuando se active).
- [ ] `JWT_SECRET_KEY` regenerado.
- [ ] `git-filter-repo` ejecutado y push --force completado.
- [ ] Equipo informado y con clones actualizados.
- [ ] `.env` ya no aparece en `git log --all --name-only -- .env`.
- [ ] Webhook de Stripe configurado en el dashboard con `whsec_*`
      en `STRIPE_WEBHOOK_SECRET`.
- [ ] Probado un `payment_intent.succeeded` real → pedido marcado como
      `pagado` por el webhook (no por el cliente).
- [ ] Documentos de `docs/legal/` revisados por asesor jurídico y
      publicados en `https://grupobravo.com/privacidad`.
- [ ] (Opcional) Repo de nuevo público si procede.
