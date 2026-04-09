import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';
import 'api_config.dart';

class UsuarioService {
  final Map<String, String> _headers = {'Content-Type': 'application/json'};

  // 1. Obtener todos los usuarios
  Future<List<Usuario>> obtenerTodos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body
          .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al traer usuarios: ${response.statusCode}');
    }
  }

  // 2. Obtener usuarios filtrados por rol
  Future<List<Usuario>> obtenerPorRol(String rol) async {
    final uri = Uri.parse(
      '$baseUrl/usuarios',
    ).replace(queryParameters: {'rol': rol});

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body
          .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        'Error al traer usuarios con rol $rol: ${response.statusCode}',
      );
    }
  }

  // 3. Obtener administradores
  Future<List<Usuario>> obtenerAdmins() async {
    return obtenerPorRol('admin');
  }

  // 4. Obtener trabajadores
  Future<List<Usuario>> obtenerTrabajadores() async {
    return obtenerPorRol('trabajador');
  }

  // 5. Obtener clientes
  Future<List<Usuario>> obtenerClientes() async {
    return obtenerPorRol('cliente');
  }

  // 6. Obtener usuario por id
  Future<Usuario> obtenerPorId(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Usuario.fromJson(data as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      throw Exception('Usuario no encontrado');
    } else {
      throw Exception('Error al obtener usuario: ${response.statusCode}');
    }
  }

  // 7. Obtener usuario por id filtrando por rol
  Future<Usuario> obtenerPorIdYRol(String id, String rol) async {
    final uri = Uri.parse(
      '$baseUrl/usuarios/$id',
    ).replace(queryParameters: {'rol': rol});

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Usuario.fromJson(data as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      throw Exception('Usuario no encontrado o no coincide con el rol');
    } else {
      throw Exception('Error al obtener usuario: ${response.statusCode}');
    }
  }

  // 8. Actualizar el rol de un usuario
  Future<bool> actualizarRol(String id, String nuevoRol) async {
    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id/rol'),
      headers: _headers,
      body: jsonEncode({'rol': nuevoRol}),
    );

    return response.statusCode == 200;
  }

  // 9. Eliminar usuario
  Future<bool> eliminarUsuario(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: _headers,
    );

    return response.statusCode == 200;
  }
}
