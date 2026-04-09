class Ingrediente {
  final String id;
  final String nombre;
  final double cantidadActual;
  final String unidad;
  final double stockMinimo;

  Ingrediente({
    required this.id,
    required this.nombre,
    this.cantidadActual = 0,
    this.unidad = 'kg',
    this.stockMinimo = 0,
  });

  bool get stockBajo => cantidadActual <= stockMinimo;

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: json['id'] ?? json['_id'] ?? '',
      nombre: json['nombre'] ?? json['ingrediente'] ?? '',
      cantidadActual: (json['cantidad_actual'] ?? 0).toDouble(),
      unidad: json['unidad'] ?? 'kg',
      stockMinimo: (json['stock_minimo'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'cantidad_actual': cantidadActual,
      'unidad': unidad,
      'stock_minimo': stockMinimo,
    };
  }
}
