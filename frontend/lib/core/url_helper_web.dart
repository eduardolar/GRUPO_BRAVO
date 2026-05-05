import 'package:web/web.dart' as web;

/// Implementación para Flutter web. Usa `history.replaceState` para borrar
/// los `?query=...` de la barra de direcciones SIN navegar (no añade entrada
/// al historial, no recarga la página).
///
/// Tras esto, un F5 ya no vuelve a parsear el query antiguo, así que
/// flujos tipo Stripe-redirect no se disparan dos veces.
void limpiarQueryParamsImpl() {
  final loc = web.window.location;
  // Mantenemos pathname y hash; eliminamos solo el "?...".
  final destino = '${loc.pathname}${loc.hash}';
  web.window.history.replaceState(null, '', destino);
}
