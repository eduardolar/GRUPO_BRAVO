// ============================================================================
// frontend/lib/models/categoria_model.dart
// ----------------------------------------------------------------------------
// Categoría de la carta (Entrantes, Principales, Postres...). `icono`
// guarda un nombre de Material Icon opcional para el chip de filtro.
// ============================================================================
class Categoria {
  final String id;
  final String nombre;
  final String? icono;

  Categoria({required this.id, required this.nombre, this.icono});

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] ?? json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      icono: json['icono'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'nombre': nombre, 'icono': icono};
  }
}
