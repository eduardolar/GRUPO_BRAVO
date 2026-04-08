import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pedido_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class PedidoService {
  /// Crear un nuevo pedido
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
        'mesa_id': mesaId,
        'numero_mesa': numeroMesa,
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usuario_id': userId,
        'items': items,
        'tipo_entrega': tipoEntrega,
        'metodo_pago': metodoPago,
        'total': total,
        'direccion_entrega': direccionEntrega,
        'mesa_id': mesaId,
        'numero_mesa': numeroMesa,
        'notas': notas,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Error al crear pedido');
    }
  }

  /// Obtener historial de pedidos de un usuario
  static Future<List<Pedido>> obtenerHistorialPedidos({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.pedidos.map((m) => Pedido.fromMap(m)).toList();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/pedidos?usuario_id=$userId'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => Pedido.fromMap(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al obtener historial');
    }
  }
}
