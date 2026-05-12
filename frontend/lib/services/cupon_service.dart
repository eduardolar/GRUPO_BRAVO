import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/cupon_model.dart';
import 'api_config.dart';
import 'http_client.dart';
import 'auth_session.dart';

/// Valor centinela para distinguir "parámetro no pasado" de "null explícito"
/// en [CuponService.crear].
const Object _noProvidedSentinel = Object();

class CuponService {
  static Map<String, String> get _headers => AuthSession.headers();

  static Future<List<Cupon>> listar({bool soloActivos = false}) async {
    final uri = Uri.parse(
      '$baseUrl/cupones${soloActivos ? '?solo_activos=true' : ''}',
    );

    final res = await httpWithRetry(() => http.get(uri, headers: _headers));
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((j) => Cupon.fromJson(j))
          .toList();
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  static Future<Cupon> crear({
    required String codigo,
    required String tipo,
    required double valor,
    String descripcion = '',
    int? usosMaximos,
    String? fechaInicio,
    String? fechaFin,
    Object? restauranteId = _noProvidedSentinel,
  }) async {
    final body = <String, dynamic>{
      'codigo': codigo,
      'tipo': tipo,
      'valor': valor,
      'descripcion': descripcion,
      'usos_maximos': usosMaximos,
      if (fechaInicio != null && fechaInicio.isNotEmpty)
        'fecha_inicio': fechaInicio,
      if (fechaFin != null && fechaFin.isNotEmpty) 'fecha_fin': fechaFin,
    };

    if (restauranteId != _noProvidedSentinel) {
      body['restaurante_id'] = restauranteId;
    }

    final res = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/cupones'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return Cupon.fromJson(jsonDecode(res.body));
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  static Future<Cupon> editar(
    String id, {
    String? descripcion,
    double? valor,
    String? tipo,
    int? usosMaximos,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final body = <String, dynamic>{
      'descripcion': ?descripcion,
      'valor': ?valor,
      'tipo': ?tipo,
      'usos_maximos': ?usosMaximos,
      'fecha_inicio': ?fechaInicio,
      'fecha_fin': ?fechaFin,
    };

    final res = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/cupones/$id'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (res.statusCode == 200) return Cupon.fromJson(jsonDecode(res.body));
    throw toApiException(res.statusCode, decodeBody(res));
  }

  static Future<void> toggleActivo(String id, bool activo) async {
    final res = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/cupones/$id/activo?activo=$activo'),
        headers: _headers,
      ),
      retry: false,
    );

    if (res.statusCode != 200) {
      throw toApiException(res.statusCode, decodeBody(res));
    }
  }

  static Future<void> eliminar(String id) async {
    final res = await httpWithRetry(
      () => http.delete(Uri.parse('$baseUrl/cupones/$id'), headers: _headers),
      retry: false,
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw toApiException(res.statusCode, decodeBody(res));
    }
  }

  static Future<Map<String, dynamic>> validar({
    required String codigo,
    required double subtotal,
    double costeEnvio = 0.0,
    String? restauranteId,
  }) async {
    final body = <String, dynamic>{
      'codigo': codigo.trim().toUpperCase(),
      'subtotal': subtotal,
      'coste_envio': costeEnvio,
      'restaurante_id': ?restauranteId,
    };

    final res = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/cupones/validar'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  static Future<void> registrarUso(
    String cuponId, {
    String? restauranteId,
  }) async {
    final uri = Uri.parse('$baseUrl/cupones/$cuponId/usar');

    final body = <String, dynamic>{
      'restaurante_id': ?restauranteId,
    };

    final res = await httpWithRetry(
      () => http.post(
        uri,
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (res.statusCode != 200) {
      throw toApiException(res.statusCode, decodeBody(res));
    }
  }

  static Future<void> enviarNotificacionMasiva({
    required String cuponId,
    required String tipoFiltro,
    String? restauranteId,
  }) async {
    final url = Uri.parse('$baseUrl/cupones/enviar-masivo');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cuponId': cuponId,
          'filtro': tipoFiltro,
          'restauranteId': restauranteId,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw errorData['message'] ?? 'Error al procesar el envío masivo';
      }
    } catch (e) {
      throw 'No se pudo conectar con el servidor: $e';
    }
  }
}
