import 'dart:io';

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  CAMBIAR A [true] CUANDO EL BACKEND ESTÉ LISTO             ║
/// ╚══════════════════════════════════════════════════════════════╝
const bool usarApiReal = true;

/// En Android emulator, `localhost` debe ser `10.0.2.2`
final String baseUrl = usarApiReal ? _backendBaseUrl() : 'http://localhost:8000';

String _backendBaseUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
