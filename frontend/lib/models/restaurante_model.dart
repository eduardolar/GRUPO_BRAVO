// ============================================================================
// frontend/lib/models/restaurante_model.dart
// ----------------------------------------------------------------------------
// Modelo de la sucursal. Incluye datos de contacto, fiscales y horarios.
// El backend persiste todo en `restaurantes`; el `id` se usa como
// `restaurante_id` en pedidos, productos, mesas, etc.
// ============================================================================
/// Modelo de sucursal / restaurante del Grupo Bravo.
///
/// Incluye los campos del local más los nuevos campos añadidos para la
/// edición avanzada (F8):
///   - [logoUrl] / [logoPublicId]: logo en Cloudinary.
///   - [horariosDia]: horario detallado por día de la semana.
///   - Datos fiscales: [cif], [razonSocial], [direccionFiscal], etc.
///   - [metodosPago]: lista de slugs de métodos aceptados.
class Restaurante {
  final String id;
  final String nombre;
  final String direccion;
  final String codigo;
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
    this.activo = true,
    this.suspendidoAt,
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

  /// Devuelve true si la sucursal está abierta en este momento.
  ///
  /// Usa [horariosDia] (al menos un día con abierto:true). Si no hay ningún
  /// día configurado como abierto, devuelve false.
  /// Soporta turnos que cruzan la medianoche (apertura > cierre): la cola
  /// del turno de ayer cubre las primeras horas de hoy.
  bool estaAbierto() {
    if (horariosDia == null || !horariosDia!.values.any((h) => h.abierto)) {
      return false;
    }

    const claves = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final idxHoy = now.weekday - 1; // 0..6
    final idxAyer = (idxHoy - 1 + 7) % 7;

    // a) Cola del turno de ayer si cruzaba medianoche.
    final hAyer = horariosDia![claves[idxAyer]];
    if (hAyer != null && hAyer.abierto) {
      final openA = _parseMins(hAyer.apertura);
      final closeA = _parseMins(hAyer.cierre);
      if (closeA <= openA && nowMins < closeA) return true;
    }

    // b) Turno de hoy.
    final hHoy = horariosDia![claves[idxHoy]];
    if (hHoy != null && hHoy.abierto) {
      final openH = _parseMins(hHoy.apertura);
      final closeH = _parseMins(hHoy.cierre);
      if (closeH > openH) {
        return nowMins >= openH && nowMins < closeH;
      }
      // Hoy cruza medianoche: abierto desde apertura hasta 23:59.
      return nowMins >= openH;
    }
    return false;
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
