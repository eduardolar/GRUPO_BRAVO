import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reserva_model.dart';
import '../models/mesa_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class ReservaService {
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

    // Con API real, el servidor valida al crear la reserva
    return true;
  }

  /// Obtener reservas de un usuario
  static Future<List<Reserva>> obtenerReservas({required String userId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockData.reservas.where((r) => r.usuarioId == userId).toList();
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

  // ─── Helpers privados ────────────────────────────────────────

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
