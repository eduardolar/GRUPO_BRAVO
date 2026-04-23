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

/// Stripe publishable key.
/// Para cambiar entre entornos (test/producción) usa --dart-define:
///   flutter run --dart-define=STRIPE_PK=pk_live_...
///
/// Si no se pasa el flag, se usa la clave de test por defecto.
const String stripePublishableKey = String.fromEnvironment(
  'STRIPE_PK',
  defaultValue: 'pk_test_51TOw8VAyHSG5POXsDtUQMKCwyJ5SUdFWc7eyNMsrIq4NsxbhX6kaZLSOZb3B1K0mncosU5pg3bWLqPP4XDFzuB4u00p4DnMegH',
);
