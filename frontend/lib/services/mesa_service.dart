import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mesa_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class MesaService {
  /// Obtener todas las mesas del local
  static Future<List<Mesa>> obtenerMesas() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.from(MockData.mesas);
    }

    final response = await http.get(Uri.parse('$baseUrl/mesas'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Mesa.fromMap(m as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al obtener mesas');
    }
  }

  /// Validar código QR de una mesa
  static Future<Map<String, dynamic>> validarQrMesa({
    required String codigoQr,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final mesa = MockData.mesas.cast<Mesa?>().firstWhere(
        (m) => m!.codigoQr == codigoQr,
        orElse: () => null,
      );
      if (mesa == null) {
        throw Exception('QR no válido');
      }
      return {
        'mesa_id': mesa.id,
        'numero_mesa': mesa.numero,
        'estado': mesa.disponible ? 'disponible' : 'ocupada',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/mesas/validar-qr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'codigo_qr': codigoQr}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'QR no válido');
    }
  }
}
