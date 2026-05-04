class Cupon {
  final String id;
  final String codigo;
  final String tipo;       // "porcentaje" | "fijo"
  final double valor;
  final String descripcion;
  final bool activo;
  final int? usosMaximos;
  final int usosActuales;
  final String? fechaInicio;
  final String? fechaFin;

  const Cupon({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.valor,
    required this.descripcion,
    required this.activo,
    this.usosMaximos,
    required this.usosActuales,
    this.fechaInicio,
    this.fechaFin,
  });

  factory Cupon.fromJson(Map<String, dynamic> j) => Cupon(
        id: j['id'] ?? '',
        codigo: j['codigo'] ?? '',
        tipo: j['tipo'] ?? 'porcentaje',
        valor: (j['valor'] ?? 0).toDouble(),
        descripcion: j['descripcion'] ?? '',
        activo: j['activo'] != false,
        usosMaximos: j['usos_maximos'] as int?,
        usosActuales: (j['usos_actuales'] ?? 0) as int,
        fechaInicio: j['fecha_inicio'] as String?,
        fechaFin: j['fecha_fin'] as String?,
      );

  String get etiquetaValor =>
      tipo == 'porcentaje' ? '${valor.toStringAsFixed(0)}%' : '€${valor.toStringAsFixed(2)}';

  bool get ilimitado => usosMaximos == null;
}
