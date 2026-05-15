// ============================================================================
// frontend/lib/models/pedido_model.dart
// ----------------------------------------------------------------------------
// Modelos del pedido: ProductoPedido (línea) y Pedido (cabecera).
//
// `itemId` (UUID estable asignado por el backend) permite a cocina marcar
// items como hechos individualmente sin depender del índice (más robusto
// si el pedido se modifica). Pedidos antiguos sin itemId caen al endpoint
// legacy `/items/{idx}/hecho-por-indice`.
// ============================================================================
class ProductoPedido {
  final String? productoId;
  /// UUID estable del item dentro del pedido. Lo asigna el backend al crear.
  /// Pedidos antiguos pueden no tenerlo; en ese caso usa la URL legacy
  /// `/items/{idx}/hecho-por-indice`.
  final String? itemId;
  final String nombre;
  final int cantidad;
  final double precio;
  final List<String> sin;
  final bool hecho;

  ProductoPedido({
    this.productoId,
    this.itemId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    this.sin = const [],
    this.hecho = false,
  });

  factory ProductoPedido.fromMap(Map<String, dynamic> mapa) {
    return ProductoPedido(
      productoId: mapa['producto_id'] as String?,
      itemId: mapa['item_id'] as String?,
      nombre: mapa['nombre'] ?? mapa['producto_nombre'] ?? '',
      cantidad: mapa['cantidad'] ?? 1,
      precio: (mapa['precio'] ?? 0.0).toDouble(),
      sin:
          (mapa['sin'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      hecho: mapa['hecho'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (itemId != null) 'item_id': itemId,
      'nombre': nombre,
      'cantidad': cantidad,
      'precio': precio,
      'sin': sin,
      'hecho': hecho,
    };
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
  final String estadoPago;
  final String? direccion;
  final String? mesaId;
  final int? numeroMesa;
  final List<ProductoPedido> productos;
  final String? notas;
  final String? restauranteId;
  /// Pedido marcado como urgente: cocinero lo prioriza visualmente.
  final bool prioritario;

  Pedido({
    required this.id,
    required this.fecha,
    required this.total,
    required this.estado,
    required this.items,
    required this.tipoEntrega,
    required this.metodoPago,
    this.estadoPago = 'pendiente',
    this.direccion,
    this.mesaId,
    this.numeroMesa,
    required this.productos,
    this.notas,
    this.restauranteId,
    this.prioritario = false,
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
      // Acepta camelCase (formato actual del backend) y snake_case (legacy).
      estadoPago: (mapa['estadoPago'] ?? mapa['estado_pago'] ?? 'pendiente') as String,
      direccion: mapa['direccion'],
      mesaId: mapa['mesaId'],
      numeroMesa: mapa['numeroMesa'],
      productos: productosList,
      notas: mapa['notas'] as String?,
      restauranteId: mapa['restauranteId'] as String?,
      prioritario: mapa['prioritario'] == true,
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
