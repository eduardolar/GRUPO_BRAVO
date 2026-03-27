import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // Registrar usuario
  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'password_hash': contrasena,
        'telefono': telefono,
        'direccion': direccion,
        'rol': 'cliente',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Error al registrar');
    }
  }

  // Iniciar sesión
  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password_hash': contrasena}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Credenciales incorrectas');
    }
  }
}
