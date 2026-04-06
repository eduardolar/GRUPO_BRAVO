import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto_model.dart';
import '../models/pedido_model.dart';
import '../models/mesa_model.dart';
import '../models/reserva_model.dart';
import '../data/mock_data.dart';

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  CAMBIAR A [true] CUANDO EL BACKEND ESTÉ LISTO             ║
/// ╚══════════════════════════════════════════════════════════════╝
const bool usarApiReal = false;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // ─── AUTENTICACIÓN ───────────────────────────────────────────

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
      // Comprobar si ya existe
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

  // ─── PRODUCTOS Y CATEGORÍAS ──────────────────────────────────

  /// Obtener lista de categorías
  static Future<List<String>> obtenerCategorias() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(MockData.categorias);
    }

    final response = await http.get(Uri.parse('$baseUrl/categorias'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Error al obtener categorías');
    }
  }

  /// Obtener productos (opcionalmente filtrados por categoría)
  static Future<List<Producto>> obtenerProductos({String? categoria}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final productos = MockData.productos;
      if (categoria != null) {
        return productos.where((p) => p.categoria == categoria).toList();
      }
      return List.from(productos);
    }

    final uri = categoria != null
        ? Uri.parse('$baseUrl/productos?categoria=$categoria')
        : Uri.parse('$baseUrl/productos');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Producto.fromMap(json)).toList();
    } else {
      throw Exception('Error al obtener productos');
    }
  }

  // ─── PEDIDOS ─────────────────────────────────────────────────

  /// Crear un nuevo pedido
  static Future<Map<String, dynamic>> crearPedido({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String tipoEntrega,
    required String metodoPago,
    required double total,
    String? direccionEntrega,
    String? notas,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 600));
      final nuevoPedidoId =
          '#${(MockData.pedidos.length + 1).toString().padLeft(3, '0')}';
      final ahora = DateTime.now();
      final fecha =
          '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year}';
      return {
        'id': nuevoPedidoId,
        'fecha': fecha,
        'total': total,
        'estado': 'En preparación',
        'items': items.length,
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/pedidos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usuario_id': userId,
        'items': items,
        'tipo_entrega': tipoEntrega,
        'metodo_pago': metodoPago,
        'total': total,
        'direccion_entrega': direccionEntrega,
        'notas': notas,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Error al crear pedido');
    }
  }

  /// Obtener historial de pedidos de un usuario
  static Future<List<Pedido>> obtenerHistorialPedidos({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.pedidos.map((m) => Pedido.fromMap(m)).toList();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/pedidos?usuario_id=$userId'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => Pedido.fromMap(json as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al obtener historial');
    }
  }

  // ─── MESAS ───────────────────────────────────────────────────

  /// Obtener todas las mesas del local
  static Future<List<Mesa>> obtenerMesas() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.from(MockData.mesas);
    }

    final response = await http.get(Uri.parse('$baseUrl/mesas'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Mesa.fromMap(m as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al obtener mesas');
    }
  }

  // ─── RESERVAS ────────────────────────────────────────────────

  /// Duración estimada de una comida (90 minutos)
  static const int _duracionReservaMinutos = 90;

  /// Crear una reserva de mesa
  static Future<Reserva> crearReserva({
    required String userId,
    required DateTime fecha,
    required String hora,
    required int comensales,
    required String turno,
    String? notas,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 500));

      final fechaStr =
          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

      // Buscar una mesa libre que quepa, sin conflicto de horario
      final mesaAsignada = _buscarMesaDisponible(
        fecha: fechaStr,
        hora: hora,
        comensales: comensales,
      );

      if (mesaAsignada == null) {
        throw Exception(
          'No hay mesas disponibles para $comensales comensales a las $hora. '
          'Prueba otra hora o reduce el número de comensales.',
        );
      }

      final reserva = Reserva(
        id: 'r_${DateTime.now().millisecondsSinceEpoch}',
        usuarioId: userId,
        fecha: fechaStr,
        hora: hora,
        comensales: comensales,
        turno: turno,
        estado: 'Confirmada',
        mesaId: mesaAsignada.id,
        numeroMesa: mesaAsignada.numero,
        notas: notas,
      );

      MockData.reservas.add(reserva);
      return reserva;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/reservas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usuario_id': userId,
        'fecha': fecha.toIso8601String(),
        'hora': hora,
        'comensales': comensales,
        'turno': turno,
        'notas': notas,
      }),
    );

    if (response.statusCode == 200) {
      return Reserva.fromMap(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Error al crear reserva');
    }
  }

  /// Comprueba si hay mesa disponible para una fecha, hora y nº de comensales.
  /// Devuelve true si hay al menos una mesa libre.
  static bool hayDisponibilidad({
    required DateTime fecha,
    required String hora,
    required int comensales,
  }) {
    final fechaStr =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    return _buscarMesaDisponible(
      fecha: fechaStr,
      hora: hora,
      comensales: comensales,
    ) != null;
  }

  /// Convierte "HH:mm" a minutos desde medianoche
  static int _horaAMinutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  /// Comprueba si dos franjas horarias se solapan (cada una dura 90 min)
  static bool _hayConflictoHorario(String horaA, String horaB) {
    final inicioA = _horaAMinutos(horaA);
    final finA = inicioA + _duracionReservaMinutos;
    final inicioB = _horaAMinutos(horaB);
    final finB = inicioB + _duracionReservaMinutos;
    return inicioA < finB && inicioB < finA;
  }

  /// Busca la primera mesa con capacidad suficiente que no tenga
  /// reserva en conflicto horario para esa fecha.
  static Mesa? _buscarMesaDisponible({
    required String fecha,
    required String hora,
    required int comensales,
  }) {
    // Mesas candidatas ordenadas por capacidad ascendente (asignar la más justa)
    final candidatas = MockData.mesas
        .where((m) => m.capacidad >= comensales && m.disponible)
        .toList()
      ..sort((a, b) => a.capacidad.compareTo(b.capacidad));

    for (final mesa in candidatas) {
      final tieneConflicto = MockData.reservas.any((r) =>
          r.mesaId == mesa.id &&
          r.fecha == fecha &&
          r.estado == 'Confirmada' &&
          _hayConflictoHorario(r.hora, hora));

      if (!tieneConflicto) return mesa;
    }
    return null; // Todas ocupadas en esa franja
  }

  /// Obtener reservas de un usuario
  static Future<List<Reserva>> obtenerReservas({
    required String userId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.reservas
          .where((r) => r.usuarioId == userId)
          .toList();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/reservas?usuario_id=$userId'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((m) => Reserva.fromMap(m as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al obtener reservas');
    }
  }

  /// Eliminar una reserva
  static Future<bool> eliminarReserva({required String reservaId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      MockData.reservas.removeWhere((r) => r.id == reservaId);
      return true;
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/reservas/$reservaId'),
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

  // ─── QR / MESA ──────────────────────────────────────────────

  /// Validar código QR de una mesa
  static Future<Map<String, dynamic>> validarQrMesa({
    required String codigoQr,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {
        'mesa_id': codigoQr,
        'numero_mesa': codigoQr.replaceAll(RegExp(r'[^0-9]'), ''),
        'estado': 'disponible',
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/mesas/validar-qr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'codigo_qr': codigoQr}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'QR no válido');
    }
  }
}
