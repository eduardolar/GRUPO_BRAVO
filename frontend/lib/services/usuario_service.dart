import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/usuario_model.dart';
import 'api_config.dart';
import 'auth_session.dart';
import 'http_client.dart';

class UsuarioService {
  /// Cabeceras para peticiones autenticadas. El backend identifica al actor
  /// por el JWT (`Authorization: Bearer ...`); ya no aceptamos `X-Actor`
  /// (eliminado por seguridad), por lo que tampoco lo enviamos desde aquí
  /// (CORS lo bloquearía y rompería el preflight).
  static Map<String, String> _headersConActor() => AuthSession.headers();

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

  // 6. Crear un empleado (panel admin)
  // No se envía password: el backend genera una y manda correo de activación.
  // No se envía restaurante_id: el backend lo fuerza por el token del admin.
  Future<Map<String, dynamic>> crearEmpleado({
    required String nombre,
    required String correo,
    required String rol,
    String? telefono,
  }) async {
    final body = <String, dynamic>{
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/'),
      headers: _headersConActor(),
      body: jsonEncode(body),
    );
    return {
      'statusCode': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  // 6b. Crear un usuario (panel admin — legacy, mantiene firma anterior)
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

  // 9. Reactivar un usuario suspendido
  Future<void> reactivarUsuario(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/$id/reactivar'),
      headers: _headersConActor(),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail']?.toString() ?? 'Error al reactivar usuario';
      throw Exception(detail);
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

  // 8. Persistencia de Dirección y Coordenadas (perfil propio del cliente)
  // Propaga el error del backend (ApiException) para que el caller pueda
  // mostrar el detail real al usuario en lugar de un fallo silencioso.
  Future<bool> actualizarDireccion({
    required String direccion,
    required double latitud,
    required double longitud,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/clientes/me'),
      headers: _headersConActor(),
      body: jsonEncode({
        'direccion': direccion,
        'latitud': latitud,
        'longitud': longitud,
      }),
    );
    if (response.statusCode == 200) return true;
    throw toApiException(response.statusCode, decodeBody(response));
  }
}
