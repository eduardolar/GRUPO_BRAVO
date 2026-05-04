import 'package:flutter/foundation.dart' show kIsWeb;
import 'platform_helper.dart';

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  CAMBIAR A [true] CUANDO EL BACKEND ESTÉ LISTO             ║
/// ╚══════════════════════════════════════════════════════════════╝
const bool usarApiReal = true;

/// URL base del backend.
/// En producción, pasa la URL completa mediante dart-define:
///   flutter run --dart-define=API_BASE_URL=https://api.grupobravo.com
/// Sin el flag, usa la URL de desarrollo local según plataforma.
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get baseUrl {
  if (_apiBaseUrlOverride.isNotEmpty) return '$_apiBaseUrlOverride/api/v1';
  const port = 8000;
  if (kIsWeb) return 'http://localhost:$port/api/v1';
  if (isAndroid) return 'http://10.0.2.2:$port/api/v1';
  return 'http://localhost:$port/api/v1';
}

/// Stripe publishable key.
/// Para cambiar entre entornos (test/producción) usa --dart-define:
///   flutter run --dart-define=STRIPE_PK=pk_live_...
///
/// Si no se pasa el flag, se usa la clave de test por defecto.
const String stripePublishableKey = String.fromEnvironment(
  'STRIPE_PK',
  defaultValue: 'pk_test_51TOw8VAyHSG5POXsDtUQMKCwyJ5SUdFWc7eyNMsrIq4NsxbhX6kaZLSOZb3B1K0mncosU5pg3bWLqPP4XDFzuB4u00p4DnMegH',
);
