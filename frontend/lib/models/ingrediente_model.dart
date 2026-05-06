class Ingrediente {
  final String id;
  final String nombre;
  final String categoria; // Añadido para que funcionen los filtros
  final double cantidadActual;
  final String unidad;
  final double stockMinimo;
  // Cantidad necesaria en una receta (sólo aplica cuando el ingrediente
  // forma parte de Producto.ingredientes). 0 si no está en una receta.
  final double cantidadReceta;

  Ingrediente({
    required this.id,
    required this.nombre,
    this.categoria = 'Otros',
    this.cantidadActual = 0,
    this.unidad = 'kg',
    this.stockMinimo = 0,
    this.cantidadReceta = 0,
  });

  bool get stockBajo => cantidadActual <= stockMinimo;

  Ingrediente copyWith({
    String? id,
    String? nombre,
    String? categoria,
    double? cantidadActual,
    String? unidad,
    double? stockMinimo,
    double? cantidadReceta,
  }) {
    return Ingrediente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      cantidadActual: cantidadActual ?? this.cantidadActual,
      unidad: unidad ?? this.unidad,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      cantidadReceta: cantidadReceta ?? this.cantidadReceta,
    );
  }

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: json['id'] ?? json['_id'] ?? '',
      nombre: json['nombre'] ?? json['ingrediente'] ?? '',
      categoria: json['categoria'] ?? 'Otros',
      cantidadActual:
          (json['cantidadActual'] ??
                  json['cantidad_actual'] ??
                  json['cantidad'] ??
                  0)
              .toDouble(),
      unidad: json['unidad'] ?? 'kg',
      stockMinimo: (json['stockMinimo'] ?? json['stock_minimo'] ?? 0)
          .toDouble(),
      cantidadReceta: (json['cantidadReceta'] ?? json['cantidad_receta'] ?? 0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'cantidadActual': cantidadActual,
      'unidad': unidad,
      'stockMinimo': stockMinimo,
      'cantidadReceta': cantidadReceta,
    };
  }
}
