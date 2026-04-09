import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';
import 'api_config.dart';

class UsuarioService {
  // 1. Obtener todos los usuarios
  Future<List<Usuario>> obtenerTodos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios'), // Esta ruta debe existir en Python
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Usuario.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al traer usuarios');
    }
  }

  // 2. Borrar un usuario
  Future<bool> eliminarUsuario(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: {'Content-Type': 'application/json'},
    );
    return response.statusCode == 200;
  }
}