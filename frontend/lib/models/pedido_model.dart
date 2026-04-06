class ProductoPedido {
  final String nombre;
  final int cantidad;
  final double precio;

  ProductoPedido({
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });

  factory ProductoPedido.fromMap(Map<String, dynamic> mapa) {
    return ProductoPedido(
      nombre: mapa['nombre'] ?? '',
      cantidad: mapa['cantidad'] ?? 1,
      precio: (mapa['precio'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'cantidad': cantidad, 'precio': precio};
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
  final List<ProductoPedido> productos;

  Pedido({
    required this.id,
    required this.fecha,
    required this.total,
    required this.estado,
    required this.items,
    required this.tipoEntrega,
    required this.metodoPago,
    this.direccion,
    required this.productos,
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
      tipoEntrega: mapa['tipo_entrega'] ?? '',
      metodoPago: mapa['metodo_pago'] ?? '',
      direccion: mapa['direccion'],
      productos: productosList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha,
      'total': total,
      'estado': estado,
      'items': items,
      'tipo_entrega': tipoEntrega,
      'metodo_pago': metodoPago,
      'direccion': direccion,
      'productos': productos.map((p) => p.toMap()).toList(),
    };
  }
}
