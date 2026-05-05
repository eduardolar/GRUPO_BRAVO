import 'package:web/web.dart' as web;

/// Implementación para Flutter web: dispara el diálogo de impresión del
/// navegador. La página debe estar montada con un layout limpio (fondo
/// blanco, QR grande, datos de la mesa) — eso lo hace [QrImprimibleScreen].
const bool kPuedeImprimir = true;

void printDocumentImpl() {
  web.window.print();
}
