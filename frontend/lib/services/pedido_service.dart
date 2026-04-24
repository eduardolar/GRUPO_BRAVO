import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pedido_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';
import 'http_client.dart';

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

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/pedidos'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'items': items,
          'tipoEntrega': tipoEntrega,
          'metodoPago': metodoPago,
          'total': total,
          'direccionEntrega': direccionEntrega,
          'mesaId': mesaId,
          'numeroMesa': numeroMesa,
          'notas': notas,
          'referenciaPago': referenciaPago,
          'estadoPago': estadoPago,
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
        headers: {'Accept': 'application/json'},
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

  static Future<void> agregarItemsPedido({
    required String pedidoId,
    required List<Map<String, dynamic>> items,
    required double totalExtra,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }

    // PATCH: reemplaza items y total con la lista completa acumulada
    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/$pedidoId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'items': items,
          'total': totalExtra,
        }),
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
  }) async {
    try {
      final response = await httpWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/pedidos'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'userId': '',
            'items': items,
            'tipoEntrega': 'Comer en el local',
            'metodoPago': 'Pendiente',
            'total': 0,
            'mesaId': mesaId,
            'notas': 'Pedido enviado por QR',
            'estadoPago': 'pendiente',
          }),
        ),
        retry: false,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on ApiException {
      return false;
    }
  }
  static Future<List<Pedido>> obtenerTodosLosPedidos() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.pedidos.map((m) => Pedido.fromMap(m)).toList();
    }

    // Llama al endpoint general de pedidos sin filtrar por usuario
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/pedidos'),
        headers: {'Accept': 'application/json'},
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
}
