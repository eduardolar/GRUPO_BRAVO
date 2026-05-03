import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurante_model.dart';
import 'api_config.dart';
import 'http_client.dart';

class RestauranteService {
  Future<List<Restaurante>> obtenerTodos() async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/restaurantes'),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Restaurante.fromJson(item)).toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  Future<Restaurante?> crearRestaurante({
    required String nombre,
    required String direccion,
  }) async {
    try {
      final response = await httpWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/restaurantes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'nombre': nombre, 'direccion': direccion}),
        ),
        retry: false,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Restaurante.fromJson(jsonDecode(response.body));
      }
      return null;
    } on ApiException {
      return null;
    }
  }

  Future<bool> editarRestaurante({
    required String id,
    required String nombre,
    required String direccion,
    String? horarioApertura,
    String? horarioCierre,
  }) async {
    try {
      final body = <String, dynamic>{
        'nombre': nombre,
        'direccion': direccion,
      };
      if (horarioApertura != null) body['horario_apertura'] = horarioApertura;
      if (horarioCierre != null) body['horario_cierre'] = horarioCierre;

      final response = await httpWithRetry(
        () => http.put(
          Uri.parse('$baseUrl/restaurantes/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        retry: false,
      );
      return response.statusCode == 200;
    } on ApiException {
      return false;
    }
  }

  Future<bool> eliminarRestaurante(String id) async {
    try {
      final response = await httpWithRetry(
        () => http.delete(
          Uri.parse('$baseUrl/restaurantes/$id'),
          headers: {'Content-Type': 'application/json'},
        ),
        retry: false,
      );
      return response.statusCode == 200;
    } on ApiException {
      return false;
    }
  }
}
