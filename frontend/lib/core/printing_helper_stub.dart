import 'package:flutter/foundation.dart';

/// Implementación por defecto (móvil / desktop): la plataforma no expone
/// `window.print()`, así que el helper público cae a un mensaje en la UI
/// y el usuario imprime con la opción nativa del SO.
const bool kPuedeImprimir = false;

void printDocumentImpl() {
  debugPrint('printDocument(): no soportado en esta plataforma. '
      'Usa Compartir > Imprimir desde el menú del sistema.');
}
