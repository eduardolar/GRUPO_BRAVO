class Reserva {
  final String id;
  final String usuarioId;
  final String fecha;
  final String hora;
  final int comensales;
  final String turno; // 'comida', 'cena'
  final String estado; // 'Confirmada', 'Cancelada', 'Completada'
  final String? mesaId;
  final int? numeroMesa;
  final String? notas;

  Reserva({
    required this.id,
    required this.usuarioId,
    required this.fecha,
    required this.hora,
    required this.comensales,
    required this.turno,
    required this.estado,
    this.mesaId,
    this.numeroMesa,
    this.notas,
  });

  factory Reserva.fromMap(Map<String, dynamic> mapa) {
    return Reserva(
      id: mapa['id'] ?? '',
      usuarioId: mapa['usuario_id'] ?? '',
      fecha: mapa['fecha'] ?? '',
      hora: mapa['hora'] ?? '',
      comensales: mapa['comensales'] ?? 1,
      turno: mapa['turno'] ?? 'comida',
      estado: mapa['estado'] ?? 'Confirmada',
      mesaId: mapa['mesa_id'],
      numeroMesa: mapa['numero_mesa'],
      notas: mapa['notas'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'fecha': fecha,
      'hora': hora,
      'comensales': comensales,
      'turno': turno,
      'estado': estado,
      'mesa_id': mesaId,
      'numero_mesa': numeroMesa,
      'notas': notas,
    };
  }

  Reserva copyWith({String? estado}) {
    return Reserva(
      id: id,
      usuarioId: usuarioId,
      fecha: fecha,
      hora: hora,
      comensales: comensales,
      turno: turno,
      estado: estado ?? this.estado,
      mesaId: mesaId,
      numeroMesa: numeroMesa,
      notas: notas,
    );
  }
}
