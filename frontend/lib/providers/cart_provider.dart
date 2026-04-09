import 'package:flutter/material.dart';
import '../models/producto_model.dart';

class CartItem {
  final Producto producto;
  final List<String> ingredientesExcluidos;
  int cantidad;

  CartItem({
    required this.producto,
    this.cantidad = 1,
    this.ingredientesExcluidos = const [],
  });

  /// Clave única: producto + combinación de exclusiones
  String get key {
    if (ingredientesExcluidos.isEmpty) return producto.id;
    final sorted = List<String>.from(ingredientesExcluidos)..sort();
    return '${producto.id}_sin_${sorted.join('_')}';
  }

  double get subtotal => producto.precio * cantidad;
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _mesaId;
  int? _numeroMesa;

  Map<String, CartItem> get items => _items;

  String? get mesaId => _mesaId;
  int? get numeroMesa => _numeroMesa;
  bool get tienemesa => _mesaId != null;

  int get itemCount => _items.length;

  int get totalQuantity => _items.values.fold(0, (sum, item) => sum + item.cantidad);

  double get totalPrice => _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(Producto producto, {List<String> ingredientesExcluidos = const []}) {
    final item = CartItem(
      producto: producto,
      ingredientesExcluidos: ingredientesExcluidos,
    );
    final key = item.key;
    if (_items.containsKey(key)) {
      _items[key]!.cantidad++;
    } else {
      _items[key] = item;
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    if (_items.containsKey(productId)) {
      if (_items[productId]!.cantidad > 1) {
        _items[productId]!.cantidad--;
      } else {
        _items.remove(productId);
      }
      notifyListeners();
    }
  }

  void removeProduct(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _mesaId = null;
    _numeroMesa = null;
    notifyListeners();
  }

  void asignarMesa({required String mesaId, required int numeroMesa}) {
    _mesaId = mesaId;
    _numeroMesa = numeroMesa;
    notifyListeners();
  }

  void desasignarMesa() {
    _mesaId = null;
    _numeroMesa = null;
    notifyListeners();
  }

  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  int getQuantity(String productId) {
    return _items[productId]?.cantidad ?? 0;
  }
}