import 'ingrediente_model.dart';

class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final String? imagenUrl;
  final bool estaDisponible;
  final List<Ingrediente> ingredientes;

  /// Sucursal a la que pertenece el producto. `null` indica que el producto
  /// es legacy (sin sucursal asignada) y solo el super admin debería
  /// editarlo para asignárselo.
  final String? restauranteId;

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    this.imagenUrl,
    this.estaDisponible = true,
    this.ingredientes = const [],
    this.restauranteId,
  });

  // El método factory permite crear un Producto desde un Mapa (JSON)
  factory Producto.fromMap(Map<String, dynamic> mapa) {
    return Producto(
      id: mapa['id'] ?? '',
      nombre: mapa['nombre'] ?? '',
      descripcion: mapa['descripcion'] ?? '',
      precio: (mapa['precio'] ?? 0.0).toDouble(),
      categoria: mapa['categoria'] ?? '',
      imagenUrl: mapa['imagenUrl'],
      estaDisponible: mapa['estaDisponible'] ?? true,
      ingredientes: mapa['ingredientes'] != null
          ? (mapa['ingredientes'] as List).map((i) {
              if (i is String) {
                return Ingrediente(id: '', nombre: i);
              }
              return Ingrediente.fromJson(i as Map<String, dynamic>);
            }).toList()
          : [],
      // Acepta ambas convenciones desde el backend.
      restauranteId: (mapa['restauranteId'] ?? mapa['restaurante_id'])
          ?.toString(),
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
      'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
      if (restauranteId != null) 'restauranteId': restauranteId,
    };
  }
}
