import '../models/producto_model.dart';
import '../models/usuario_model.dart';
import 'mock_categories.dart';
import 'mock_products.dart';
import 'mock_users.dart';

class MockData {
  // Re-export de categorías
  static const List<String> categorias = MockCategories.categorias;

  // Re-export de productos
  static final List<Producto> productos = MockProducts.productos;

  // Re-export de usuarios
  static final List<Usuario> usuarios = MockUsers.usuarios;
}