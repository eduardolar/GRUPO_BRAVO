import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/mock_data.dart';
import 'api_config.dart';

class AuthService {
  /// Iniciar sesión
  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      final usuario = MockData.usuarios.firstWhere(
        (u) => u.email == correo && u.contrasena == contrasena,
        orElse: () => throw Exception('Credenciales incorrectas'),
      );
      return usuario.toJson();
    }

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

  /// Registrar usuario
  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      final existe = MockData.usuarios.any((u) => u.email == correo);
      if (existe) {
        throw Exception('Ya existe un usuario con ese correo');
      }
      final nuevoId = 'u_${DateTime.now().millisecondsSinceEpoch}';
      return {
        'id': nuevoId,
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'direccion': direccion,
      };
    }

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

  /// Actualizar perfil
  static Future<bool> actualizarPerfil({
    required String userId,
    required String nombre,
    required String email,
    required String telefono,
    required String direccion,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': email,
        'telefono': telefono,
        'direccion': direccion,
      }),
    );
    return response.statusCode == 200;
  }

  /// Ver perfil de usuario
  static Future<Map<String, dynamic>> verPerfil({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final usuario = MockData.usuarios.firstWhere(
        (u) => u.id == userId,
        orElse: () => throw Exception('Usuario no encontrado'),
      );
      return usuario.toJson();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Error al obtener el perfil');
    }
  }

  /// Eliminar perfil
  static Future<bool> eliminarPerfil({required String userId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/usuarios/$userId'),
      headers: {'Content-Type': 'application/json'},
    );
    return response.statusCode == 200;
  }

  /// Eliminar cuenta de usuario
  static Future<bool> eliminarCuenta({required String userId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    final response = await http.delete(Uri.parse('$baseUrl/usuarios/$userId'));
    return response.statusCode == 200;
  }
}
