import 'dart:io';

/// Guarda [bytes] en el directorio temporal del sistema y devuelve la ruta.
Future<String> descargarBytes(List<int> bytes, String filename) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
