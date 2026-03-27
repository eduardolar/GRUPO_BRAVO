class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final String? imagenUrl; // Opcional para fotos reales
  final bool estaDisponible; // Para manejo de stock

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    this.imagenUrl,
    this.estaDisponible = true, // Por defecto disponible
  });

  // El método factory permite crear un Producto desde un Mapa (JSON)
  factory Producto.fromMap(Map<String, dynamic> mapa) {
    return Producto(
      id: mapa['id'] ?? '',
      nombre: mapa['nombre'] ?? '',
      descripcion: mapa['descripcion'] ?? '',
      // Aseguramos que el precio sea double aunque venga como int
      precio: (mapa['precio'] ?? 0.0).toDouble(),
      categoria: mapa['categoria'] ?? '',
      imagenUrl: mapa['imagenUrl'],
      estaDisponible: mapa['estaDisponible'] ?? true,
    );
  }

  // Método para convertir el objeto de vuelta a un Mapa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'categoria': categoria,
      'imagenUrl': imagenUrl,
      'estaDisponible': estaDisponible,
    };
  }
}