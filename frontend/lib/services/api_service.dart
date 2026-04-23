import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/producto_model.dart';
import '../models/pedido_model.dart';
import '../models/mesa_model.dart';
import '../models/reserva_model.dart';
import '../models/ingrediente_model.dart';

import 'auth_service.dart';
import 'producto_service.dart';
import 'ingredientes_service.dart';
import 'pedido_service.dart';
import 'reserva_service.dart';
import 'mesa_service.dart';
import 'http_client.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // ─── AUTH ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) => AuthService.iniciarSesion(correo: correo, contrasena: contrasena);

  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) => AuthService.registrarUsuario(
    nombre: nombre,
    correo: correo,
    contrasena: contrasena,
    telefono: telefono,
    direccion: direccion,
  );

  static Future<bool> actualizarPerfil({
    required String userId,
    required String nombre,
    required String email,
    required String telefono,
    required String direccion,
  }) => AuthService.actualizarPerfil(
    userId: userId,
    nombre: nombre,
    email: email,
    telefono: telefono,
    direccion: direccion,
  );

  static Future<Map<String, dynamic>> verPerfil({required String userId}) =>
      AuthService.verPerfil(userId: userId);

  static Future<bool> eliminarPerfil({required String userId}) =>
      AuthService.eliminarPerfil(userId: userId);

  static Future<bool> eliminarCuenta({required String userId}) =>
      AuthService.eliminarCuenta(userId: userId);

  // ─── PRODUCTOS ───────────────────────────────────────────────

  static Future<List<String>> obtenerCategorias() =>
      ProductoService.obtenerCategorias();

  static Future<List<Producto>> obtenerProductos({String? categoria}) =>
      ProductoService.obtenerProductos(categoria: categoria);

  static Future<List<Ingrediente>> obtenerIngredientes() =>
      IngredienteService.obtenerIngredientes();

  static Future<Map<String, List<Ingrediente>>> obtenerIngredientesPorCategoria() =>
      IngredienteService.obtenerIngredientesPorCategoria();

  // ─── PEDIDOS ─────────────────────────────────────────────────

  static Future<bool> enviarPedidoPorQR({
    required String mesaId,
    required List<dynamic> items,
  }) => PedidoService.enviarPedidoPorQR(mesaId: mesaId, items: items);

  static Future<Map<String, dynamic>> crearPedido({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String tipoEntrega,
    required String metodoPago,
    required double total,
    String? direccionEntrega,
    String? mesaId,
    int? numeroMesa,
    String? notas,
    String? referenciaPago,
    required String estadoPago,
  }) => PedidoService.crearPedido(
    userId: userId,
    items: items,
    tipoEntrega: tipoEntrega,
    metodoPago: metodoPago,
    total: total,
    direccionEntrega: direccionEntrega,
    mesaId: mesaId,
    numeroMesa: numeroMesa,
    notas: notas,
    referenciaPago: referenciaPago,
    estadoPago: estadoPago,
  );

  static Future<void> agregarItemsPedido({
    required String pedidoId,
    required List<Map<String, dynamic>> items,
    required double totalExtra,
  }) => PedidoService.agregarItemsPedido(
    pedidoId: pedidoId,
    items: items,
    totalExtra: totalExtra,
  );

  static Future<List<Pedido>> obtenerHistorialPedidos({
    required String userId,
  }) => PedidoService.obtenerHistorialPedidos(userId: userId);

  // ─── PAGOS TARJETA / STRIPE ──────────────────────────────────

  static Future<Map<String, dynamic>> crearIntentoTarjeta({
    required double amount,
    String currency = 'eur',
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/stripe/create-intent'),
        headers: _jsonHeaders(),
        body: jsonEncode({'amount': amount, 'currency': currency}),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<bool> confirmarPagoTarjeta({
    required String clientSecret,
    required String numeroTarjeta,
    required String fechaExpiracion,
    required String cvv,
    required String nombreTitular,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/stripe/confirm'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'clientSecret': clientSecret,
          'numeroTarjeta': numeroTarjeta,
          'fechaExpiracion': fechaExpiracion,
          'cvv': cvv,
          'nombreTitular': nombreTitular,
        }),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    final data = decodeBody(response);
    return data['success'] == true || data['status'] == 'succeeded';
  }

  static Future<bool> verificarPagoTarjeta({
    required String paymentIntentId,
  }) async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/payments/stripe/verify/$paymentIntentId'),
        headers: _jsonHeaders(),
      ),
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    final data = decodeBody(response);
    return data['paid'] == true || data['status'] == 'succeeded';
  }

  // ─── APPLE PAY ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> iniciarApplePay({
    required double total,
    String currencyCode = 'EUR',
    String countryCode = 'ES',
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/apple-pay/init'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'total': total,
          'currencyCode': currencyCode,
          'countryCode': countryCode,
        }),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<Map<String, dynamic>> confirmarApplePay({
    required String clientSecret,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/apple-pay/confirm'),
        headers: _jsonHeaders(),
        body: jsonEncode({'clientSecret': clientSecret}),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<bool> verificarApplePay({
    required String paymentIntentId,
  }) async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/payments/apple-pay/verify/$paymentIntentId'),
        headers: _jsonHeaders(),
      ),
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    final data = decodeBody(response);
    return data['paid'] == true ||
        data['status'] == 'succeeded' ||
        data['status'] == 'paid';
  }

  static Future<Map<String, dynamic>> crearCheckoutSession({
    required double total,
    String currency = 'eur',
    required String successUrl,
    required String cancelUrl,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/stripe/create-checkout-session'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'total': total,
          'currency': currency,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        }),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<bool> verificarCheckoutSession({
    required String sessionId,
  }) async {
    final response = await httpWithRetry(
      () => http.get(
        Uri.parse('$baseUrl/payments/stripe/verify-session/$sessionId'),
        headers: _jsonHeaders(),
      ),
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return decodeBody(response)['paid'] == true;
  }

  static Future<void> actualizarEstadoPago({
    required String referenciaPago,
    String estadoPago = 'pagado',
  }) async {
    final response = await httpWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl/pedidos/actualizar-estado-pago'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'referencia_pago': referenciaPago,
          'estado_pago': estadoPago,
        }),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  // ─── PAYPAL ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> crearOrdenPaypal({
    required double total,
    String currency = 'EUR',
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/paypal/create-order'),
        headers: _jsonHeaders(),
        body: jsonEncode({'total': total, 'currency': currency}),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<Map<String, dynamic>> capturarOrdenPaypal({
    required String orderId,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/paypal/capture-order'),
        headers: _jsonHeaders(),
        body: jsonEncode({'orderId': orderId}),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  // ─── GOOGLE PAY / GOOGLE PLAY ────────────────────────────────

  static Future<Map<String, dynamic>> iniciarGooglePay({
    required double total,
    String currencyCode = 'EUR',
    String countryCode = 'ES',
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/google-pay/init'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'total': total,
          'currencyCode': currencyCode,
          'countryCode': countryCode,
        }),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  static Future<Map<String, dynamic>> verificarCompraGooglePlay({
    String? packageName,
    required String productId,
    required String purchaseToken,
  }) async {
    final body = <String, dynamic>{
      'productId': productId,
      'purchaseToken': purchaseToken,
    };
    if (packageName != null && packageName.isNotEmpty) {
      body['packageName'] = packageName;
    }
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/payments/google-play/verify'),
        headers: _jsonHeaders(),
        body: jsonEncode(body),
      ),
      retry: false,
    );
    if (response.statusCode >= 400) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
    return Map<String, dynamic>.from(decodeBody(response));
  }

  // ─── MESAS ───────────────────────────────────────────────────

  static Future<List<Mesa>> obtenerMesas() => MesaService.obtenerMesas();

  // ─── RESERVAS ────────────────────────────────────────────────

  static Future<Reserva> crearReserva({
    required String userId,
    required String nombreCompleto,
    required DateTime fecha,
    required String hora,
    required int comensales,
    required String turno,
    String? notas,
  }) => ReservaService.crearReserva(
    userId: userId,
    nombreCompleto: nombreCompleto,
    fecha: fecha,
    hora: hora,
    comensales: comensales,
    turno: turno,
    notas: notas,
  );

  static Future<bool> hayDisponibilidad({
    required DateTime fecha,
    required String hora,
    required int comensales,
  }) => ReservaService.hayDisponibilidad(
    fecha: fecha,
    hora: hora,
    comensales: comensales,
  );

  static Future<List<Reserva>> obtenerReservas({required String userId}) =>
      ReservaService.obtenerReservas(userId: userId);

  static Future<bool> actualizarComensales({
    required String reservaId,
    required int comensales,
  }) => ReservaService.actualizarComensales(
    reservaId: reservaId,
    comensales: comensales,
  );

  static Future<bool> eliminarReserva({required String reservaId}) =>
      ReservaService.eliminarReserva(reservaId: reservaId);

  // ─── QR / MESA ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> validarQrMesa({
    required String codigoQr,
  }) => MesaService.validarQrMesa(codigoQr: codigoQr);

  // ─── HELPERS ─────────────────────────────────────────────────

  static Map<String, String> _jsonHeaders() {
    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }

  static Future<void> agregarItemTicket({
  required String mesaId,
  required Producto producto,
  required int cantidad,
}) async {
  final body = {
    "producto_id": producto.id,
    "nombre": producto.nombre,
    "cantidad": cantidad,
    "precio": producto.precio,
  };

  final response = await httpWithRetry(
    () => http.post(
      Uri.parse("$baseUrl/tickets/mesa/$mesaId"),
      headers: _jsonHeaders(),
      body: jsonEncode(body),
    ),
    retry: false,
  );

  if (response.statusCode >= 400) {
    throw Exception("Error al enviar item al ticket: ${response.body}");
  }
}

}
