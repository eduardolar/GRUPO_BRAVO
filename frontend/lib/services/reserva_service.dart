import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reserva_model.dart';
import '../models/mesa_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class ReservaService {
  static const int _duracionReservaMinutos = 90;

  static Future<Reserva> crearReserva({
    required String userId,
    required String nombreCompleto,
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
        nombreCompleto: nombreCompleto,
        fecha: fecha,
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
        'usuarioId': userId,
        'nombreCompleto': nombreCompleto,
        'fecha': fecha.toIso8601String().split('T').first,
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

  static Future<bool> hayDisponibilidad({
    required DateTime fecha,
    required String hora,
    required int comensales,
  }) async {
    if (!usarApiReal) {
      final fechaStr =
          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      return _buscarMesaDisponible(
            fecha: fechaStr,
            hora: hora,
            comensales: comensales,
          ) !=
          null;
    }

    final fechaStr = fecha.toIso8601String().split('T').first;
    final response = await http.get(
      Uri.parse(
        '$baseUrl/reservas/mesas-disponibles?fecha=$fechaStr&hora=$hora&comensales=$comensales',
      ),
    );

    if (response.statusCode == 200) {
      final List<dynamic> mesas = jsonDecode(response.body);
      return mesas.isNotEmpty;
    }
    return false;
  }

  static Future<List<Reserva>> obtenerReservas({required String userId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.reservas.where((r) => r.usuarioId == userId).toList();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/reservas?usuarioId=$userId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((m) => Reserva.fromMap(m as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al obtener reservas - Status: ${response.statusCode}');
    }
  }

  static Future<bool> actualizarComensales({
    required String reservaId,
    required int comensales,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = MockData.reservas.indexWhere((r) => r.id == reservaId);
      if (index >= 0) {
        MockData.reservas[index] =
            MockData.reservas[index].copyWith(comensales: comensales);
      }
      return true;
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/reservas/$reservaId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'comensales': comensales}),
    );
    return response.statusCode == 200;
  }

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

  /// Obtener todas las reservas futuras (para trabajadores)
  static Future<List<Reserva>> obtenerReservasFuturas() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      return MockData.reservas.where((r) => !r.fecha.isBefore(hoy)).toList();
    }

    final response = await http.get(Uri.parse('$baseUrl/reservas/futuras'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((m) => Reserva.fromMap(m as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Error al obtener reservas futuras - Status: ${response.statusCode}');
    }
  }

  /// Actualizar reserva completa (fecha, hora, comensales, turno, notas)
  static Future<bool> actualizarReserva(Reserva reserva) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = MockData.reservas.indexWhere((r) => r.id == reserva.id);
      if (index >= 0) {
        MockData.reservas[index] = reserva;
      }
      return true;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/reservas/${reserva.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fecha': reserva.fecha.toIso8601String().split('T').first,
        'hora': reserva.hora,
        'comensales': reserva.comensales,
        'turno': reserva.turno,
        'notas': reserva.notas,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Error al actualizar reserva - Status: ${response.statusCode}');
    }
  }

  // ─── Helpers privados ────────────────────────────────────────

  static int _horaAMinutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  static bool _hayConflictoHorario(String horaA, String horaB) {
    final inicioA = _horaAMinutos(horaA);
    final finA = inicioA + _duracionReservaMinutos;
    final inicioB = _horaAMinutos(horaB);
    final finB = inicioB + _duracionReservaMinutos;
    return inicioA < finB && inicioB < finA;
  }

  static Mesa? _buscarMesaDisponible({
    required String fecha,
    required String hora,
    required int comensales,
  }) {
    final candidatas =
        MockData.mesas
            .where((m) => m.capacidad >= comensales && m.disponible)
            .toList()
          ..sort((a, b) => a.capacidad.compareTo(b.capacidad));

    for (final mesa in candidatas) {
      final tieneConflicto = MockData.reservas.any(
        (r) =>
            r.mesaId == mesa.id &&
            r.fecha == fecha &&
            r.estado == 'Confirmada' &&
            _hayConflictoHorario(r.hora, hora),
      );

      if (!tieneConflicto) return mesa;
    }
    return null;
  }
}