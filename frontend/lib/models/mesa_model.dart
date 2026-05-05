class Mesa {
  final String id;
  final int numero;
  final int capacidad;
  final String ubicacion; // 'interior', 'terraza', 'privado'
  final bool disponible;
  final String codigoQr;
  final String? restauranteId;

  Mesa({
    required this.id,
    required this.numero,
    required this.capacidad,
    required this.ubicacion,
    this.disponible = true,
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
      codigoQr: mapa['codigoQr'] ?? mapa['codigo_qr'],
      restauranteId: (mapa['restauranteId'] ?? mapa['restaurante_id'])
          ?.toString(),
    );
  }

  set estado(String estado) {}

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'capacidad': capacidad,
      'ubicacion': ubicacion,
      'disponible': disponible,
      'codigoQr': codigoQr,
      if (restauranteId != null) 'restauranteId': restauranteId,
    };
  }

  Mesa copyWith({
    bool? disponible,
    String? codigoQr,
    String? restauranteId,
  }) {
    return Mesa(
      id: id,
      numero: numero,
      capacidad: capacidad,
      ubicacion: ubicacion,
      disponible: disponible ?? this.disponible,
      codigoQr: codigoQr ?? this.codigoQr,
      restauranteId: restauranteId ?? this.restauranteId,
    );
  }
}
