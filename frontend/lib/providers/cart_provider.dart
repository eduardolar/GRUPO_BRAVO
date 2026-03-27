import 'package:flutter/material.dart';
import '../models/producto_model.dart';

class CartItem {
  final Producto producto;
  int cantidad;

  CartItem({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.length;

  int get totalQuantity => _items.values.fold(0, (sum, item) => sum + item.cantidad);

  double get totalPrice => _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  void addItem(Producto producto) {
    if (_items.containsKey(producto.id)) {
      _items[producto.id]!.cantidad++;
    } else {
      _items[producto.id] = CartItem(producto: producto);
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
    notifyListeners();
  }

  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  int getQuantity(String productId) {
    return _items[productId]?.cantidad ?? 0;
  }
}