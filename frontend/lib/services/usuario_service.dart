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
      headers: {'Content-Type': 'application/json'},
    );
    return response.statusCode == 200;
  }

  // 3. Obtener solo administradores
  Future<List<Usuario>> obtenerAdmins() async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios?rol=admin'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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

  // 5. Cambiar el rol de un usuario (para gestionar el rol admin)
  Future<bool> cambiarRol(String id, String nuevoRol) async {
    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id/rol'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rol': nuevoRol}),
    );

    return response.statusCode == 200;
  }

  Future<bool> crearUsuario({
  required String nombre,
  required String correo,
  required String password,
  required String rol,
  required String restauranteId,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/usuarios/'), // La ruta POST de Python
      headers: {'Content-Type': 'application/json'},
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
    print('Error al crear usuario: $e');
    return false;
  } 
}

//  7. Persistencia de Dirección y Coordenadas ---
  Future<bool> actualizarDireccion({
    required String userId,
    required String direccion,
    required double latitud,
    required double longitud,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'direccion': direccion,
          'latitud': latitud,
          'longitud': longitud,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Error del servidor: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error al conectar con el backend: $e");
      return false;
    }
  }
}