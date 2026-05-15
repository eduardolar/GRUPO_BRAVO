// ============================================================================
// frontend/lib/services/cierre_caja_service.dart
// ----------------------------------------------------------------------------
// Cliente HTTP de cierres de caja (Z report) por turno.
// Operaciones: abrir, cerrar, reabrir (con motivo, auditado), listar.
// ============================================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_session.dart';
import 'http_client.dart';

/// Servicio para la gestión de cierres de caja por turno.
///
/// Todos los métodos devuelven el JSON parseado del backend tal cual,
/// sin mapear a modelo propio, para no duplicar el contrato.
class CierreCajaService {
  static Map<String, String> get _headers => AuthSession.headers();

  // ── Abrir turno ────────────────────────────────────────────────────────────

  /// Abre un cierre de caja para el [turno] dado.
  /// [fecha] es opcional: si se omite, el backend usa la fecha actual.
  /// Lanza [ApiException] con statusCode 409 si ya existe un cierre abierto
  /// o cerrado para esa sucursal+fecha+turno.
  static Future<Map<String, dynamic>> abrirCierre({
    required String turno,
    String? fecha,
  }) async {
    final body = <String, dynamic>{'turno': turno};
    if (fecha != null) body['fecha'] = fecha;

    final res = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/cierres-caja/abrir'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      // No reintentar escrituras para no crear duplicados
      retry: false,
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Cerrar turno ───────────────────────────────────────────────────────────

  /// Cierra el turno identificado por [id], declarando [efectivoDeclarado].
  /// Lanza [ApiException] con statusCode 409 si hay pedidos pendientes en el turno.
  static Future<Map<String, dynamic>> cerrarCierre(
    String id,
    double efectivoDeclarado,
  ) async {
    final res = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/cierres-caja/$id/cerrar'),
        headers: _headers,
        body: jsonEncode({'efectivo_declarado': efectivoDeclarado}),
      ),
      retry: false,
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Reabrir turno ──────────────────────────────────────────────────────────

  /// Reabre un cierre cerrado, requiriendo un [motivo] de mínimo 10 caracteres.
  /// Queda registrado en el log de auditoría del documento de cierre.
  static Future<Map<String, dynamic>> reabrirCierre(
    String id,
    String motivo,
  ) async {
    final res = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/cierres-caja/$id/reabrir'),
        headers: _headers,
        body: jsonEncode({'motivo': motivo}),
      ),
      retry: false,
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Listar cierres ─────────────────────────────────────────────────────────

  /// Devuelve la lista de cierres filtrada por los parámetros indicados.
  /// El backend los ordena por fecha desc y turno (comida→cena).
  static Future<List<Map<String, dynamic>>> listar({
    String? fecha,
    String? turno,
    String? estado,
    String? fechaDesde,
    String? fechaHasta,
    /// Solo super_admin: filtra por sucursal. El admin normal no lo necesita
    /// porque el backend ya lo restringe por el restaurante del token.
    String? restauranteId,
  }) async {
    final params = <String, String>{};
    if (fecha != null) params['fecha'] = fecha;
    if (turno != null) params['turno'] = turno;
    if (estado != null) params['estado'] = estado;
    if (fechaDesde != null) params['fecha_desde'] = fechaDesde;
    if (fechaHasta != null) params['fecha_hasta'] = fechaHasta;
    if (restauranteId != null) params['restaurante_id'] = restauranteId;

    final uri = Uri.parse(
      '$baseUrl/cierres-caja',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await httpWithRetry(
      () => http.get(uri, headers: _headers),
    );

    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .cast<Map<String, dynamic>>();
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Obtener cierre por ID ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> obtener(String id) async {
    final res = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/cierres-caja/$id'),
        headers: _headers,
      ),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Cierre abierto actual ──────────────────────────────────────────────────

  /// Devuelve el cierre abierto del [turno] para hoy, o null si no existe (404).
  /// Cualquier otro error se propaga normalmente.
  static Future<Map<String, dynamic>?> abiertoActual(String turno) async {
    final res = await httpWithRetry(
      () => http.get(
        Uri.parse(
          '$baseUrl/cierres-caja/abierto-actual?turno=$turno',
        ),
        headers: _headers,
      ),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    // 404 significa "no hay turno abierto" — no es un error, devolvemos null
    if (res.statusCode == 404) return null;
    throw toApiException(res.statusCode, decodeBody(res));
  }
}
