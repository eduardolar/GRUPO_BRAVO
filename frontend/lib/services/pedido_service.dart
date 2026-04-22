import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pedido_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

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

    final response = await http.post(
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
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['detail'] ?? 'Error al crear pedido');
    }
  }

  static Future<List<Pedido>> obtenerHistorialPedidos({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.pedidos.map((m) => Pedido.fromMap(m)).toList();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/pedidos?userId=$userId'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => Pedido.fromMap(json as Map<String, dynamic>))
          .toList();
    } else {
      final data = _decodeBody(response);
      throw Exception(data['detail'] ?? 'Error al obtener historial');
    }
  }

  static Future<bool> enviarPedidoPorQR({
    required String mesaId,
    required List<dynamic> items,
  }) async {
    try {
      final response = await http.post(
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
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }
}
