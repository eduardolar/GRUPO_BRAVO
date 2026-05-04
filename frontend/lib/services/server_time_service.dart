import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'http_client.dart';

/// Mantiene un offset entre el reloj del dispositivo y la hora del servidor.
///
/// Se usa para que los cronómetros (p. ej. tiempo transcurrido de un pedido)
/// se calculen contra la hora real del backend, no contra la del tablet de
/// cocina (que puede tener mal puesto el reloj o un timezone raro).
///
/// Singleton: el offset es proceso-wide. Cualquier pantalla que necesite la
/// hora del servidor lee [now]; las pantallas que tengan un poll regular
/// pueden llamar a [sincronizar] cada N polls para corregir la deriva.
class ServerTimeService {
  ServerTimeService._();
  static final ServerTimeService instance = ServerTimeService._();

  /// Diferencia (server - cliente). Si el offset es +5 min significa que el
  /// servidor va 5 minutos por delante del cliente.
  Duration _offset = Duration.zero;
  DateTime? _ultimaSync;

  Duration get offset => _offset;
  DateTime? get ultimaSync => _ultimaSync;

  /// Hora actual según el servidor (en UTC).
  DateTime get now => DateTime.now().toUtc().add(_offset);

  /// Llama al endpoint `/pedidos/server-time` y recalcula el offset.
  /// Devuelve `true` si la sincronización fue exitosa.
  Future<bool> sincronizar() async {
    try {
      final tEnvio = DateTime.now().toUtc();
      final response = await httpWithRetry(
        () => http.get(
          Uri.parse('$baseUrl/pedidos/server-time'),
          headers: {'Accept': 'application/json'},
        ),
      );
      final tRecibido = DateTime.now().toUtc();

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final serverIso = body['server_time']?.toString();
      if (serverIso == null) return false;

      final serverTime = DateTime.parse(serverIso).toUtc();
      // Compensa la latencia: asume que el servidor respondió a mitad del RTT.
      final tMitad = tEnvio.add(
        Duration(microseconds: tRecibido.difference(tEnvio).inMicroseconds ~/ 2),
      );
      _offset = serverTime.difference(tMitad);
      _ultimaSync = tRecibido;
      return true;
    } catch (e) {
      debugPrint('ServerTimeService.sincronizar fallo: $e');
      return false;
    }
  }
}
