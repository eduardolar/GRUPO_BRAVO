import 'package:intl/intl.dart';

class Reserva {
  final String id;
  final String usuarioId;
  final String nombreCompleto; 
  final DateTime fecha;
  final String hora;
  final int comensales;
  final String turno;
  final String estado;
  final String? mesaId;
  final int? numeroMesa;
  final String? notas;

  Reserva({
    required this.id,
    required this.usuarioId,
    required this.nombreCompleto, 
    required this.fecha,
    required this.hora,
    required this.comensales,
    required this.turno,
    required this.estado,
    this.mesaId,
    this.numeroMesa,
    this.notas,
  });

  /// Detecta automáticamente el formato de fecha
  static DateTime _parseFecha(String fechaStr) {
    try {
      if (fechaStr.contains('/')) {
        // Formato mock: dd/MM/yyyy
        return DateFormat('dd/MM/yyyy').parse(fechaStr);
      } else {
        // Formato API real: yyyy-MM-dd
        return DateTime.parse(fechaStr);
      }
    } catch (_) {
      return DateTime.now();
    }
  }

  factory Reserva.fromMap(Map<String, dynamic> mapa) {
    return Reserva(
      id: mapa['id'] ?? '',
      usuarioId: mapa['usuarioId'] ?? mapa['usuario_id'] ?? '',
      nombreCompleto: mapa['nombreCompleto'] ?? mapa['nombre_completo'] ?? '',
      fecha: _parseFecha(mapa['fecha'] ?? ''),
      hora: mapa['hora'] ?? '',
      comensales: mapa['comensales'] ?? 1,
      turno: mapa['turno'] ?? 'comida',
      estado: mapa['estado'] ?? 'Confirmada',
      mesaId: mapa['mesaId'] ?? mapa['mesa_id'],
      numeroMesa: mapa['numeroMesa'] ?? mapa['numero_mesa'],
      notas: mapa['notas'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'nombreCompleto': nombreCompleto,
      'fecha': DateFormat('yyyy-MM-dd').format(fecha),
      'hora': hora,
      'comensales': comensales,
      'turno': turno,
      'estado': estado,
      'mesaId': mesaId,
      'numeroMesa': numeroMesa,
      'notas': notas,
    };
  }

  Reserva copyWith({
    String? id,
    String? usuarioId,
    String? nombreCompleto,
    DateTime? fecha,
    String? hora,
    int? comensales,
    String? turno,
    String? estado,
    String? mesaId,
    int? numeroMesa,
    String? notas,
  }) {
    return Reserva(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      comensales: comensales ?? this.comensales,
      turno: turno ?? this.turno,
      estado: estado ?? this.estado,
      mesaId: mesaId ?? this.mesaId,
      numeroMesa: numeroMesa ?? this.numeroMesa,
      notas: notas ?? this.notas,
    );
  }
}