class Mesa {
  final String id;
  final int numero;
  final int capacidad;
  final String ubicacion; // 'interior', 'terraza', 'privado'
  final bool disponible;

  Mesa({
    required this.id,
    required this.numero,
    required this.capacidad,
    required this.ubicacion,
    this.disponible = true,
  });

  factory Mesa.fromMap(Map<String, dynamic> mapa) {
    return Mesa(
      id: mapa['id'] ?? '',
      numero: mapa['numero'] ?? 0,
      capacidad: mapa['capacidad'] ?? 2,
      ubicacion: mapa['ubicacion'] ?? 'interior',
      disponible: mapa['disponible'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'capacidad': capacidad,
      'ubicacion': ubicacion,
      'disponible': disponible,
    };
  }

  Mesa copyWith({bool? disponible}) {
    return Mesa(
      id: id,
      numero: numero,
      capacidad: capacidad,
      ubicacion: ubicacion,
      disponible: disponible ?? this.disponible,
    );
  }
}
