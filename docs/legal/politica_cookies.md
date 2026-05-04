# Política de Cookies — Restaurante Bravo

**Última actualización**: 4 de mayo de 2026
**Versión**: 1.0

> ⚠ **Aviso al equipo**: este texto es una **plantilla base**. Antes de
> publicarlo en producción **debe revisarse por un asesor jurídico** y
> verificarse que el inventario de cookies refleja exactamente lo que el
> sitio web y la app instalan en el dispositivo.

---

## 1. ¿Qué es una cookie?

Una cookie es un pequeño fichero de texto que un sitio web instala en tu
navegador o aplicación para almacenar información (preferencias,
identificadores de sesión, etc.). En la app móvil hablamos también de
"identificadores locales" (`SharedPreferences`, `flutter_secure_storage`,
LocalStorage de WebView), que cumplen una función equivalente.

## 2. Tipos de cookies que usamos

### 2.1 Cookies / identificadores **técnicos** (necesarios)

No requieren consentimiento. Se usan para que la Plataforma funcione.

| Identificador | Origen | Finalidad | Duración |
| --- | --- | --- | --- |
| `usuario_sesion` (SharedPreferences) | Propia | Mantener tu sesión iniciada | Hasta cerrar sesión |
| Token JWT (memoria) | Propia | Autenticación contra el backend | Hasta cerrar sesión o expiración (60 min) |
| Cookie de sesión Stripe | Stripe | Procesar el pago en el SDK | Sesión |

### 2.2 Cookies **funcionales**

Permiten recordar preferencias (tema, idioma, dirección por defecto). No
requieren consentimiento si son estrictamente necesarias para una
funcionalidad solicitada por el usuario.

| Identificador | Origen | Finalidad | Duración |
| --- | --- | --- | --- |
| `direccion_default` | Propia | Recordar la dirección de entrega | Persistente |
| `tema_preferido` | Propia | Recordar el tema (claro/oscuro) | Persistente |

### 2.3 Cookies **analíticas**

`<Aún no se usan. Si en el futuro se incorpora un proveedor de analítica
(Google Analytics, Sentry, Plausible, Matomo…), añadir aquí su tabla y
mostrar el banner de consentimiento.>`

### 2.4 Cookies **publicitarias / de marketing**

`<No usamos cookies de marketing. Si en el futuro se incorporan, será sólo
con consentimiento explícito y previo.>`

## 3. Cookies de terceros

| Proveedor | Política de cookies |
| --- | --- |
| Stripe | https://stripe.com/cookie-settings |
| PayPal | https://www.paypal.com/es/webapps/mpp/ua/cookie-full |
| Apple Pay | https://www.apple.com/legal/privacy/ |
| Google Pay | https://policies.google.com/technologies/cookies |

## 4. ¿Cómo gestionar las cookies?

### 4.1 En la versión web

La primera vez que entras se muestra un banner con tres opciones:

- **Aceptar todas**.
- **Rechazar las no necesarias**.
- **Configurar** (panel granular por categorías).

Puedes cambiar tu elección en cualquier momento desde el enlace
"Preferencias de cookies" del pie de página.

### 4.2 En la app móvil

Las cookies/identificadores técnicos son imprescindibles para usar la
app. Puedes borrar todos los datos locales desde:

- Ajustes del dispositivo → Aplicaciones → Restaurante Bravo →
  Almacenamiento → "Borrar datos".
- O desinstalando la aplicación.

### 4.3 En el navegador

La mayoría de navegadores permiten controlar las cookies desde sus
preferencias:

- [Chrome](https://support.google.com/chrome/answer/95647)
- [Firefox](https://support.mozilla.org/es/kb/proteccion-antirrastreo-mejorada-en-firefox-para-)
- [Safari](https://support.apple.com/es-es/HT201265)
- [Edge](https://support.microsoft.com/es-es/microsoft-edge)

## 5. Consecuencias de bloquear las cookies técnicas

Si bloqueas las cookies técnicas, no podrás iniciar sesión, mantener tu
carrito ni completar pedidos. Bloquear las funcionales sólo implica
perder ciertas comodidades (recordar la dirección, el tema, etc.).

## 6. Modificaciones

Esta política puede actualizarse para reflejar cambios técnicos o
legales. La fecha al inicio del documento indica la última revisión.

## 7. Contacto

- 📧 privacidad@grupobravo.com
