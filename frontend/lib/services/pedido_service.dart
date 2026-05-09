import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/pedido_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';
import 'http_client.dart';
import 'auth_session.dart';

class PedidoService {
  static Future<Map<String, dynamic>> crearPedido({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String tipoEntrega,
    required String metodoPago,
    required double total,
    String? direccionEntrega,
    String? mesaId,
    int? numeroMesa,
    String? notas,
    String? referenciaPago,
    required String estadoPago,
    String? restauranteId,
    String? idempotencyKey,
    bool prioritario = false,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 600));
      final nuevoPedidoId =
          '#${(MockData.pedidos.length + 1).toString().padLeft(3, '0')}';
      final ahora = DateTime.now();
      final fecha =
          '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';

      return {
        'id': nuevoPedidoId,
        'fecha': fecha,
        'total': total,
        'estado': 'En preparación',
        'items': items.length,
        'mesaId': mesaId,
        'numeroMesa': numeroMesa,
        'referenciaPago': referenciaPago,
        'estadoPago': estadoPago,
      };
    }

    final extraHeaders = <String, String>{'Accept': 'application/json'};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      extraHeaders['Idempotency-Key'] = idempotencyKey;
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/pedidos'),
        headers: AuthSession.headers(extra: extraHeaders),
        body: jsonEncode({
          'userId': userId,
          'items': items,
          'tipoEntrega': tipoEntrega,
          'metodoPago': metodoPago,
          'direccionEntrega': direccionEntrega,
          'mesaId': mesaId,
          'numeroMesa': numeroMesa,
          'notas': notas,
          'referenciaPago': referenciaPago,
          'estadoPago': estadoPago,
          'restauranteId': ?restauranteId,
          if (prioritario) 'prioritario': true,
        }),
      ),
      retry: false,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decodeBody(response));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<List<Pedido>> obtenerHistorialPedidos({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.pedidos.map((m) => Pedido.fromMap(m)).toList();
    }

    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/pedidos?userId=$userId'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => Pedido.fromMap(json as Map<String, dynamic>))
          .toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Reemplaza items y total del pedido. Si pasas [version], el backend
  /// aplica concurrencia optimista: si tu version está desfasada → 409.
  /// Devuelve la respuesta del backend (con la nueva `version` incrementada).
  static Future<Map<String, dynamic>> agregarItemsPedido({
    required String pedidoId,
    required List<Map<String, dynamic>> items,
    required double totalExtra,
    int? version,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return {'updated': true, if (version != null) 'version': version + 1};
    }

    final body = <String, dynamic>{
      'items': items,
      'total': totalExtra,
      'version': ?version,
    };
    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<Map<String, dynamic>?> obtenerPedidoActivoPorMesa(
    String mesaId,
  ) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return null;
    }

    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/pedidos?mesaId=$mesaId'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );

    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body);
      if (raw is List && raw.isNotEmpty) {
        return Map<String, dynamic>.from(raw.first as Map);
      }
      if (raw is Map<String, dynamic>) return raw;
      return null;
    }
    if (response.statusCode == 404) return null;
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> cerrarPedido({
    required String pedidoId,
    required String metodoPago,
    String? idempotencyKey,
    double? descuento,
    double? propina,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    final extraHeaders = <String, String>{'Accept': 'application/json'};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      // El header se envía siempre; si el backend aún no lo soporta lo ignora.
      extraHeaders['Idempotency-Key'] = idempotencyKey;
    }

    final body = <String, dynamic>{
      'estadoPago': 'pagado',
      'estado': 'entregado',
      'metodoPago': metodoPago,
    };
    if (descuento != null && descuento > 0) body['descuento'] = descuento;
    if (propina != null && propina > 0) body['propina'] = propina;

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId'),
        headers: AuthSession.headers(extra: extraHeaders),
        body: jsonEncode(body),
      ),
      retry: false,
    );

    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<bool> enviarPedidoPorQR({
    required String mesaId,
    required List<dynamic> items,
    String? restauranteId,
  }) async {
    try {
      final response = await httpWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/pedidos'),
          headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
          body: jsonEncode({
            'userId': '',
            'items': items,
            'tipoEntrega': 'Comer en el local',
            'metodoPago': 'Pendiente',
            'total': 0,
            'mesaId': mesaId,
            'notas': 'Pedido enviado por QR',
            'estadoPago': 'pendiente',
            'restauranteId': ?restauranteId,
          }),
        ),
        retry: false,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on ApiException {
      return false;
    }
  }

  static Future<void> actualizarEstadoPedido({
    required String pedidoId,
    required String estado,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId/estado'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
        body: jsonEncode({'estado': estado}),
      ),
      retry: false,
    );

    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  /// Devuelve los KPIs del turno del camarero autenticado: total cobrado,
  /// pedidos cobrados, mesas atendidas, propinas, descuentos, cancelados.
  /// Sin parámetros = "hoy desde medianoche". Útil para la pantalla "Mi turno".
  static Future<Map<String, dynamic>> obtenerMiTurno({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return {
        'totalCobrado': 0.0,
        'pedidosCobrados': 0,
        'mesasAtendidas': 0,
        'totalPropinas': 0.0,
        'totalDescuentos': 0.0,
        'pedidosCancelados': 0,
      };
    }
    final params = <String, String>{};
    if (desde != null) params['desde'] = desde.toUtc().toIso8601String();
    if (hasta != null) params['hasta'] = hasta.toUtc().toIso8601String();

    final uri = Uri.parse(
      '$baseUrl/pedidos/mi-turno',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await httpWithRetry(
      () => http.get(
        uri,
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(decodeBody(response));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Transfiere la responsabilidad del pedido a otro camarero (cambio de
  /// turno). Solo el responsable actual o admin pueden hacerlo.
  static Future<void> transferirPedido({
    required String pedidoId,
    required String nuevoResponsableSub,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return;
    }
    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId/transferir'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
        body: jsonEncode({'nuevoResponsableSub': nuevoResponsableSub}),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  /// Devuelve la lista mínima de camareros (id, nombre, correo) activos en
  /// la sucursal del actor. Pensado para el selector de transferencia.
  static Future<List<Map<String, dynamic>>> listarCamarerosDisponibles() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return [];
    }
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/pedidos/camareros-disponibles'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Mueve un pedido a otra mesa. Libera la mesa origen y ocupa la destino.
  /// El pedido debe estar en un estado activo (no entregado/cancelado).
  static Future<void> moverPedidoAOtraMesa({
    required String pedidoId,
    required String nuevaMesaId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 250));
      return;
    }
    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId/mover-mesa'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
        body: jsonEncode({'nuevaMesaId': nuevaMesaId}),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  /// Cancela un pedido enviando [motivoCancelacion] al backend.
  ///
  /// El backend exige que [motivoCancelacion] sea un string no vacío cuando
  /// el campo `estado` lleva el valor `"cancelado"`. Si falta, devuelve 422.
  static Future<void> cancelarPedido({
    required String pedidoId,
    required String motivoCancelacion,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
        body: jsonEncode({
          'estado': 'cancelado',
          'motivo_cancelacion': motivoCancelacion.trim(),
        }),
      ),
      retry: false,
    );

    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  /// Marca un item de un pedido como hecho/no hecho.
  ///
  /// Pasa [itemId] (UUID estable asignado por el backend) cuando esté
  /// disponible. Si el pedido es legacy y no tiene `item_id` en BD, pasa
  /// [itemIndex] como fallback y el método llamará a la URL deprecada
  /// `/items/{idx}/hecho-por-indice`.
  ///
  /// El backend devuelve `todosHechos: true` cuando todos los items están
  /// completados; en ese caso el propio backend mueve el pedido a `listo`.
  static Future<Map<String, dynamic>> marcarItemHecho({
    required String pedidoId,
    String? itemId,
    int? itemIndex,
    required bool hecho,
  }) async {
    assert(
      itemId != null || itemIndex != null,
      'marcarItemHecho requiere itemId o itemIndex',
    );

    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return {'updated': true, 'hecho': hecho, 'todosHechos': false};
    }

    final url = itemId != null
        ? '$baseUrl/pedidos/$pedidoId/items/$itemId/hecho'
        : '$baseUrl/pedidos/$pedidoId/items/$itemIndex/hecho-por-indice';

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse(url),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
        body: jsonEncode({'hecho': hecho}),
      ),
      retry: false,
    );

    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<Pedido> obtenerPedido(String pedidoId) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final mock = MockData.pedidos.firstWhere(
        (m) => m['id'] == pedidoId,
        orElse: () => MockData.pedidos.first,
      );
      return Pedido.fromMap(mock);
    }

    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/pedidos/$pedidoId'),
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );

    if (response.statusCode == 200) {
      return Pedido.fromMap(decodeBody(response));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<List<Pedido>> obtenerTodosLosPedidos({
    String? restauranteId,
    String? estado,
    List<String>? estados,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int? limit,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      var pedidos = MockData.pedidos.map((m) => Pedido.fromMap(m)).toList();
      // Prioriza el filtro múltiple sobre el singular.
      if (estados != null && estados.isNotEmpty) {
        pedidos = pedidos.where((p) => estados.contains(p.estado)).toList();
      } else if (estado != null) {
        pedidos = pedidos.where((p) => p.estado == estado).toList();
      }
      return pedidos;
    }

    final params = <String, String>{};
    if (restauranteId != null && restauranteId.isNotEmpty) {
      params['restauranteId'] = restauranteId;
    }
    // `estados` (CSV) tiene prioridad; si está presente, no enviamos `estado`
    // para evitar confusión en el backend (este ya prioriza `estados` también).
    if (estados != null && estados.isNotEmpty) {
      params['estados'] = estados.join(',');
    } else if (estado != null) {
      params['estado'] = estado;
    }
    // Filtros temporales: el backend extiende las fechas a inicio/fin de día.
    if (fechaDesde != null) {
      params['fecha_desde'] = fechaDesde.toIso8601String().substring(0, 10);
    }
    if (fechaHasta != null) {
      params['fecha_hasta'] = fechaHasta.toIso8601String().substring(0, 10);
    }
    // Salvaguarda: limita el número de pedidos devueltos para no bloquear la UI.
    if (limit != null) {
      params['limit'] = limit.toString();
    }
    final uri = Uri.parse(
      '$baseUrl/pedidos',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await httpWithRetry(
      () => http.get(
        uri,
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => Pedido.fromMap(json as Map<String, dynamic>))
          .toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Llama a GET /api/v1/pedidos/resumen y devuelve el JSON parseado.
  /// El backend aplica aislamiento por sucursal automáticamente para admin
  /// (super_admin ve todos).  [restauranteId] es opcional: si el token ya
  /// identifica la sucursal, el backend lo ignora.
  static Future<Map<String, dynamic>> obtenerResumenContabilidad({
    required DateTime fechaDesde,
    required DateTime fechaHasta,
    String? restauranteId,
  }) async {
    final params = <String, String>{
      'fecha_desde': fechaDesde.toIso8601String().substring(0, 10),
      'fecha_hasta': fechaHasta.toIso8601String().substring(0, 10),
    };
    if (restauranteId != null && restauranteId.isNotEmpty) {
      params['restauranteId'] = restauranteId;
    }
    final uri = Uri.parse(
      '$baseUrl/pedidos/resumen',
    ).replace(queryParameters: params);

    final response = await httpWithRetry(
      () => http.get(
        uri,
        headers: AuthSession.headers(extra: {'Accept': 'application/json'}),
      ),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Llama a GET /api/v1/pedidos/exportar?formato=csv y devuelve los bytes
  /// crudos del CSV.  El caller decide si guarda a disco (móvil/desktop) o
  /// dispara una descarga en el navegador (web).
  /// Lanza [ApiException] con status 400 si el rango supera 90 días.
  static Future<Uint8List> exportarContabilidadCsv({
    required DateTime fechaDesde,
    required DateTime fechaHasta,
    String? restauranteId,
  }) async {
    final params = <String, String>{
      'fecha_desde': fechaDesde.toIso8601String().substring(0, 10),
      'fecha_hasta': fechaHasta.toIso8601String().substring(0, 10),
      'formato': 'csv',
    };
    if (restauranteId != null && restauranteId.isNotEmpty) {
      params['restauranteId'] = restauranteId;
    }
    final uri = Uri.parse(
      '$baseUrl/pedidos/exportar',
    ).replace(queryParameters: params);

    // No reintentar: la exportación puede ser costosa en el backend.
    final response = await httpWithRetry(
      () => http.get(
        uri,
        headers: AuthSession.headers(
          extra: {'Accept': 'text/csv, application/json'},
          json: false,
        ),
      ),
      retry: false,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }
}
