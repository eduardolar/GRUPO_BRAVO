import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'cart_provider.dart';

class PedidoProvider extends ChangeNotifier {
  String _mesaId = '';
  int? _numeroMesa;
  bool _cargando = false;
  String? _error;

  String get mesaId => _mesaId;
  int? get numeroMesa => _numeroMesa;
  bool get cargando => _cargando;
  String? get error => _error;

  void setMesa(String id, {int? numero}) {
    _mesaId = id;
    _numeroMesa = numero;
    notifyListeners();
  }

  void limpiarPedido() {
    _mesaId = '';
    _numeroMesa = null;
    _error = null;
    notifyListeners();
  }

  /// Envía el pedido al servidor y limpia el carrito si tiene éxito.
  /// Devuelve `true` si el pedido se creó correctamente.
  /// La UI es responsable de la navegación y los SnackBars según el resultado.
  Future<bool> finalizarOrden({
    required CartProvider cart,
    required String userId,
    String metodoPago = 'efectivo',
    String? notas,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final items = cart.items.values
          .map(
            (item) => {
              'producto_id': item.producto.id,
              'nombre': item.producto.nombre,
              'cantidad': item.cantidad,
              'precio': item.producto.precio,
              'sin': item.ingredientesExcluidos,
            },
          )
          .toList();

      final resultado = await ApiService.crearPedido(
        userId: userId,
        items: items,
        tipoEntrega: 'local',
        metodoPago: metodoPago,
        total: cart.totalPrice,
        mesaId: _mesaId.isNotEmpty ? _mesaId : cart.mesaId,
        numeroMesa: _numeroMesa ?? cart.numeroMesa,
        notas: notas,
        estadoPago: 'pendiente',
        restauranteId: cart.restauranteId,
      );

      final exito = resultado['id'] != null || resultado['pedido_id'] != null;
      if (exito) {
        cart.clearCart();
        limpiarPedido();
      }
      return exito;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
