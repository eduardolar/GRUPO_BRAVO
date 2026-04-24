import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario_model.dart';
import 'api_config.dart';
import 'http_client.dart';

class UsuarioService {
  Future<List<Usuario>> obtenerTodos() async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/usuarios'),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body
          .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  Future<bool> eliminarUsuario(String id) async {
    final response = await httpWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl/usuarios/$id'),
        headers: {'Content-Type': 'application/json'},
      ),
      retry: false,
    );
    return response.statusCode == 200;
  }

  Future<List<Usuario>> obtenerAdmins() async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/usuarios?rol=admin'),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(response.body);
      return body
          .map((item) => Usuario.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  Future<Usuario> obtenerAdminPorId(String id) async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/usuarios/$id?rol=admin'),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Usuario.fromJson(data as Map<String, dynamic>);
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  Future<bool> cambiarRol(String id, String nuevoRol) async {
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/usuarios/$id/rol'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rol': nuevoRol}),
      ),
      retry: false,
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
      final response = await httpWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/usuarios/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nombre': nombre,
            'correo': correo,
            'password': password,
            'rol': rol,
            'restauranteId': restauranteId,
          }),
        ),
        retry: false,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on ApiException {
      return false;
    }
  }
}
