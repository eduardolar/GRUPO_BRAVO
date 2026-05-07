/// Modelo de sucursal / restaurante del Grupo Bravo.
///
/// Incluye los campos heredados (nombre, horario general) más los nuevos
/// campos añadidos para la edición avanzada del local (F8):
///   - [logoUrl] / [logoPublicId]: logo en Cloudinary.
///   - [horariosDia]: horario detallado por día de la semana.
///   - Datos fiscales: [cif], [razonSocial], [direccionFiscal], etc.
///   - [metodosPago]: lista de slugs de métodos aceptados.
class Restaurante {
  final String id;
  final String nombre;
  final String direccion;
  final String codigo;
  final String? horarioApertura; // "HH:MM" — legacy campo general
  final String? horarioCierre;  // "HH:MM" — legacy campo general
  final bool activo;
  /// Fecha ISO en que fue suspendida, o null si no está suspendida.
  final String? suspendidoAt;

  // ── Campos nuevos F8 ──────────────────────────────────────────────────────

  /// URL pública del logo (Cloudinary).
  final String? logoUrl;

  /// ID interno de Cloudinary para poder borrar el logo sin URL.
  final String? logoPublicId;

  /// Horario por día de la semana.
  /// Clave: nombre en minúsculas ("lunes"…"domingo").
  /// Valor: {apertura, cierre, abierto}.
  final Map<String, HorarioDia>? horariosDia;

  // Datos fiscales (todos opcionales):
  final String? cif;
  final String? razonSocial;
  final String? direccionFiscal;
  final String? codigoPostal;
  final String? ciudad;
  final String? provincia;
  final String? pais;

  /// Slugs de métodos de pago aceptados.
  /// Valores posibles: efectivo, tarjeta, paypal, google_pay, stripe.
  final List<String> metodosPago;

  Restaurante({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.codigo,
    this.horarioApertura,
    this.horarioCierre,
    this.activo = true,
    this.suspendidoAt,
    // Nuevos:
    this.logoUrl,
    this.logoPublicId,
    this.horariosDia,
    this.cif,
    this.razonSocial,
    this.direccionFiscal,
    this.codigoPostal,
    this.ciudad,
    this.provincia,
    this.pais,
    this.metodosPago = const [],
  });

  /// true si la sucursal fue suspendida via super_admin (tiene suspendido_at).
  bool get estaSuspendida => suspendidoAt != null;

  factory Restaurante.fromJson(Map<String, dynamic> json) {
    // Horarios por día — el backend devuelve un Map o null.
    Map<String, HorarioDia>? horariosDia;
    final raw = json['horarios_dia'];
    if (raw is Map) {
      horariosDia = raw.map((k, v) {
        if (v is Map<String, dynamic>) {
          return MapEntry(k.toString(), HorarioDia.fromJson(v));
        }
        return MapEntry(k.toString(), const HorarioDia());
      });
    }

    // Métodos de pago: lista de strings o null.
    List<String> metodosPago = const [];
    final rawMetodos = json['metodos_pago'];
    if (rawMetodos is List) {
      metodosPago = rawMetodos.map((e) => e.toString()).toList();
    }

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
      suspendidoAt: json['suspendido_at'] as String?,
      logoUrl: json['logo_url'] as String?,
      logoPublicId: json['logo_public_id'] as String?,
      horariosDia: horariosDia,
      cif: json['cif'] as String?,
      razonSocial: json['razon_social'] as String?,
      direccionFiscal: json['direccion_fiscal'] as String?,
      codigoPostal: json['codigo_postal'] as String?,
      ciudad: json['ciudad'] as String?,
      provincia: json['provincia'] as String?,
      pais: json['pais'] as String?,
      metodosPago: metodosPago,
    );
  }

  /// Returns false only when both horario fields are set AND current time is
  /// outside range.
  bool estaAbierto() {
    if (horarioApertura == null || horarioCierre == null) return true;
    final now = DateTime.now();
    final open = _parseMins(horarioApertura!);
    final close = _parseMins(horarioCierre!);
    final nowMins = now.hour * 60 + now.minute;
    if (close > open) {
      return nowMins >= open && nowMins < close;
    } else {
      // Cruza la medianoche (p.ej. 22:00 – 02:00)
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

/// Horario de un día concreto de la semana.
class HorarioDia {
  final String apertura; // "HH:MM"
  final String cierre;   // "HH:MM"
  final bool abierto;

  const HorarioDia({
    this.apertura = '09:00',
    this.cierre = '23:00',
    this.abierto = false,
  });

  factory HorarioDia.fromJson(Map<String, dynamic> json) {
    return HorarioDia(
      apertura: json['apertura'] as String? ?? '09:00',
      cierre: json['cierre'] as String? ?? '23:00',
      abierto: json['abierto'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'apertura': apertura,
    'cierre': cierre,
    'abierto': abierto,
  };

  HorarioDia copyWith({String? apertura, String? cierre, bool? abierto}) {
    return HorarioDia(
      apertura: apertura ?? this.apertura,
      cierre: cierre ?? this.cierre,
      abierto: abierto ?? this.abierto,
    );
  }
}
