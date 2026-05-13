// ============================================================================
// frontend/lib/services/super_admin_service.dart
// ----------------------------------------------------------------------------
// Cliente HTTP de endpoints reservados a super_admin: KPIs de la red,
// suspensión de sucursales, dashboards transversales.
// ============================================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_session.dart';
import 'http_client.dart';

/// Métodos exclusivos de super_admin que no existen en otros servicios.
class SuperAdminService {
  static Map<String, String> get _headers => AuthSession.headers();

  // ── KPIs globales de hoy ───────────────────────────────────────────────────

  /// Devuelve el mapa completo del endpoint /super-admin/kpis-hoy.
  /// Incluye: fecha, totales { ingresos_hoy, pedidos_hoy, ticket_medio,
  /// items_vendidos, pedidos_en_cocina, reservas_hoy, stock_bajo_total,
  /// cierres_pendientes, sucursales_abiertas, sucursales_total },
  /// por_sucursal [ { restaurante_id, nombre, ingresos_hoy, pedidos_hoy,
  ///   pedidos_en_cocina, abierta } ].
  static Future<Map<String, dynamic>> kpisHoy() async {
    final res = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/super-admin/kpis-hoy'),
        headers: _headers,
      ),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Suspender sucursal ─────────────────────────────────────────────────────

  /// Suspende la sucursal [id]. [motivo] es opcional.
  /// Devuelve { mensaje, restaurante_id, suspendido_at }.
  static Future<Map<String, dynamic>> suspenderRestaurante(
    String id, {
    String? motivo,
  }) async {
    final body = motivo != null ? {'motivo': motivo} : <String, dynamic>{};
    final res = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/super-admin/restaurantes/$id/suspender'),
        headers: _headers,
        body: jsonEncode(body),
      ),
      retry: false,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Reactivar sucursal ─────────────────────────────────────────────────────

  /// Reactiva la sucursal [id].
  /// Devuelve { mensaje, restaurante_id }.
  static Future<Map<String, dynamic>> reactivarRestaurante(String id) async {
    final res = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/super-admin/restaurantes/$id/reactivar'),
        headers: _headers,
        body: jsonEncode({}),
      ),
      retry: false,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Lista de sucursales con suspendidas ────────────────────────────────────

  /// Devuelve todas las sucursales, incluyendo las suspendidas.
  /// Cada item lleva { id, nombre, ..., activo, suspendido_at }.
  static Future<List<Map<String, dynamic>>> listarRestaurantes({
    bool incluirSuspendidos = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/restaurantes',
    ).replace(queryParameters: {
      'incluir_suspendidos': incluirSuspendidos.toString(),
    });

    final res = await httpWithRetry(
      () => http.get(uri, headers: _headers),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
    }
    throw toApiException(res.statusCode, decodeBody(res));
  }

  // ── Eliminar sucursal (hard-delete) ────────────────────────────────────────

  /// Elimina permanentemente la sucursal [id].
  /// Solo super_admin puede hacerlo (el backend valida el rol).
  static Future<void> eliminarRestaurante(String id) async {
    final res = await httpWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl/restaurantes/$id'),
        headers: _headers,
      ),
      retry: false,
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw toApiException(res.statusCode, decodeBody(res));
    }
  }
}
