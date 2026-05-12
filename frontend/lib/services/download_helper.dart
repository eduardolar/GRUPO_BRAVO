// Exporta la implementación correcta según la plataforma.
// En web usa dart:html para disparar la descarga en el navegador.
// En móvil/desktop usa dart:io para guardar en el directorio temporal.
export 'download_helper_io.dart'
    if (dart.library.html) 'download_helper_web.dart';
