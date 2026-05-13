// ============================================================================
// frontend/lib/core/url_helper.dart
// ----------------------------------------------------------------------------
// Helper para manipular la URL del navegador. Mismo patrón de "conditional
// import" que printing_helper: la implementación cambia según plataforma.
//
// Caso de uso real: cuando Stripe/PayPal redirigen tras un pago, llegan a
//   https://app.grupobravo.com/?stripe_session=cs_xxx
// La query string queda pegada en la URL para siempre. Cada F5 dispara
// "procesar redirect" de nuevo (y muestra "pedido confirmado" otra vez,
// o vuelve a llamar a Stripe). Por eso, justo después de procesar el
// redirect, llamamos a `limpiarQueryParams()` para dejar la URL en `/`.
// ============================================================================
/// Borra los `query parameters` de la URL del navegador (solo en web).
///
/// En móvil/desktop es un no-op: los flujos de redirect-OAuth o redirect-Stripe
/// no aplican porque siempre vuelven con un deep link que el OS gestiona.
///
/// Por qué existe: cuando Stripe Checkout o PayPal redirigen a la web con
/// `?stripe_session=...`, el query param queda permanentemente en la barra
/// de direcciones. Cada recarga (F5) vuelve a parsearlo y dispara la
/// pantalla de "pedido confirmado" otra vez. Llamar [limpiarQueryParams]
/// tras procesar el redirect deja la URL en `/`.
library;

import 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart';

void limpiarQueryParams() => limpiarQueryParamsImpl();
