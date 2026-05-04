class ProductoPedido {
  final String? productoId;
  final String nombre;
  final int cantidad;
  final double precio;
  final List<String> sin;

  ProductoPedido({
    this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.sin = const [],
  });

  factory ProductoPedido.fromMap(Map<String, dynamic> mapa) {
    return ProductoPedido(
      productoId: mapa['producto_id'] as String?,
      nombre: mapa['nombre'] ?? mapa['producto_nombre'] ?? '',
      cantidad: mapa['cantidad'] ?? 1,
      precio: (mapa['precio'] ?? 0.0).toDouble(),
      sin: (mapa['sin'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'cantidad': cantidad, 'precio': precio, 'sin': sin};
  }

  double get subtotal => cantidad * precio;
}

class Pedido {
  final String id;
  final String fecha;
  final double total;
  final String estado;
  final int items;
  final String tipoEntrega;
  final String metodoPago;
  final String? direccion;
  final String? mesaId;
  final int? numeroMesa;
  final List<ProductoPedido> productos;
  final String? notas;
  final String? restauranteId;

  Pedido({
    required this.id,
    required this.fecha,
    required this.total,
    required this.estado,
    required this.items,
    required this.tipoEntrega,
    required this.metodoPago,
    this.direccion,
    this.mesaId,
    this.numeroMesa,
    required this.productos,
    this.notas,
    this.restauranteId,
  });

  factory Pedido.fromMap(Map<String, dynamic> mapa) {
    final productosList =
        (mapa['productos'] as List<dynamic>?)
            ?.map((p) => ProductoPedido.fromMap(p as Map<String, dynamic>))
            .toList() ??
        [];
    return Pedido(
      id: mapa['id'] ?? '',
      fecha: mapa['fecha'] ?? '',
      total: (mapa['total'] ?? 0.0).toDouble(),
      estado: mapa['estado'] ?? '',
      items: mapa['items'] ?? 0,
      tipoEntrega: mapa['tipoEntrega'] ?? '',
      metodoPago: mapa['metodoPago'] ?? '',
      direccion: mapa['direccion'],
      mesaId: mapa['mesaId'],
      numeroMesa: mapa['numeroMesa'],
      productos: productosList,
      notas: mapa['notas'] as String?,
      restauranteId: mapa['restauranteId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha,
      'total': total,
      'estado': estado,
      'items': items,
      'tipoEntrega': tipoEntrega,
      'metodoPago': metodoPago,
      'direccion': direccion,
      'mesaId': mesaId,
      'numeroMesa': numeroMesa,
      'productos': productos.map((p) => p.toMap()).toList(),
      'notas': notas,
      'restauranteId': restauranteId,
    };
  }
}
