import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/restaurante_model.dart';
import 'api_config.dart'; //aqui se define la variable baseUrl con la URL de la API

class RestauranteService {
  Future<List<Restaurante>> obtenerTodos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/restaurantes'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((item) => Restaurante.fromJson(item)).toList();
      } else {
        throw Exception('Error al obtener restaurantes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Restaurante?> crearRestaurante({required String nombre, required String direccion}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/restaurantes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre, 'direccion': direccion}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Restaurante.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> editarRestaurante({required String id, required String nombre, required String direccion}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/restaurantes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre, 'direccion': direccion}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> eliminarRestaurante(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/restaurantes/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}