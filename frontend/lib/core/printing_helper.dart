/// Imprime la página actual cuando se ejecuta en web. En móvil/desktop
/// es un no-op: el usuario debe usar la opción Compartir / Imprimir del SO.
///
/// Esta es la fachada portátil; el comportamiento por plataforma se inyecta
/// con `import` condicional desde [printing_helper_io.dart] o
/// [printing_helper_web.dart] (ver final del fichero).
library;

import 'printing_helper_stub.dart'
    if (dart.library.html) 'printing_helper_web.dart';

/// Devuelve `true` si la plataforma soporta `printDocument()` (web).
bool get puedeImprimirNativo => kPuedeImprimir;

/// Lanza el diálogo de impresión de la plataforma (en web).
/// En móvil/desktop registra un debugPrint y no hace nada — el caller debe
/// caer a un mensaje "Usa Compartir > Imprimir" o capturar pantalla.
void printDocument() => printDocumentImpl();
