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
