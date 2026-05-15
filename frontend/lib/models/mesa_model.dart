// ============================================================================
// frontend/lib/models/mesa_model.dart
// ----------------------------------------------------------------------------
// Modelo de mesa física. `estado` (string) es el campo nuevo; `disponible`
// (bool) se mantiene por compatibilidad con la app antigua: true solo si la
// mesa está libre.
// ============================================================================
class Mesa {
  final String id;
  final int numero;
  final int capacidad;
  final String ubicacion; // 'interior', 'terraza', 'privado'
  final bool disponible;
  /// Estado real de la mesa: 'libre' u 'ocupada'.
  /// `disponible` se mantiene como bool retrocompatible (true solo si libre).
  final String estado;
  final String codigoQr;
  final String? restauranteId;

  Mesa({
    required this.id,
    required this.numero,
    required this.capacidad,
    required this.ubicacion,
    this.disponible = true,
    this.estado = 'libre',
    String? codigoQr,
    this.restauranteId,
  }) : codigoQr = codigoQr ?? 'mesa_$numero';

  factory Mesa.fromMap(Map<String, dynamic> mapa) {
    return Mesa(
      id: mapa['id'] ?? '',
      numero: mapa['numero'] ?? 0,
      capacidad: mapa['capacidad'] ?? 2,
      ubicacion: mapa['ubicacion'] ?? 'interior',
      disponible: mapa['disponible'] ?? true,
      estado: (mapa['estado'] as String?) ??
          (mapa['disponible'] == false ? 'ocupada' : 'libre'),
      codigoQr: mapa['codigoQr'] ?? mapa['codigo_qr'],
      restauranteId: (mapa['restauranteId'] ?? mapa['restaurante_id'])?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'capacidad': capacidad,
      'ubicacion': ubicacion,
      'disponible': disponible,
      'estado': estado,
      'codigoQr': codigoQr,
      if (restauranteId != null) 'restauranteId': restauranteId,
    };
  }

  Mesa copyWith({
    bool? disponible,
    String? estado,
    String? codigoQr,
    String? restauranteId,
  }) {
    return Mesa(
      id: id,
      numero: numero,
      capacidad: capacidad,
      ubicacion: ubicacion,
      disponible: disponible ?? this.disponible,
      estado: estado ?? this.estado,
      codigoQr: codigoQr ?? this.codigoQr,
      restauranteId: restauranteId ?? this.restauranteId,
    );
  }
}
