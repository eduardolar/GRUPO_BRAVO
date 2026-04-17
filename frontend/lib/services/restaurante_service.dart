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
}