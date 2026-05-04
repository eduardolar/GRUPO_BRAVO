class Restaurante {
  final String id;
  final String nombre;
  final String direccion;
  final String codigo;
  final String? horarioApertura; // "HH:MM" e.g. "09:00"
  final String? horarioCierre; // "HH:MM" e.g. "23:00"
  final bool activo;

  Restaurante({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.codigo,
    this.horarioApertura,
    this.horarioCierre,
    this.activo = true,
  });

  factory Restaurante.fromJson(Map<String, dynamic> json) {
    return Restaurante(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      direccion: json['direccion'] ?? '',
      codigo: json['codigo'] ?? '',
      horarioApertura:
          json['horarioApertura'] as String? ??
          json['horario_apertura'] as String?,
      horarioCierre:
          json['horarioCierre'] as String? ?? json['horario_cierre'] as String?,
      activo: json['activo'] != false,
    );
  }

  /// Returns false only when both horario fields are set AND current time is outside range.
  bool estaAbierto() {
    if (horarioApertura == null || horarioCierre == null) return true;
    final now = DateTime.now();
    final open = _parseMins(horarioApertura!);
    final close = _parseMins(horarioCierre!);
    final nowMins = now.hour * 60 + now.minute;
    if (close > open) {
      return nowMins >= open && nowMins < close;
    } else {
      // crosses midnight (e.g. 22:00 – 02:00)
      return nowMins >= open || nowMins < close;
    }
  }

  static int _parseMins(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return h * 60 + m;
  }
}
