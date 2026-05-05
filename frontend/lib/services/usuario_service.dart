import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/usuario_model.dart';
import 'actor_context.dart';
import 'api_config.dart';
import 'auth_session.dart';

class UsuarioService {
  /// Cabeceras para peticiones que registran auditoría:
  /// añade `X-Actor` con el correo del usuario actualmente logueado y el
  /// `Authorization: Bearer ...` cuando hay sesión activa.
  static Map<String, String> _headersConActor() =>
      AuthSession.headers(extra: ActorContext.instance.headers);

  static Map<String, String> get _headersJson => AuthSession.headers();

  // 1. Obtener todos los usuarios
  Future<List<Usuario>> obtenerTodos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios'),
      headers: _headersJson,
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body
          .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al traer usuarios');
    }
  }

  // 2. Borrar un usuario
  Future<bool> eliminarUsuario(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: _headersConActor(),
    );
    return response.statusCode == 200;
  }

  // 3. Obtener solo administradores
  Future<List<Usuario>> obtenerAdmins() async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios?rol=admin'),
      headers: _headersJson,
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body
          .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al traer administradores');
    }
  }

  // 4. Obtener usuario administrador por id
  Future<Usuario> obtenerAdminPorId(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/$id?rol=admin'),
      headers: _headersJson,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Usuario.fromJson(data as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      throw Exception('Administrador no encontrado');
    } else {
      throw Exception('Error al obtener administrador');
    }
  }

  // 5. Cambiar el rol de un usuario
  Future<bool> cambiarRol(String id, String nuevoRol) async {
    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id/rol'),
      headers: _headersConActor(),
      body: jsonEncode({'rol': nuevoRol}),
    );
    return response.statusCode == 200;
  }

  // 6. Crear un usuario (panel admin)
  Future<bool> crearUsuario({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
    required String restauranteId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/'),
        headers: _headersConActor(),
        body: jsonEncode({
          'nombre': nombre,
          'correo': correo,
          'password': password,
          'rol': rol,
          'restaurante_id': restauranteId,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error al crear usuario: $e');
      return false;
    }
  }

  // 7. Editar campos de un usuario
  Future<bool> editarUsuario(
    String id, {
    String? nombre,
    String? correo,
    bool? activo,
  }) async {
    try {
      final body = <String, dynamic>{
        'nombre': ?nombre,
        'correo': ?correo,
        'activo': ?activo,
      };
      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/$id'),
        headers: _headersConActor(),
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error al editar usuario: $e');
      return false;
    }
  }

  // 8. Persistencia de Dirección y Coordenadas
  Future<bool> actualizarDireccion({
    required String userId,
    required String direccion,
    required double latitud,
    required double longitud,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/$userId'),
        headers: _headersConActor(),
        body: jsonEncode({
          'direccion': direccion,
          'latitud': latitud,
          'longitud': longitud,
        }),
      );

      if (response.statusCode == 200) return true;
      debugPrint('Error del servidor: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('Error al conectar con el backend: $e');
      return false;
    }
  }
}
