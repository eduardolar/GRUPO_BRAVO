class Stock {
  final String id;
  final String nombre;
  final String descripcion;
  final bool estaDisponible; // Para manejo de stock

  Stock({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.estaDisponible = true, // Por defecto disponible
  });

  // El método factory permite crear un Producto desde un Mapa (JSON)
  factory Stock.fromMap(Map<String, dynamic> mapa) {
    return Stock(
      id: mapa['id'] ?? '',
      nombre: mapa['nombre'] ?? '',
      descripcion: mapa['descripcion'] ?? '',
      estaDisponible: mapa['estaDisponible'] ?? true,
    );
  }

  // Método para convertir el objeto de vuelta a un Mapa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'estaDisponible': estaDisponible,
    };
  }
}
