import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'http_client.dart';
import 'auth_session.dart';

/// Servicio para los avisos de falta de stock.
/// Backend: POST/GET /api/v1/avisos-falta
class AvisoFaltaService {
  /// Crea un aviso de falta.
  /// [nombre] — nombre del ingrediente (obligatorio).
  /// [ingredienteId] — id del ingrediente en BD (opcional).
  /// [notas] — texto libre del trabajador (opcional).
  static Future<Map<String, dynamic>> crear({
    required String nombre,
    String? ingredienteId,
    String? notas,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'id': 'mock_${DateTime.now().millisecondsSinceEpoch}',
        'ingredienteNombre': nombre,
        'estado': 'pendiente',
      };
    }

    final body = <String, dynamic>{'ingredienteNombre': nombre};
    if (ingredienteId != null && ingredienteId.isNotEmpty) {
      body['ingredienteId'] = ingredienteId;
    }
    if (notas != null && notas.isNotEmpty) {
      body['notas'] = notas;
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/avisos-falta'),
        headers: AuthSession.headers(),
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decodeBody(response));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Lista los avisos de falta.
  /// [estado] — filtro opcional: 'pendiente' | 'atendido'.
  static Future<List<Map<String, dynamic>>> listar({String? estado}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return [];
    }

    final params = <String, String>{};
    if (estado != null && estado.isNotEmpty) params['estado'] = estado;

    final uri = Uri.parse(
      '$baseUrl/avisos-falta',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await httpWithRetry(
      () => http.get(uri, headers: AuthSession.headers()),
    );

    if (response.statusCode == 200) {
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is List) return List<Map<String, dynamic>>.from(raw);
      return [];
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Marca un aviso como atendido.
  /// [notasAdmin] — nota opcional del administrador.
  static Future<void> marcarAtendido(String id, {String? notasAdmin}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    final body = <String, dynamic>{'estado': 'atendido'};
    if (notasAdmin != null && notasAdmin.isNotEmpty) {
      body['notasAdmin'] = notasAdmin;
    }

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/avisos-falta/$id'),
        headers: AuthSession.headers(),
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }
}
