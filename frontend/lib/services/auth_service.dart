import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/mock_data.dart';
import 'api_config.dart';
import 'http_client.dart';

class AuthService {
  // MODIFICADO: Ahora el login puede devolver un aviso de "requires_2fa"
  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      final usuario = MockData.usuarios.firstWhere(
        (u) => u.email == correo && u.contrasena == contrasena,
        orElse: () => throw const ApiException(401, 'Credenciales incorrectas'),
      );
      return usuario.toJson();
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo, 'password': contrasena}),
      ),
      retry: false,
    );

    // Si el status es 200, devolvemos el map (que puede incluir el aviso 2FA)
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } 
    
    throw toApiException(response.statusCode, decodeBody(response));
  }

  // Para enviar el código que el usuario recibe en su correo
  static Future<Map<String, dynamic>> verificarLogin2FA(String correo, String codigo) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {'success': true, 'message': 'Código login verificado en Mock'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/verificar-login-2fa'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'codigo': codigo}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); 
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Código incorrecto o caducado');
    }
  }

  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (MockData.usuarios.any((u) => u.email == correo)) {
        throw const ApiException(409, 'Ya existe un usuario con ese correo');
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

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'correo': correo,
          'password': contrasena,
          'telefono': telefono,
          'direccion': direccion,
          'rol': 'cliente',
        }),
      ),
      retry: false,
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Map<String, dynamic>> verificarCodigo({
    required String correo,
    required String codigo,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {'success': true, 'message': 'Código verificado en Mock'};
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/verificar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo, 'codigo': codigo}),
      ),
      retry: false,
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> recuperarPassword({required String correo}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/recuperar-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo}),
      ),
      retry: false,
    );

    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> resetPassword({
    required String correo,
    required String codigo,
    required String nuevaPassword,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correo,
          'codigo': codigo,
          'nueva_password': nuevaPassword,
        }),
      ),
      retry: false,
    );

    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> reenviarCodigo({required String correo}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/reenviar-codigo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo}),
      ),
      retry: false,
    );

    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }
static Future<void> reenviarLogin2FA({required String correo}) async {
    // Si estás usando los datos de prueba sin backend
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/reenviar-login-2fa'), // Endpoint específico para reenviar código de login 2FA
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Error al reenviar el código de seguridad');
    }
  }

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

    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/usuarios/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'correo': email,
          'telefono': telefono,
          'direccion': direccion,
        }),
      ),
      retry: false,
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> verPerfil({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final usuario = MockData.usuarios.firstWhere(
        (u) => u.id == userId,
        orElse: () => throw const ApiException(404, 'Usuario no encontrado'),
      );
      return usuario.toJson();
    }

    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/usuarios/$userId'),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<bool> eliminarPerfil({required String userId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    }

    final response = await httpWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl/usuarios/$userId'),
        headers: {'Content-Type': 'application/json'},
      ),
      retry: false,
    );
    return response.statusCode == 200;
  }

  static Future<void> cambiarContrasena({
    required String userId,
    required String passwordActual,
    required String nuevaPassword,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }

    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/usuarios/$userId/cambiar-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'password_actual': passwordActual,
          'nueva_password': nuevaPassword,
        }),
      ),
      retry: false,
    );

    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<bool> eliminarCuenta({required String userId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    final response = await httpWithRetry(
      () => http.delete(Uri.parse('$baseUrl/usuarios/$userId')),
      retry: false,
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> setup2fa({required String userId}) async {
    final response = await httpWithRetry(
      () => http.post(Uri.parse('$baseUrl/usuarios/$userId/2fa/setup'),
          headers: {'Content-Type': 'application/json'}),
      retry: false,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Map<String, dynamic>> activar2fa({
    required String userId,
    required String codigo,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/usuarios/$userId/2fa/activar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo}),
      ),
      retry: false,
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Map<String, dynamic>> verificar2faRecovery({
    required String userId,
    required String codigo,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/verificar-2fa-recovery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'codigo': codigo}),
      ),
      retry: false,
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<List<String>> regenerarCodigosRecuperacion({
    required String userId,
    required String codigo,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/usuarios/$userId/2fa/regenerar-codigos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo}),
      ),
      retry: false,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<String>.from(data['codigosRecuperacion'] as List);
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> desactivar2fa({
    required String userId,
    required String codigo,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/usuarios/$userId/2fa/desactivar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codigo': codigo}),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<Map<String, dynamic>> verificar2fa({
    required String userId,
    required String codigo,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/verificar-2fa'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'codigo': codigo}),
      ),
      retry: false,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw toApiException(response.statusCode, decodeBody(response));
  }
}