import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mesa_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';
import 'http_client.dart';

class MesaService {
  static Future<List<Mesa>> obtenerMesas() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.from(MockData.mesas);
    }

    final response = await httpWithRetry(
      () => http.get(Uri.parse('$baseUrl/mesas')),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Mesa.fromMap(m as Map<String, dynamic>)).toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

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
        throw const ApiException(404, 'QR no válido');
      }
      return {
        'mesaId': mesa.id,
        'numeroMesa': mesa.numero,
        'estado': mesa.disponible ? 'disponible' : 'ocupada',
      };
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/mesas/validar-qr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigoQr': codigoQr}),
      ),
      retry: false,
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Mesa> crearMesa({
    required int numero,
    required int capacidad,
    required String ubicacion,
    required String codigoQr,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      final nueva = Mesa(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        numero: numero,
        capacidad: capacidad,
        ubicacion: ubicacion,
        disponible: true,
        codigoQr: codigoQr,
      );
      MockData.mesas.add(nueva);
      return nueva;
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/mesas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'numero': numero,
          'capacidad': capacidad,
          'ubicacion': ubicacion,
          'codigoQr': codigoQr,
        }),
      ),
      retry: false,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Mesa.fromMap(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> marcarMesaOcupada(String mesaId) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      final index = MockData.mesas.indexWhere((m) => m.id == mesaId);
      if (index != -1) {
        MockData.mesas[index] = MockData.mesas[index].copyWith(disponible: false);
      }
      return;
    }

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/mesas/$mesaId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'disponible': false}),
      ),
      retry: false,
    );

    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> marcarMesaLibre(String mesaId) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      final index = MockData.mesas.indexWhere((m) => m.id == mesaId);
      if (index != -1) {
        MockData.mesas[index] =
            MockData.mesas[index].copyWith(disponible: true);
      }
      return;
    }

    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/mesas/$mesaId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'disponible': true}),
      ),
      retry: false,
    );

    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }
}
