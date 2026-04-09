import 'package:flutter/foundation.dart' show kIsWeb;
import 'platform_helper.dart';

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  CAMBIAR A [true] CUANDO EL BACKEND ESTÉ LISTO             ║
/// ╚══════════════════════════════════════════════════════════════╝
const bool usarApiReal = true;

/// URL base del backend.
/// - Web → localhost
/// - Android emulador → 10.0.2.2 (alias del host)
/// - Resto → localhost
String get baseUrl {
  const port = 8000;
  if (kIsWeb) return 'http://localhost:$port';
  if (isAndroid) return 'http://10.0.2.2:$port';
  return 'http://localhost:$port';
}
