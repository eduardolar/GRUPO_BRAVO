import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Typed HTTP error. [statusCode] == 0 means a network-level failure
/// (no connection or request timeout).
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;
  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Maps an HTTP [statusCode] + response [body] to a user-facing [ApiException].
ApiException toApiException(int statusCode, Map<String, dynamic> body) {
  String? extractDetail(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is List && value.isNotEmpty) {
      return value.map((item) => item.toString()).join(', ');
    }
    if (value is Map<String, dynamic>) {
      return extractDetail(
        value['detail'] ?? value['message'] ?? value['error'],
      );
    }
    return null;
  }

  final String? detail =
      extractDetail(body['detail']) ??
      extractDetail(body['message']) ??
      extractDetail(body['error']) ??
      extractDetail(body['title']) ??
      extractDetail(body['errors']);

  return switch (statusCode) {
    400 => ApiException(400, detail ?? 'Solicitud incorrecta'),
    401 => const ApiException(401, 'Sesión expirada. Vuelve a iniciar sesión'),
    403 => const ApiException(
      403,
      'No tienes permiso para realizar esta acción',
    ),
    404 => ApiException(404, detail ?? 'Recurso no encontrado'),
    409 => ApiException(409, detail ?? 'Ya existe un registro con estos datos'),
    422 => ApiException(422, detail ?? 'Los datos enviados no son válidos'),
    429 => const ApiException(429, 'Demasiadas solicitudes. Espera un momento'),
    >= 500 => ApiException(
      statusCode,
      detail ?? 'Error del servidor ($statusCode). Inténtalo más tarde',
    ),
    _ => ApiException(statusCode, detail ?? 'Error inesperado ($statusCode)'),
  };
}

/// Decodes a JSON response body to a Map.
/// Returns a fallback detail when the response is not valid JSON.
Map<String, dynamic> decodeBody(http.Response response) {
  if (response.body.isEmpty) return {};
  try {
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  } on FormatException {
    // PayPal / backend puede devolver texto o HTML en errores 500.
    debugPrint(
      'DEBUG: HTTP response body no es JSON. '
      'status=${response.statusCode} body=${response.body}',
    );
    return {'detail': response.body.trim()};
  }
}

/// Executes [request] with a 20-second timeout, converting network failures
/// to [ApiException].
///
/// When [retry] is true (default), retries up to [maxAttempts] times on 5xx
/// responses and network failures, with increasing back-off.
/// Pass `retry: false` for writes that must not be duplicated (orders, payments).
Future<http.Response> httpWithRetry(
  Future<http.Response> Function() request, {
  bool retry = true,
  int maxAttempts = 3,
}) async {
  int attempt = 0;
  while (true) {
    attempt++;
    try {
      final response = await request().timeout(const Duration(seconds: 20));
      if (!retry || response.statusCode < 500 || attempt >= maxAttempts) {
        return response;
      }
      await Future.delayed(Duration(seconds: attempt));
    } on SocketException {
      if (!retry || attempt >= maxAttempts) {
        throw const ApiException(
          0,
          'Sin conexión a internet. Comprueba tu red',
        );
      }
      await Future.delayed(Duration(seconds: attempt));
    } on TimeoutException {
      if (!retry || attempt >= maxAttempts) {
        throw const ApiException(
          0,
          'El servidor tardó demasiado. Inténtalo de nuevo',
        );
      }
      await Future.delayed(Duration(seconds: attempt));
    } on http.ClientException catch (e) {
      // Web: SocketException no existe, los errores de red llegan como
      // ClientException con mensajes tipo "Failed to fetch", "XMLHttpRequest
      // error" o "Connection closed before full header was received".
      if (kDebugMode) debugPrint('httpWithRetry · ClientException: $e');
      if (!retry || attempt >= maxAttempts) {
        throw ApiException(0, _mensajeErrorRed(e));
      }
      await Future.delayed(Duration(seconds: attempt));
    }
  }
}

/// Mensaje en castellano explicando una `ClientException`. Como en web
/// "Failed to fetch" puede deberse a backend caído, CORS, certificado,
/// extensión de navegador... añadimos pistas accionables.
String _mensajeErrorRed(http.ClientException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('failed to fetch') ||
      msg.contains('xmlhttprequest') ||
      msg.contains('network error')) {
    if (kIsWeb) {
      return 'No se pudo conectar al servidor.\n'
          'Verifica que el backend está en marcha y que CORS permite tu origen.';
    }
    return 'No hay conexión con el servidor. Inténtalo de nuevo.';
  }
  if (msg.contains('connection') && msg.contains('refused')) {
    return 'El servidor rechazó la conexión. ¿Está el backend levantado?';
  }
  if (msg.contains('connection closed')) {
    return 'Conexión interrumpida. Reintenta en unos segundos.';
  }
  return 'Error de red: ${e.message}';
}
