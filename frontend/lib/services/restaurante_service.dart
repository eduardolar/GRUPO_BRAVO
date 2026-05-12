import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/restaurante_model.dart';
import 'api_config.dart';
import 'http_client.dart';
import 'auth_session.dart';

class RestauranteService {
  Future<List<Restaurante>> obtenerTodos() async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/restaurantes'),
        headers: AuthSession.headers(),
      ),
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Restaurante.fromJson(item)).toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  Future<Restaurante?> crearRestaurante({
    required String nombre,
    required String direccion,
  }) async {
    try {
      final response = await httpWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/restaurantes'),
          headers: AuthSession.headers(),
          body: jsonEncode({'nombre': nombre, 'direccion': direccion}),
        ),
        retry: false,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Restaurante.fromJson(jsonDecode(response.body));
      }
      return null;
    } on ApiException {
      return null;
    }
  }

  Future<bool> editarRestaurante({
    required String id,
    required String nombre,
    required String direccion,
  }) async {
    try {
      final body = <String, dynamic>{'nombre': nombre, 'direccion': direccion};

      final response = await httpWithRetry(
        () => http.put(
          Uri.parse('$baseUrl/restaurantes/$id'),
          headers: AuthSession.headers(),
          body: jsonEncode(body),
        ),
        retry: false,
      );
      return response.statusCode == 200;
    } on ApiException {
      return false;
    }
  }

  Future<bool> toggleActivo(String id, bool activo) async {
    try {
      final response = await httpWithRetry(
        () => http.patch(
          Uri.parse('$baseUrl/restaurantes/$id/activo'),
          headers: AuthSession.headers(),
          body: jsonEncode({'activo': activo}),
        ),
        retry: false,
      );
      return response.statusCode == 200;
    } on ApiException {
      return false;
    }
  }

  Future<bool> eliminarRestaurante(String id) async {
    try {
      final response = await httpWithRetry(
        () => http.delete(
          Uri.parse('$baseUrl/restaurantes/$id'),
          headers: AuthSession.headers(),
        ),
        retry: false,
      );
      return response.statusCode == 200;
    } on ApiException {
      return false;
    }
  }

  // ── Métodos nuevos F8 ─────────────────────────────────────────────────────

  /// Actualiza los campos indicados de un restaurante (PATCH semántico sobre PUT).
  /// Solo se envían los campos presentes en [datos]; el backend ignora los ausentes.
  /// Lanza [ApiException] si el servidor devuelve 4xx/5xx.
  static Future<void> actualizarRestaurante(
    String id,
    Map<String, dynamic> datos,
  ) async {
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/restaurantes/$id'),
        headers: AuthSession.headers(),
        body: jsonEncode(datos),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  /// Sube el logo de una sucursal a Cloudinary vía backend.
  /// Devuelve el mapa con `logo_url` y `logo_public_id`.
  /// Lanza [ApiException] en errores (503 si Cloudinary no está configurado).
  static Future<Map<String, dynamic>> subirLogo({
    required String id,
    required Uint8List bytes,
    required String nombreArchivo,
    required String contentType,
  }) async {
    final uri = Uri.parse('$baseUrl/restaurantes/$id/logo');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(AuthSession.headers(json: false))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: nombreArchivo,
          contentType: MediaType.parse(contentType),
        ),
      );

    final streamed = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return decodeBody(response);
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Elimina el logo de la sucursal en Cloudinary y pone el campo a null.
  static Future<void> eliminarLogo(String id) async {
    final response = await httpWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl/restaurantes/$id/logo'),
        headers: AuthSession.headers(),
      ),
      retry: false,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }
}
