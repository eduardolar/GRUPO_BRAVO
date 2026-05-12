// dart:html sigue siendo la forma más sencilla de disparar una descarga en
// navegador con Blob + AnchorElement. La alternativa `package:web` requiere
// dependencia extra y migración de API; cambiamos cuando sea estrictamente
// obligatorio.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Dispara la descarga de [bytes] en el navegador con el nombre [filename].
Future<String> descargarBytes(List<int> bytes, String filename) async {
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
